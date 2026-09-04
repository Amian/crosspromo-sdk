import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Pulls a card's icon into the cache before the card is shown.
///
/// Prefetching the card JSON alone still leaves the icon downloading at the moment
/// the card appears, so it fades in a beat late. Warming it here means the bytes are
/// already in `URLCache` when the card asks for them.
public typealias CrossPromoIconWarmer = @Sendable (URL) -> Void

/// Uses `URLSession.shared` — the same session the card loads its icon through — so
/// the response lands in the cache the card actually reads. Deliberately silent: this
/// runs when nothing is on screen, so a failure must never surface.
func warmCrossPromoIcon(_ iconURL: URL) {
    Task { _ = try? await URLSession.shared.data(from: iconURL) }
}

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
    private let warmIcon: CrossPromoIconWarmer
    private var session: Session?

    /// The in-flight handshake, so simultaneous callers share one instead of each
    /// starting their own. Two cards appearing at once used to mean two handshakes.
    private var sessionTask: Task<Session, Error>?

    /// One card fetched ahead of being needed.
    ///
    /// A card is identical whichever slot it lands in — placement never affects which
    /// ad the backend picks — so a single held card can fill whichever placement
    /// appears first. It is single use, though — one card is one ad — so taking it
    /// removes it.
    private var prefetchedCard: PromoCardData?
    private var prefetchTask: Task<Void, Never>?

    /// Which slot each card was handed to, so its impression and click can report
    /// where it was actually shown. Bounded: cards are short-lived and only a couple
    /// are ever in flight.
    private var placementByCard: [String: String] = [:]

    public init(configuration: CrossPromoConfiguration) {
        self.configuration = configuration
        transport = URLSessionCrossPromoTransport(timeout: configuration.requestTimeout)
        deviceContext = AppleDeviceContextProvider()
        warmIcon = warmCrossPromoIcon
    }

    init(
        configuration: CrossPromoConfiguration,
        transport: any CrossPromoTransport,
        deviceContext: any CrossPromoDeviceContextProviding,
        iconWarmer: CrossPromoIconWarmer? = nil
    ) {
        self.configuration = configuration
        self.transport = transport
        self.deviceContext = deviceContext
        // Default to a no-op in tests: the real warmer would hit the network.
        warmIcon = iconWarmer ?? { _ in }
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
    public func prefetch() async {
        if let existing = prefetchTask {
            await existing.value
            return
        }
        if prefetchedCard != nil { return }
        let task = Task { await self.runPrefetch() }
        prefetchTask = task
        await task.value
    }

    /// Warms only the session handshake, for callers that want the credential ready
    /// without holding a card that could go stale.
    public func warmUp() async {
        _ = try? await validSession()
    }

    private func runPrefetch() async {
        defer { prefetchTask = nil }
        do {
            if let card = try await requestCard() {
                prefetchedCard = card
                // Pull the icon in too. Without this the card text would appear
                // instantly and the icon would still fade in a beat later.
                warmIcon(card.iconURL)
            }
        } catch {
            // Best effort: see prefetch's contract.
        }
    }

    public func fetchCard(placement: CrossPromoPlacement) async throws -> PromoCardData? {
        if let ready = takePrefetched() { return assign(ready, to: placement) }

        // A prefetch already on the wire: wait for it rather than starting a second
        // identical request and wasting the impression the first one is holding.
        if let inflight = prefetchTask {
            await inflight.value
            if let arrived = takePrefetched() { return assign(arrived, to: placement) }
        }
        guard let fresh = try await requestCard() else { return nil }
        return assign(fresh, to: placement)
    }

    private func takePrefetched() -> PromoCardData? {
        guard let held = prefetchedCard else { return nil }
        prefetchedCard = nil
        return held.expiresAt.timeIntervalSinceNow > Self.cardMinimumRemaining ? held : nil
    }

    /// Records which slot this card went to, so the impression and click that follow
    /// can say where it was really shown.
    private func assign(_ card: PromoCardData, to placement: CrossPromoPlacement) -> PromoCardData {
        if placementByCard.count >= 32, let oldest = placementByCard.keys.first {
            placementByCard.removeValue(forKey: oldest)
        }
        placementByCard[card.cardID] = placement.rawValue
        return card
    }

    /// The slot a card was shown in, for callers building the click link.
    public func placement(for card: PromoCardData) -> String? {
        placementByCard[card.cardID]
    }

    private func requestCard() async throws -> PromoCardData? {
        let session = try await validSession()
        // No placement: the backend returns the same card either way, and sending one
        // here would tie this card to a slot before we know where it will be shown.
        let response: CardResponse = try await request(
            path: "/v1/cards",
            method: "POST",
            body: CardRequest(placement: nil),
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
            ),
            placement: placementByCard[card.cardID]
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
    public nonisolated static let sdkVersion = "0.4.0"
    private static var configuredClient: CrossPromoClient?

    /// Everything an ad needs — the session handshake, one card, and its icon — is
    /// fetched in the background as soon as this is called, so the first card the app
    /// shows appears with no network wait.
    ///
    /// No placement is needed: a card is identical whichever slot it lands in, so the
    /// one held here fills whichever placement appears first, and reports that slot
    /// when it is actually seen. Pass `prefetch: false` to opt out.
    ///
    /// Best effort — it cannot throw into the caller, and anything that fails is
    /// simply fetched on demand instead.
    public static func configure(
        appKey: String,
        environment: CrossPromoConfiguration.Environment = .automatic,
        prefetch: Bool = true
    ) throws {
        let configuration = try CrossPromoConfiguration(appKey: appKey, environment: environment)
        let client = CrossPromoClient(configuration: configuration)
        configuredClient = client
        if prefetch {
            Task { await client.prefetch() }
        }
    }

    public static var client: CrossPromoClient {
        get throws {
            guard let configuredClient else { throw CrossPromoError.notConfigured }
            return configuredClient
        }
    }
}
