import Combine
import Foundation
import SwiftData

protocol MatchRepositoryFactoryProtocol {
    func makeRepository(modelContext: ModelContext) -> MatchRepositoryProtocol
}

final class MatchRepositoryFactory: MatchRepositoryFactoryProtocol {
    private let apiService: MatchAPIServiceProtocol

    init(apiService: MatchAPIServiceProtocol = MatchAPIService()) {
        self.apiService = apiService
    }

    func makeRepository(modelContext: ModelContext) -> MatchRepositoryProtocol {
        MatchRepository(
            apiService: apiService,
            persistenceService: MatchPersistenceService(modelContext: modelContext)
        )
    }
}

protocol MatchRepositoryProtocol {
    func fetchCachedMatches() throws -> [StoredMatch]
    func refreshMatches() -> AnyPublisher<[StoredMatch], MatchMateError>
    func updateDecision(_ decision: MatchDecision, for match: StoredMatch) throws -> [StoredMatch]
    func pendingDecisionSyncMatches() throws -> [StoredMatch]
    func pendingDecisionSyncCount() throws -> Int
    func markDecisionSynced(_ match: StoredMatch, decision: MatchDecision) throws
    func markDecisionSyncFailed(_ match: StoredMatch, message: String) throws
}

final class MatchRepository: MatchRepositoryProtocol {
    private let apiService: MatchAPIServiceProtocol
    private let persistenceService: MatchPersistenceServiceProtocol

    init(
        apiService: MatchAPIServiceProtocol,
        persistenceService: MatchPersistenceServiceProtocol
    ) {
        self.apiService = apiService
        self.persistenceService = persistenceService
    }

    func fetchCachedMatches() throws -> [StoredMatch] {
        try persistenceService.fetchMatches()
    }

    func refreshMatches() -> AnyPublisher<[StoredMatch], MatchMateError> {
        apiService.fetchMatches()
            .receive(on: DispatchQueue.main)
            .tryMap { [persistenceService] profiles in
                try persistenceService.upsertMatches(from: profiles)
            }
            .mapError { error in
                error as? MatchMateError ?? MatchMateError.unknown(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }

    func updateDecision(_ decision: MatchDecision, for match: StoredMatch) throws -> [StoredMatch] {
        try persistenceService.updateDecision(decision, for: match)
        return try persistenceService.fetchMatches()
    }

    func pendingDecisionSyncMatches() throws -> [StoredMatch] {
        try persistenceService.fetchPendingDecisionSyncMatches()
    }

    func pendingDecisionSyncCount() throws -> Int {
        try pendingDecisionSyncMatches().count
    }

    func markDecisionSynced(_ match: StoredMatch, decision: MatchDecision) throws {
        try persistenceService.markDecisionSynced(match, decision: decision)
    }

    func markDecisionSyncFailed(_ match: StoredMatch, message: String) throws {
        try persistenceService.markDecisionSyncFailed(match, message: message)
    }
}
