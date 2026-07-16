import Foundation

public struct PromoCardData: Codable, Equatable, Sendable, Identifiable {
    public let cardID: String
    public let appName: String
    public let iconURL: URL
    public let tagline: String
    public let cta: String
    public let clickURL: URL
    public let impressionToken: String
    public let expiresAt: Date

    public var id: String { cardID }

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case appName = "app_name"
        case iconURL = "icon_url"
        case tagline
        case cta
        case clickURL = "click_url"
        case impressionToken = "impression_token"
        case expiresAt = "expires_at"
    }
}

public struct CrossPromoSessionStatus: Equatable, Sendable {
    public let publisherAppID: String
    public let countsEnabled: Bool
    public let reason: String?
    public let expiresAt: Date
}

struct AppDescriptor: Codable, Sendable {
    let platform: String
    let bundleID: String
    let version: String
    let buildNumber: String

    enum CodingKeys: String, CodingKey {
        case platform
        case bundleID = "bundle_id"
        case version
        case buildNumber = "build_number"
    }
}

struct SDKDescriptor: Codable, Sendable {
    let name: String
    let version: String
}

struct IntegrityPreparation: Codable, Sendable {
    let provider: String
    let appTransactionJWS: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case appTransactionJWS = "app_transaction_jws"
    }
}

struct DeviceSnapshot: Sendable {
    let installationID: String
    let app: AppDescriptor
    let integrity: IntegrityPreparation
}

struct SessionChallengeRequest: Codable, Sendable {
    let appKey: String
    let environment: String
    let installationID: String
    let app: AppDescriptor
    let sdk: SDKDescriptor
    let locale: String
    let integrity: IntegrityPreparation

    enum CodingKeys: String, CodingKey {
        case appKey = "app_key"
        case environment
        case installationID = "installation_id"
        case app
        case sdk
        case locale
        case integrity
    }
}

struct SessionChallengeResponse: Codable, Sendable {
    let sessionID: String
    let challengeBase64: String
    let integrityMode: String
    let cloudProjectNumber: Int64?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case challengeBase64 = "challenge_base64"
        case integrityMode = "integrity_mode"
        case cloudProjectNumber = "cloud_project_number"
    }
}

struct IntegrityEvidence: Codable, Sendable {
    let provider: String
    let appTransactionJWS: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case appTransactionJWS = "app_transaction_jws"
    }
}

struct SessionVerifyRequest: Codable, Sendable {
    let sessionID: String
    let evidence: IntegrityEvidence

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case evidence
    }
}

struct SessionVerifyResponse: Codable, Sendable {
    let accessToken: String
    let publisherAppID: String
    let countsEnabled: Bool
    let reason: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case publisherAppID = "publisher_app_id"
        case countsEnabled = "counts_enabled"
        case reason
        case expiresAt = "expires_at"
    }
}

struct CardRequest: Codable, Sendable {
    let placement: String
}

struct CardResponse: Codable, Sendable {
    let card: PromoCardData?
}

struct ImpressionRequest: Codable, Sendable {
    struct Viewability: Codable, Sendable {
        let visibleFraction: Double
        let durationMS: Int

        enum CodingKeys: String, CodingKey {
            case visibleFraction = "visible_fraction"
            case durationMS = "duration_ms"
        }
    }

    let impressionToken: String
    let occurredAt: Date
    let viewability: Viewability

    enum CodingKeys: String, CodingKey {
        case impressionToken = "impression_token"
        case occurredAt = "occurred_at"
        case viewability
    }
}

struct EmptyResponse: Codable, Sendable {}

struct ErrorEnvelope: Codable, Sendable {
    let error: APIErrorBody?
}

struct APIErrorBody: Codable, Sendable {
    let code: String?
    let message: String?
}
