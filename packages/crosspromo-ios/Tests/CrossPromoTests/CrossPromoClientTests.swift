import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import CrossPromo

@Suite("CrossPromo client")
struct CrossPromoClientTests {
    @Test("automatically selects the build environment")
    func automaticBuildEnvironment() throws {
        let configuration = try CrossPromoConfiguration(appKey: "cp_live_example")
        #if DEBUG
        #expect(configuration.environment.requestValue == "sandbox")
        #else
        #expect(configuration.environment.requestValue == "production")
        #endif
    }

    @Test("collects app metadata and reports a qualified impression")
    func sessionCardAndImpression() async throws {
        let transport = MockTransport()
        let context = MockDeviceContext()
        let configuration = try CrossPromoConfiguration(
            appKey: "cp_live_example",
            environment: .custom(URL(string: "https://example.test")!)
        )
        let client = CrossPromoClient(
            configuration: configuration,
            transport: transport,
            deviceContext: context
        )

        let card = try #require(await client.fetchCard(placement: .postScan))
        try await client.recordImpression(for: card, visibleFraction: 0.75, duration: 1.1)

        let requests = await transport.requests
        #expect(requests.map(\.url?.path) == [
            "/v1/sdk/sessions/challenge",
            "/v1/sdk/sessions/verify",
            "/v1/cards",
            "/v1/events/impressions",
        ])
        let challengeBody = try #require(requests[0].httpBody)
        let challengeJSON = try #require(
            JSONSerialization.jsonObject(with: challengeBody) as? [String: Any]
        )
        #expect(challengeJSON["environment"] as? String == "production")
        let app = try #require(challengeJSON["app"] as? [String: Any])
        let sdk = try #require(challengeJSON["sdk"] as? [String: Any])
        #expect(app["bundle_id"] as? String == "app.example.publisher")
        #expect(app["version"] as? String == "3.2.1")
        #expect(sdk["version"] as? String == "0.3.5")
        #expect(challengeJSON["installation_id"] == nil)
        #expect(challengeJSON["locale"] == nil)
        #expect(challengeJSON["integrity"] == nil)
        let verifyBody = try #require(requests[1].httpBody)
        let verifyJSON = try #require(
            JSONSerialization.jsonObject(with: verifyBody) as? [String: Any]
        )
        let evidence = try #require(verifyJSON["evidence"] as? [String: Any])
        #expect(evidence["provider"] as? String == "app_transaction")
        #expect(evidence["app_transaction_jws"] as? String == "apple.signed.jws")
        let cardBody = try #require(requests[2].httpBody)
        let cardJSON = try #require(
            JSONSerialization.jsonObject(with: cardBody) as? [String: Any]
        )
        #expect(cardJSON["placement"] as? String == "post_scan")
        #expect(requests[3].value(forHTTPHeaderField: "Idempotency-Key") != nil)
    }

    @Test("does not send an impression below the threshold")
    func ignoresUnqualifiedImpression() async throws {
        let transport = MockTransport()
        let client = CrossPromoClient(
            configuration: try CrossPromoConfiguration(
                appKey: "cp_live_example",
                environment: .custom(URL(string: "https://example.test")!)
            ),
            transport: transport,
            deviceContext: MockDeviceContext()
        )
        let card = try #require(await client.fetchCard(placement: .settings))
        try await client.recordImpression(for: card, visibleFraction: 0.49, duration: 4)
        #expect(await transport.requests.count == 3)
    }

    @Test("a prefetched card is served without any further network call")
    func prefetchServesWithoutNetwork() async throws {
        let transport = MockTransport()
        let client = try makeClient(transport)

        await client.prefetch(placement: .postScan)
        #expect(await transport.requests.map(\.url?.path) == [
            "/v1/sdk/sessions/challenge",
            "/v1/sdk/sessions/verify",
            "/v1/cards",
        ])

        let card = try #require(await client.fetchCard(placement: .postScan))
        #expect(card.cardID == "c_1")
        #expect(await transport.requests.count == 3, "showing a prefetched card must not touch the network")
    }

    @Test("a prefetched card is single use, because its impression token is")
    func prefetchedCardIsSingleUse() async throws {
        let transport = MockTransport()
        let client = try makeClient(transport)

        await client.prefetch(placement: .postScan)
        let first = try #require(await client.fetchCard(placement: .postScan))
        let second = try #require(await client.fetchCard(placement: .postScan))

        #expect(first.cardID == "c_1")
        #expect(second.cardID == "c_2", "the second card must be a fresh one")
        #expect(first.impressionToken != second.impressionToken)
        #expect(await transport.cardRequestCount == 2)
    }

    @Test("a prefetched card for another placement is not reused")
    func prefetchIsPerPlacement() async throws {
        let transport = MockTransport()
        let client = try makeClient(transport)

        await client.prefetch(placement: .postScan)
        let card = try #require(await client.fetchCard(placement: .settings))

        #expect(card.cardID == "c_2")
        #expect(await transport.cardRequestCount == 2)
    }

    @Test("a prefetched card too close to expiry is discarded, not shown")
    func stalePrefetchedCardIsRefetched() async throws {
        // Below the client's freshness margin: it could expire before the viewability
        // window it is about to be measured against completes.
        let transport = MockTransport(cardLifetime: 5)
        let client = try makeClient(transport)

        await client.prefetch(placement: .postScan)
        #expect(await transport.cardRequestCount == 1)

        let card = try #require(await client.fetchCard(placement: .postScan))
        #expect(await transport.cardRequestCount == 2, "the stale card is refetched")
        #expect(card.cardID == "c_2")
    }

    @Test("simultaneous cards share a single session handshake")
    func concurrentCardsShareOneHandshake() async throws {
        let transport = MockTransport()
        let client = try makeClient(transport)

        // Two placements appearing at once previously raced into two full handshakes,
        // because nothing tracked the session request already in flight.
        async let first = client.fetchCard(placement: .postScan)
        async let second = client.fetchCard(placement: .settings)
        _ = try await (first, second)

        #expect(await transport.requestCount(for: "/v1/sdk/sessions/challenge") == 1)
        #expect(await transport.requestCount(for: "/v1/sdk/sessions/verify") == 1)
        #expect(await transport.cardRequestCount == 2)
    }

    @Test("session and card timestamps decode with or without fractional seconds")
    func decodesBackendTimestamps() throws {
        // The Node backend sends `new Date().toISOString()`, which ALWAYS carries
        // milliseconds. JSONDecoder's built-in .iso8601 strategy rejects those, so
        // every real session response failed to decode and no session could ever be
        // established. Every fixture here previously used whole seconds, which is
        // exactly why that went unnoticed.
        struct Stamped: Decodable { let expiresAt: Date }
        func decode(_ text: String) throws -> Date {
            try CrossPromoCoding.decoder
                .decode(Stamped.self, from: Data(#"{"expiresAt":"\#(text)"}"#.utf8))
                .expiresAt
        }

        // Both shapes must parse, and must agree on the instant they describe.
        let withMilliseconds = try decode("2026-07-31T00:37:25.742Z")
        let wholeSeconds = try decode("2026-07-31T00:37:25Z")
        #expect(abs(withMilliseconds.timeIntervalSince(wholeSeconds) - 0.742) < 0.01)

        // And a garbage value must still be rejected rather than silently accepted.
        #expect(throws: (any Error).self) { try decode("not-a-date") }
    }

    @Test("a card served with millisecond timestamps is usable end to end")
    func cardWithFractionalTimestamps() async throws {
        let transport = MockTransport(fractionalTimestamps: true)
        let client = try makeClient(transport)

        let card = try #require(await client.fetchCard(placement: .postScan))

        #expect(card.cardID == "c_1")
        #expect(await transport.requestCount(for: "/v1/cards") == 1)
    }

    @Test("prefetching also warms the card icon")
    func prefetchWarmsIcon() async throws {
        let transport = MockTransport()
        let warmed = IconWarmRecorder()
        let client = try makeClient(transport, iconWarmer: { url in warmed.record(url) })

        await client.prefetch(placement: .postScan)

        #expect(warmed.urls == [URL(string: "https://cdn.example/icon.png")!])
    }

    @Test("a prefetch that returns no card warms nothing")
    func failedPrefetchWarmsNothing() async throws {
        let transport = MockTransport(failCards: true)
        let warmed = IconWarmRecorder()
        let client = try makeClient(transport, iconWarmer: { url in warmed.record(url) })

        await client.prefetch(placement: .postScan)

        #expect(warmed.urls.isEmpty)
    }

    @Test("concurrent prefetches for one placement share a single fetch")
    func concurrentPrefetchesShareOneFetch() async throws {
        let transport = MockTransport()
        let client = try makeClient(transport)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask { await client.prefetch(placement: .postScan) }
            }
        }

        #expect(await transport.cardRequestCount == 1)
        #expect(await transport.requestCount(for: "/v1/sdk/sessions/challenge") == 1)
    }
}

private func makeClient(
    _ transport: MockTransport,
    iconWarmer: CrossPromoIconWarmer? = nil
) throws -> CrossPromoClient {
    CrossPromoClient(
        configuration: try CrossPromoConfiguration(
            appKey: "cp_live_example",
            environment: .custom(URL(string: "https://example.test")!)
        ),
        transport: transport,
        deviceContext: MockDeviceContext(),
        iconWarmer: iconWarmer
    )
}

/// The warmer is a plain synchronous @Sendable closure, so it cannot await an actor.
private final class IconWarmRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func record(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private actor MockTransport: CrossPromoTransport {
    /// How long each served card stays valid. Nil means the far future.
    private let cardLifetime: TimeInterval?
    /// Makes `/v1/cards` fail, to prove a failed prefetch stays invisible.
    private let failCards: Bool
    /// Emits timestamps the way the Node backend really does, with milliseconds.
    private let fractionalTimestamps: Bool
    var requests: [URLRequest] = []
    private var cardsServed = 0

    init(
        cardLifetime: TimeInterval? = nil,
        failCards: Bool = false,
        fractionalTimestamps: Bool = false
    ) {
        self.cardLifetime = cardLifetime
        self.failCards = failCards
        self.fractionalTimestamps = fractionalTimestamps
    }

    private var farFuture: String {
        fractionalTimestamps ? "2099-01-01T00:00:00.742Z" : "2099-01-01T00:00:00Z"
    }

    var cardRequestCount: Int {
        requests.filter { $0.url?.path == "/v1/cards" }.count
    }

    func requestCount(for path: String) -> Int {
        requests.filter { $0.url?.path == path }.count
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url?.path
        let json: String
        switch path {
        case "/v1/sdk/sessions/challenge":
            json = #"{"session_id":"s_1","challenge_base64":"aGVsbG8=","integrity_mode":"app_transaction"}"#
        case "/v1/sdk/sessions/verify":
            json = """
            {"access_token":"token","publisher_app_id":"app_1","counts_enabled":true,\
            "reason":null,"expires_at":"\(farFuture)"}
            """
        case "/v1/cards" where failCards:
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil
            )!
            return (Data("{}".utf8), response)
        case "/v1/cards":
            cardsServed += 1
            let expiresAt: String
            if let cardLifetime {
                expiresAt = ISO8601DateFormatter().string(
                    from: Date().addingTimeInterval(cardLifetime)
                )
            } else {
                expiresAt = farFuture
            }
            json = """
            {"card":{"card_id":"c_\(cardsServed)","app_name":"Rock Finder",\
            "icon_url":"https://cdn.example/icon.png","tagline":"Find every rock",\
            "cta":"Get","click_url":"https://go.example/c/1",\
            "impression_token":"imp_\(cardsServed)","expires_at":"\(expiresAt)"}}
            """
        case "/v1/events/impressions":
            json = ""
        default:
            Issue.record("Unexpected path: \(path ?? "nil")")
            json = "{}"
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(json.utf8), response)
    }
}

private actor MockDeviceContext: CrossPromoDeviceContextProviding {
    func snapshot() async throws -> DeviceSnapshot {
        DeviceSnapshot(
            app: AppDescriptor(
                platform: "ios",
                bundleID: "app.example.publisher",
                version: "3.2.1",
                buildNumber: "42"
            )
        )
    }

    func generateEvidence(challengeBase64: String, mode: String) async throws -> IntegrityEvidence {
        IntegrityEvidence(provider: "app_transaction", appTransactionJWS: "apple.signed.jws")
    }
}
