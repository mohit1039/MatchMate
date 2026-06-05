import Combine
import Foundation

protocol MatchDecisionSyncServiceProtocol {
    func syncDecision(for match: StoredMatch, decision: MatchDecision) -> AnyPublisher<Void, MatchMateError>
}

final class MatchDecisionSyncService: MatchDecisionSyncServiceProtocol {
    private let session: URLSession
    private let endpoint = URL(string: "https://jsonplaceholder.typicode.com/posts")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func syncDecision(for match: StoredMatch, decision: MatchDecision) -> AnyPublisher<Void, MatchMateError> {
        let payload = MatchDecisionSyncPayload(
            userID: match.userID,
            decision: decision.rawValue,
            decidedAt: ISO8601DateFormatter().string(from: match.decisionUpdatedAt ?? Date())
        )

        guard let body = try? JSONEncoder().encode(payload) else {
            return Fail<Void, MatchMateError>(error: .encodingFailed)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw MatchMateError.invalidResponse
                }

                guard 200..<300 ~= response.statusCode else {
                    throw MatchMateError.serverError(statusCode: response.statusCode)
                }
            }
            .mapError(MatchMateError.sync)
            .eraseToAnyPublisher()
    }
}

private struct MatchDecisionSyncPayload: Encodable {
    let userID: Int
    let decision: String
    let decidedAt: String
}
