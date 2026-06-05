import Combine
import Foundation
import SwiftData

final class MatchListViewModel: ObservableObject {
    @Published private(set) var matches: [StoredMatch] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isOffline = false
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var hasCompletedInitialLoad = false
    @Published var errorMessage: String?

    private let repositoryFactory: MatchRepositoryFactoryProtocol
    private let syncService: MatchDecisionSyncServiceProtocol
    private let connectivityMonitor: ConnectivityMonitoring
    private var repository: MatchRepositoryProtocol?
    private var fetchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var syncCancellables = Set<AnyCancellable>()

    init(
        repositoryFactory: MatchRepositoryFactoryProtocol = MatchRepositoryFactory(),
        syncService: MatchDecisionSyncServiceProtocol = MatchDecisionSyncService(),
        connectivityMonitor: ConnectivityMonitoring = ConnectivityMonitor.shared
    ) {
        self.repositoryFactory = repositoryFactory
        self.syncService = syncService
        self.connectivityMonitor = connectivityMonitor
    }

    func configure(modelContext: ModelContext) {
        guard repository == nil else {
            return
        }

        // The ModelContext comes from SwiftUI's environment, so setup waits until the view is available.
        repository = repositoryFactory.makeRepository(modelContext: modelContext)
        loadStoredMatches()
        observeConnectivity()
    }

    func fetchMatches() {
        guard !isLoading, let repository else {
            return
        }

        if !connectivityMonitor.isConnected {
            // Avoid starting a network request when known offline; show the local cache instead.
            isLoading = false
            showCachedMatchesAfterFailure(error: .offline)
            return
        }

        isLoading = true
        errorMessage = nil

        fetchCancellable = repository.refreshMatches()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else {
                    return
                }

                self.isLoading = false
                self.hasCompletedInitialLoad = true
                self.fetchCancellable = nil

                if case .failure(let error) = completion {
                    self.showCachedMatchesAfterFailure(error: error)
                }
            } receiveValue: { [weak self] matches in
                guard let self else {
                    return
                }

                self.matches = matches
                self.hasCompletedInitialLoad = true
                self.isOffline = false
                self.errorMessage = nil
                self.refreshPendingSyncCount()
            }
    }

    func accept(_ match: StoredMatch) {
        updateDecision(.accepted, for: match)
    }

    func decline(_ match: StoredMatch) {
        updateDecision(.declined, for: match)
    }

    func dismissErrorMessage(matching message: String) {
        guard errorMessage == message else {
            return
        }

        errorMessage = nil
    }

    private func updateDecision(_ decision: MatchDecision, for match: StoredMatch) {
        guard let repository else {
            return
        }

        do {
            matches = try repository.updateDecision(decision, for: match)
            refreshPendingSyncCount()
            errorMessage = nil

            if connectivityMonitor.isConnected {
                syncPendingDecisions()
            } else {
                isOffline = true
                errorMessage = "Decision saved offline. It will sync when you are back online."
            }
        } catch {
            present(error)
        }
    }

    private func loadStoredMatches() {
        guard let repository else {
            return
        }

        do {
            matches = try repository.fetchCachedMatches()
            hasCompletedInitialLoad = !matches.isEmpty
            isOffline = !matches.isEmpty
            refreshPendingSyncCount()
        } catch {
            hasCompletedInitialLoad = true
            present(error)
        }
    }

    private func showCachedMatchesAfterFailure(error: MatchMateError? = nil) {
        guard let repository else {
            return
        }

        let cachedMatches: [StoredMatch]

        do {
            cachedMatches = try repository.fetchCachedMatches()
        } catch {
            present(error)
            return
        }

        if !cachedMatches.isEmpty {
            matches = cachedMatches
            hasCompletedInitialLoad = true
            isOffline = true
            refreshPendingSyncCount()
            errorMessage = fallbackCacheMessage(for: error)
        } else {
            hasCompletedInitialLoad = true
            isOffline = !connectivityMonitor.isConnected
            errorMessage = error?.localizedDescription ?? "Unable to load matches. Please try again."
        }
    }

    private func observeConnectivity() {
        connectivityMonitor.isConnectedPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleConnectivityChange(isConnected)
            }
            .store(in: &cancellables)
    }

    private func handleConnectivityChange(_ isConnected: Bool) {
        if isConnected {
            isOffline = false
            if errorMessage == MatchMateError.offline.localizedDescription {
                errorMessage = nil
            }
            syncPendingDecisions()
            fetchMatches()
        } else {
            isOffline = !matches.isEmpty
            errorMessage = matches.isEmpty
                ? "You are offline. Connect to the internet to load matches."
                : "You are offline. You can still view saved matches and save decisions."
        }
    }

    private func syncPendingDecisions() {
        guard
            connectivityMonitor.isConnected,
            !isSyncing,
            let repository
        else {
            refreshPendingSyncCount()
            return
        }

        let pendingMatches: [StoredMatch]

        do {
            pendingMatches = try repository.pendingDecisionSyncMatches()
        } catch {
            present(error)
            return
        }

        pendingSyncCount = pendingMatches.count

        guard !pendingMatches.isEmpty else {
            isSyncing = false
            return
        }

        isSyncing = true
        syncCancellables.removeAll()

        // Convert each sync failure into a result so one failed decision does not cancel the whole batch.
        let syncPublishers = pendingMatches.compactMap { match -> AnyPublisher<DecisionSyncResult, Never>? in
            guard let decision = match.decision else {
                return nil
            }

            return syncService.syncDecision(for: match, decision: decision)
                .map {
                    DecisionSyncResult(
                        match: match,
                        decision: decision,
                        error: nil
                    )
                }
                .catch { error -> Just<DecisionSyncResult> in
                    Just(
                        DecisionSyncResult(
                            match: match,
                            decision: decision,
                            error: error
                        )
                    )
                }
                .eraseToAnyPublisher()
        }

        guard !syncPublishers.isEmpty else {
            isSyncing = false
            refreshPendingSyncCount()
            return
        }

        Publishers.MergeMany(syncPublishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncedDecisions in
                self?.completeSync(with: syncedDecisions)
            }
            .store(in: &syncCancellables)
    }

    private func completeSync(with results: [DecisionSyncResult]) {
        guard let repository else {
            isSyncing = false
            return
        }

        for result in results {
            do {
                if let error = result.error {
                    try repository.markDecisionSyncFailed(
                        result.match,
                        message: error.localizedDescription
                    )
                } else {
                    try repository.markDecisionSynced(
                        result.match,
                        decision: result.decision
                    )
                }
            } catch {
                present(error)
            }
        }

        do {
            matches = try repository.fetchCachedMatches()
        } catch {
            present(error)
        }

        refreshPendingSyncCount()
        isSyncing = false

        if pendingSyncCount == 0 {
            errorMessage = nil
        } else if results.contains(where: { $0.error != nil }) {
            errorMessage = "Some saved decisions could not sync. They will retry when the connection is available."
        }
    }

    private func refreshPendingSyncCount() {
        guard let repository else {
            pendingSyncCount = 0
            return
        }

        do {
            pendingSyncCount = try repository.pendingDecisionSyncCount()
        } catch {
            pendingSyncCount = 0
            present(error)
        }
    }

    private func fallbackCacheMessage(for error: MatchMateError?) -> String {
        guard let error else {
            return "Showing saved matches."
        }

        switch error {
        case .offline:
            return "You are offline. Showing saved matches."
        default:
            return "Showing saved matches. \(error.localizedDescription)"
        }
    }

    private func present(_ error: Error) {
        let matchMateError = error as? MatchMateError ?? MatchMateError.unknown(error.localizedDescription)
        errorMessage = matchMateError.localizedDescription
    }
}

private struct DecisionSyncResult {
    let match: StoredMatch
    let decision: MatchDecision
    let error: MatchMateError?
}
