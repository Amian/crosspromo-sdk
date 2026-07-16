import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor CrossPromoClient {
    private struct Session: Sendable {
        let accessToken: String
        let status: CrossPromoSessionStatus
    }

    private let configuration: CrossPromoConfiguration
    private let transport: any CrossPromoTransport
    private let deviceContext: any CrossPromoDeviceContextProviding
    private var session: Session?

    public init(configuration: CrossPromoConfiguration) {
        self.configuration = configuration
        transport = URLSessionCrossPromoTransport(timeout: configuration.requestTimeout)
        deviceContext = AppleDeviceContextProvider()
    }

    init(
        configuration: CrossPromoConfiguration,
        transport: any CrossPromoTransport,
        deviceContext: any CrossPromoDeviceContextProviding
    ) {
        self.configuration = configuration
        self.transport = transport
        self.deviceContext = deviceContext
    }

    public func sessionStatus() async throws -> CrossPromoSessionStatus {
        try await validSession().status
    }

    public func fetchCard(placement: CrossPromoPlacement) async throws -> PromoCardData? {
        let session = try await validSession()
        let response: CardResponse = try await request(
            path: "/v1/cards",
            method: "POST",
            body: CardRequest(placement: placement.rawValue),
            bearerToken: session.accessToken
        )
        return response.card
    }

    public func recordImpression(
        for card: PromoCardData,
        visibleFraction: Double,
        duration: TimeInterval
    ) async throws {
        guard visibleFraction >= 0.5, duration >= 1 else { return }
        let session = try await validSession()
        let body = ImpressionRequest(
            impressionToken: card.impressionToken,
            occurredAt: Date(),
            viewability: .init(
                visibleFraction: min(1, max(0, visibleFraction)),
                durationMS: Int(duration * 1_000)
            )
        )
        let _: EmptyResponse = try await request(
            path: "/v1/events/impressions",
            method: "POST",
            body: body,
            bearerToken: session.accessToken,
            idempotencyKey: UUID().uuidString.lowercased()
        )
    }

    public func resetInstallationID() async {
        session = nil
        await deviceContext.resetInstallationID()
    }

    private func validSession() async throws -> Session {
        if let session, session.status.expiresAt.timeIntervalSinceNow > 30 {
            return session
        }
        let created = try await createSession()
        session = created
        return created
    }

    private func createSession() async throws -> Session {
        let snapshot = try await deviceContext.snapshot()
        let challengeRequest = SessionChallengeRequest(
            appKey: configuration.appKey,
            installationID: snapshot.installationID,
            app: snapshot.app,
            sdk: SDKDescriptor(name: "crosspromo-ios", version: CrossPromo.sdkVersion),
            locale: Locale.current.identifier,
            integrity: snapshot.integrity
        )
        let challenge: SessionChallengeResponse = try await request(
            path: "/v1/sdk/sessions/challenge",
            method: "POST",
            body: challengeRequest
        )
        let evidence = try await deviceContext.generateEvidence(
            challengeBase64: challenge.challengeBase64,
            mode: challenge.integrityMode
        )
        let verified: SessionVerifyResponse = try await request(
            path: "/v1/sdk/sessions/verify",
            method: "POST",
            body: SessionVerifyRequest(sessionID: challenge.sessionID, evidence: evidence)
        )
        return Session(
            accessToken: verified.accessToken,
            status: CrossPromoSessionStatus(
                publisherAppID: verified.publisherAppID,
                countsEnabled: verified.countsEnabled,
                reason: verified.reason,
                expiresAt: verified.expiresAt
            )
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        bearerToken: String? = nil,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        let url = configuration.environment.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("crosspromo-ios/\(CrossPromo.sdkVersion)", forHTTPHeaderField: "User-Agent")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        request.httpBody = try CrossPromoCoding.encoder.encode(body)

        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            let envelope = try? CrossPromoCoding.decoder.decode(ErrorEnvelope.self, from: data)
            throw CrossPromoError.server(
                status: response.statusCode,
                message: envelope?.error?.message ?? "Request failed"
            )
        }
        if Response.self == EmptyResponse.self, data.isEmpty,
           let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try CrossPromoCoding.decoder.decode(Response.self, from: data)
        } catch {
            throw CrossPromoError.invalidResponse
        }
    }
}

@MainActor
public enum CrossPromo {
    public nonisolated static let sdkVersion = "0.1.0"
    private static var configuredClient: CrossPromoClient?

    public static func configure(
        appKey: String,
        environment: CrossPromoConfiguration.Environment = .production
    ) throws {
        let configuration = try CrossPromoConfiguration(appKey: appKey, environment: environment)
        configuredClient = CrossPromoClient(configuration: configuration)
    }

    public static var client: CrossPromoClient {
        get throws {
            guard let configuredClient else { throw CrossPromoError.notConfigured }
            return configuredClient
        }
    }
}
