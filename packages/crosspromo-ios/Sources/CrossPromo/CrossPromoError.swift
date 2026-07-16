import Foundation

public enum CrossPromoError: Error, LocalizedError, Sendable {
    case invalidConfiguration(String)
    case notConfigured
    case invalidResponse
    case server(status: Int, message: String)
    case integrityUnavailable(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            "Invalid CrossPromo configuration: \(message)"
        case .notConfigured:
            "Call CrossPromo.configure before using the SDK."
        case .invalidResponse:
            "The CrossPromo API returned an invalid response."
        case let .server(status, message):
            "CrossPromo API error \(status): \(message)"
        case let .integrityUnavailable(message):
            "App integrity evidence is unavailable: \(message)"
        case let .transport(message):
            "CrossPromo network error: \(message)"
        }
    }
}
