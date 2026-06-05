import Foundation
import SwiftData

@Model
final class StoredMatch {
    @Attribute(.unique) var userID: Int
    var name: String
    var username: String
    var email: String
    var street: String
    var suite: String
    var city: String
    var zipcode: String
    var phone: String
    var website: String
    var companyName: String
    var companyCatchPhrase: String
    var companyBusiness: String
    var decisionRawValue: String?
    var decisionUpdatedAt: Date?
    var isDecisionSynced: Bool = true
    var lastDecisionSyncedAt: Date?
    var syncErrorMessage: String?
    var lastProfileSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(profile: MatchProfile, syncedAt: Date = Date()) {
        self.userID = profile.id
        self.name = profile.name
        self.username = profile.username
        self.email = profile.email
        self.street = profile.address.street
        self.suite = profile.address.suite
        self.city = profile.address.city
        self.zipcode = profile.address.zipcode
        self.phone = profile.phone
        self.website = profile.website
        self.companyName = profile.company.name
        self.companyCatchPhrase = profile.company.catchPhrase
        self.companyBusiness = profile.company.bs
        self.decisionRawValue = nil
        self.decisionUpdatedAt = nil
        self.isDecisionSynced = true
        self.lastDecisionSyncedAt = nil
        self.syncErrorMessage = nil
        self.lastProfileSyncedAt = syncedAt
        self.createdAt = syncedAt
        self.updatedAt = syncedAt
    }

    var decision: MatchDecision? {
        get {
            guard let decisionRawValue else {
                return nil
            }

            return MatchDecision(rawValue: decisionRawValue)
        }
        set {
            decisionRawValue = newValue?.rawValue
            updatedAt = Date()
        }
    }

    var needsDecisionSync: Bool {
        decision != nil && !isDecisionSynced
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let firstLetters = parts.prefix(2).compactMap { $0.first }
        return String(firstLetters).uppercased()
    }

    var age: Int {
        24 + (userID % 9)
    }

    var matchScore: Int {
        82 + ((userID * 3) % 16)
    }

    var imageURL: URL? {
        URL(string: "https://i.pravatar.cc/720?img=\((userID % 70) + 1)")
    }

    var locationSummary: String {
        "\(city), \(zipcode)"
    }

    var profileSummary: String {
        "\(age) yrs | \(city)"
    }

    var fullAddress: String {
        "\(suite), \(street), \(city)"
    }

    func update(with profile: MatchProfile, syncedAt: Date = Date()) {
        name = profile.name
        username = profile.username
        email = profile.email
        street = profile.address.street
        suite = profile.address.suite
        city = profile.address.city
        zipcode = profile.address.zipcode
        phone = profile.phone
        website = profile.website
        companyName = profile.company.name
        companyCatchPhrase = profile.company.catchPhrase
        companyBusiness = profile.company.bs
        lastProfileSyncedAt = syncedAt
        updatedAt = syncedAt
    }

    func applyLocalDecision(_ decision: MatchDecision) {
        self.decision = decision
        decisionUpdatedAt = Date()
        isDecisionSynced = false
        syncErrorMessage = nil
        updatedAt = Date()
    }

    func markDecisionSynced(for decision: MatchDecision) {
        guard self.decision == decision else {
            return
        }

        isDecisionSynced = true
        lastDecisionSyncedAt = Date()
        syncErrorMessage = nil
        updatedAt = Date()
    }

    func markDecisionSyncFailed(_ message: String) {
        guard decision != nil else {
            return
        }

        isDecisionSynced = false
        syncErrorMessage = message
        updatedAt = Date()
    }
}
