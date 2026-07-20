import Foundation

public struct CrossPromoConfiguration: Sendable {
    public enum Environment: Sendable {
        case automatic
        case production
        case sandbox
        case custom(URL)

        var resolved: Environment {
            switch self {
            case .automatic:
                #if DEBUG
                return .sandbox
                #else
                return .production
                #endif
            case .production, .sandbox, .custom:
                return self
            }
        }

        var baseURL: URL {
            switch resolved {
            case .production, .sandbox:
                URL(string: "https://backend-j5mh.onrender.com")!
            case let .custom(url):
                url
            case .automatic:
                preconditionFailure("Automatic environment must resolve before use")
            }
        }

        var requestValue: String {
            switch resolved {
            case .sandbox:
                "sandbox"
            case .production, .custom:
                "production"
            case .automatic:
                preconditionFailure("Automatic environment must resolve before use")
            }
        }
    }

    public let appKey: String
    public let environment: Environment
    public let requestTimeout: TimeInterval

    public init(
        appKey: String,
        environment: Environment = .automatic,
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
