import Foundation

enum MatchDecision: String, Codable, Equatable {
    case accepted
    case declined

    var title: String {
        switch self {
        case .accepted:
            return "Member Accepted"
        case .declined:
            return "Member Declined"
        }
    }

    var systemImageName: String {
        switch self {
        case .accepted:
            return "checkmark.circle.fill"
        case .declined:
            return "xmark.circle.fill"
        }
    }
}
