import Foundation

enum MatchMateError: LocalizedError {
    case offline
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingFailed
    case encodingFailed
    case requestFailed(String)
    case databaseFetchFailed(String)
    case databaseSaveFailed(String)
    case databaseUpdateFailed(String)
    case syncFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "You are offline. Showing saved matches."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let statusCode):
            return "The server returned error \(statusCode). Please try again."
        case .decodingFailed:
            return "Unable to read match data from the server."
        case .encodingFailed:
            return "Unable to prepare your decision for sync."
        case .requestFailed(let message):
            return "Network request failed. \(message)"
        case .databaseFetchFailed(let message):
            return "Unable to load saved matches. \(message)"
        case .databaseSaveFailed(let message):
            return "Unable to save match data. \(message)"
        case .databaseUpdateFailed(let message):
            return "Unable to update your decision. \(message)"
        case .syncFailed(let message):
            return "Unable to sync saved decisions. \(message)"
        case .unknown(let message):
            return "Something went wrong. \(message)"
        }
    }

    var isConnectivityError: Bool {
        if case .offline = self {
            return true
        }

        return false
    }

    static func api(_ error: Error) -> MatchMateError {
        if let matchMateError = error as? MatchMateError {
            return matchMateError
        }

        if let urlError = error as? URLError {
            return network(urlError)
        }

        if error is DecodingError {
            return .decodingFailed
        }

        return .requestFailed(error.localizedDescription)
    }

    static func sync(_ error: Error) -> MatchMateError {
        if let matchMateError = error as? MatchMateError {
            return matchMateError
        }

        if let urlError = error as? URLError {
            return network(urlError)
        }

        return .syncFailed(error.localizedDescription)
    }

    static func databaseFetch(_ error: Error) -> MatchMateError {
        .databaseFetchFailed(error.localizedDescription)
    }

    static func databaseSave(_ error: Error) -> MatchMateError {
        .databaseSaveFailed(error.localizedDescription)
    }

    static func databaseUpdate(_ error: Error) -> MatchMateError {
        .databaseUpdateFailed(error.localizedDescription)
    }

    private static func network(_ error: URLError) -> MatchMateError {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dataNotAllowed,
             .internationalRoamingOff:
            return .offline
        case .timedOut:
            return .requestFailed("The request timed out.")
        default:
            return .requestFailed(error.localizedDescription)
        }
    }
}

