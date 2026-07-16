import Foundation

public struct CrossPromoConfiguration: Sendable {
    public enum Environment: Sendable {
        case production
        case sandbox
        case custom(URL)

        var baseURL: URL {
            switch self {
            case .production, .sandbox:
                URL(string: "https://backend-j5mh.onrender.com")!
            case let .custom(url):
                url
            }
        }

        var requestValue: String {
            switch self {
            case .sandbox:
                "sandbox"
            case .production, .custom:
                "production"
            }
        }
    }

    public let appKey: String
    public let environment: Environment
    public let requestTimeout: TimeInterval

    public init(
        appKey: String,
        environment: Environment = .production,
        requestTimeout: TimeInterval = 10
    ) throws {
        guard appKey.hasPrefix("cp_live_") || appKey.hasPrefix("cpn_live_") else {
            throw CrossPromoError.invalidConfiguration(
                "appKey must be the key shown in your CrossPromo dashboard"
            )
        }
        guard requestTimeout > 0 else {
            throw CrossPromoError.invalidConfiguration("requestTimeout must be positive")
        }
        self.appKey = appKey
        self.environment = environment
        self.requestTimeout = requestTimeout
    }
}
