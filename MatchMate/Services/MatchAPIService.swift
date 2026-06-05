import Combine
import Foundation

protocol MatchAPIServiceProtocol {
    func fetchMatches() -> AnyPublisher<[MatchProfile], MatchMateError>
}

final class MatchAPIService: MatchAPIServiceProtocol {
    private let session: URLSession
    private let endpoint = URL(string: "https://jsonplaceholder.typicode.com/users")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchMatches() -> AnyPublisher<[MatchProfile], MatchMateError> {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10

        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw MatchMateError.invalidResponse
                }

                guard 200..<300 ~= response.statusCode else {
                    throw MatchMateError.serverError(statusCode: response.statusCode)
                }

                return output.data
            }
            .decode(type: [MatchProfile].self, decoder: JSONDecoder())
            .mapError(MatchMateError.api)
            .eraseToAnyPublisher()
    }
}
