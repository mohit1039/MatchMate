import SwiftData
import Foundation

protocol MatchPersistenceServiceProtocol {
    func fetchMatches() throws -> [StoredMatch]
    func fetchPendingDecisionSyncMatches() throws -> [StoredMatch]
    func upsertMatches(from profiles: [MatchProfile]) throws -> [StoredMatch]
    func updateDecision(_ decision: MatchDecision, for match: StoredMatch) throws
    func markDecisionSynced(_ match: StoredMatch, decision: MatchDecision) throws
    func markDecisionSyncFailed(_ match: StoredMatch, message: String) throws
}

final class MatchPersistenceService: MatchPersistenceServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchMatches() throws -> [StoredMatch] {
        let descriptor = FetchDescriptor<StoredMatch>(
            sortBy: [SortDescriptor(\.userID)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw MatchMateError.databaseFetch(error)
        }
    }

    func fetchPendingDecisionSyncMatches() throws -> [StoredMatch] {
        try fetchMatches().filter(\.needsDecisionSync)
    }

    func upsertMatches(from profiles: [MatchProfile]) throws -> [StoredMatch] {
        var existingMatchesByID: [Int: StoredMatch] = [:]
        var processedProfileIDs = Set<Int>()
        let syncedAt = Date()

        for match in try fetchMatches() {
            existingMatchesByID[match.userID] = match
        }

        for profile in profiles {
            guard processedProfileIDs.insert(profile.id).inserted else {
                continue
            }

            if let storedMatch = existingMatchesByID[profile.id] {
                storedMatch.update(with: profile, syncedAt: syncedAt)
            } else {
                modelContext.insert(StoredMatch(profile: profile, syncedAt: syncedAt))
            }
        }

        do {
            try modelContext.save()
        } catch {
            throw MatchMateError.databaseSave(error)
        }

        return try fetchMatches()
    }

    func updateDecision(_ decision: MatchDecision, for match: StoredMatch) throws {
        match.applyLocalDecision(decision)

        do {
            try modelContext.save()
        } catch {
            throw MatchMateError.databaseUpdate(error)
        }
    }

    func markDecisionSynced(_ match: StoredMatch, decision: MatchDecision) throws {
        match.markDecisionSynced(for: decision)

        do {
            try modelContext.save()
        } catch {
            throw MatchMateError.databaseUpdate(error)
        }
    }

    func markDecisionSyncFailed(_ match: StoredMatch, message: String) throws {
        match.markDecisionSyncFailed(message)

        do {
            try modelContext.save()
        } catch {
            throw MatchMateError.databaseUpdate(error)
        }
    }
}
