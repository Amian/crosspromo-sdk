import Foundation

public struct CrossPromoConfiguration: Sendable {
    public enum Environment: Sendable {
        case production
        case sandbox
        case custom(URL)

        var baseURL: URL {
            switch self {
            case .production:
                URL(string: "https://backend-j5mh.onrender.com")!
            case .sandbox:
                URL(string: "https://sandbox-api.crosspromo.app")!
            case let .custom(url):
                url
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
        guard appKey.hasPrefix("cp_live_") || appKey.hasPrefix("cp_test_") else {
            throw CrossPromoError.invalidConfiguration(
                "appKey must start with cp_live_ or cp_test_"
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
