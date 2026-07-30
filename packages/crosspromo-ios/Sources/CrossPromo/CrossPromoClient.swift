import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor CrossPromoClient {
    private struct Session: Sendable {
        let accessToken: String
        let status: CrossPromoSessionStatus
    }

    /// A session this close to expiring is renewed before it is handed out, so a
    /// request can never be signed with a token that dies mid-flight.
    private static let sessionMinimumRemaining: TimeInterval = 30

    /// A still-valid session with less than this left is renewed in the background,
    /// so an ad request practically never waits for the three-call handshake.
    private static let sessionRefreshMargin: TimeInterval = 120

    /// A prefetched card has to outlive the viewability window it is about to be
    /// measured against, so one that is nearly expired is discarded rather than
    /// shown and then failing to record.
    private static let cardMinimumRemaining: TimeInterval = 30

    private let configuration: CrossPromoConfiguration
    private let transport: any CrossPromoTransport
    private let deviceContext: any CrossPromoDeviceContextProviding
    private var session: Session?

    /// The in-flight handshake, so simultaneous callers share one instead of each
    /// starting their own. Two cards appearing at once used to mean two handshakes.
    private var sessionTask: Task<Session, Error>?

    /// Cards fetched ahead of being needed, keyed by placement.
    ///
    /// Cards are single use: each carries its own impression token, and the backend
    /// treats a repeated token as a replay. Handing one card to two placements would
    /// therefore silently drop the second impression, so taking a prefetched card
    /// removes it from here.
    private var prefetched: [String: PromoCardData] = [:]
    private var prefetchTasks: [String: Task<Void, Never>] = [:]

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

    /// Does the slow part of showing an ad before there is anywhere to show it: the
    /// session handshake and one card fetch. Call it at launch, or as soon as you
    /// know a placement is coming, and the matching `fetchCard` returns immediately.
    ///
    /// Never throws by design — a prefetch that did not work must not surface as an
    /// error at a point where the app was not even showing an ad. The card is simply
    /// fetched on demand instead.
    ///
    /// Safe to call repeatedly: concurrent calls for one placement share a single
    /// fetch, and a placement that already holds a fresh card does nothing.
    public func prefetch(placement: CrossPromoPlacement) async {
        let key = placement.rawValue
        if let existing = prefetchTasks[key] {
            await existing.value
            return
        }
        if prefetched[key] != nil { return }
        let task = Task { await self.runPrefetch(key: key, placement: placement) }
        prefetchTasks[key] = task
        await task.value
    }

    /// Warms only the session handshake, for callers that want the credential ready
    /// without holding a card that could go stale.
    public func warmUp() async {
        _ = try? await validSession()
    }

    private func runPrefetch(key: String, placement: CrossPromoPlacement) async {
        defer { prefetchTasks[key] = nil }
        do {
            if let card = try await requestCard(placement: placement) {
                prefetched[key] = card
            }
        } catch {
            // Best effort: see prefetch's contract.
        }
    }

    public func fetchCard(placement: CrossPromoPlacement) async throws -> PromoCardData? {
        let key = placement.rawValue
        if let ready = takePrefetched(key: key) { return ready }

        // A prefetch already on the wire: wait for it rather than starting a second
        // identical request and wasting the impression the first one is holding.
        if let inflight = prefetchTasks[key] {
            await inflight.value
            if let arrived = takePrefetched(key: key) { return arrived }
        }
        return try await requestCard(placement: placement)
    }

    private func takePrefetched(key: String) -> PromoCardData? {
        guard let held = prefetched.removeValue(forKey: key) else { return nil }
        return held.expiresAt.timeIntervalSinceNow > Self.cardMinimumRemaining ? held : nil
    }

    private func requestCard(placement: CrossPromoPlacement) async throws -> PromoCardData? {
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

    private func validSession() async throws -> Session {
        if let session {
            let remaining = session.status.expiresAt.timeIntervalSinceNow
            if remaining > Self.sessionMinimumRemaining {
                if remaining < Self.sessionRefreshMargin {
                    // Still usable, but close enough to expiry that the next ad would
                    // have paid for a fresh handshake. Renew behind this request and
                    // answer it with the token we already hold.
                    renewSessionInBackground()
                }
                return session
            }
        }
        return try await startSession()
    }

    private func startSession() async throws -> Session {
        if let sessionTask {
            return try await sessionTask.value
        }
        let task = Task { try await self.createSession() }
        sessionTask = task
        defer { sessionTask = nil }
        let created = try await task.value
        session = created
        return created
    }

    private func renewSessionInBackground() {
        guard sessionTask == nil else { return }
        Task { _ = try? await self.startSession() }
    }

    private func createSession() async throws -> Session {
        let snapshot = try await deviceContext.snapshot()
        let challengeRequest = SessionChallengeRequest(
            appKey: configuration.appKey,
            environment: configuration.environment.requestValue,
            app: snapshot.app,
            sdk: SDKDescriptor(name: "crosspromo-ios", version: CrossPromo.sdkVersion)
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
    public nonisolated static let sdkVersion = "0.3.4"
    private static var configuredClient: CrossPromoClient?

    /// `prefetchPlacements` warms the session and one card for each placement given,
    /// in the background, so the first card the app shows appears without a network
    /// wait. Pass the placements the app actually uses — a prefetched card is held
    /// until something asks for it, and anything that fails is fetched on demand.
    public static func configure(
        appKey: String,
        environment: CrossPromoConfiguration.Environment = .automatic,
        prefetchPlacements: [CrossPromoPlacement] = []
    ) throws {
        let configuration = try CrossPromoConfiguration(appKey: appKey, environment: environment)
        let client = CrossPromoClient(configuration: configuration)
        configuredClient = client
        guard !prefetchPlacements.isEmpty else { return }
        Task {
            for placement in prefetchPlacements {
                await client.prefetch(placement: placement)
            }
        }
    }

    public static var client: CrossPromoClient {
        get throws {
            guard let configuredClient else { throw CrossPromoError.notConfigured }
            return configuredClient
        }
    }
}
