import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import CrossPromo

@Suite("CrossPromo client")
struct CrossPromoClientTests {
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
        #expect(sdk["version"] as? String == "0.3.2")
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
}

private actor MockTransport: CrossPromoTransport {
    var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url?.path
        let json: String
        switch path {
        case "/v1/sdk/sessions/challenge":
            json = #"{"session_id":"s_1","challenge_base64":"aGVsbG8=","integrity_mode":"app_transaction"}"#
        case "/v1/sdk/sessions/verify":
            json = #"{"access_token":"token","publisher_app_id":"app_1","counts_enabled":true,"reason":null,"expires_at":"2099-01-01T00:00:00Z"}"#
        case "/v1/cards":
            json = #"{"card":{"card_id":"c_1","app_name":"Rock Finder","icon_url":"https://cdn.example/icon.png","tagline":"Find every rock","cta":"Get","click_url":"https://go.example/c/1","impression_token":"imp_1","expires_at":"2099-01-01T00:00:00Z"}}"#
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
