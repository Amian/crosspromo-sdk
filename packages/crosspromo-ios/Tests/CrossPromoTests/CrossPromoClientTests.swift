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
            appKey: "cp_test_example",
            environment: .custom(URL(string: "https://example.test")!)
        )
        let client = CrossPromoClient(
            configuration: configuration,
            transport: transport,
            deviceContext: context
        )

        let card = try #require(await client.fetchCard(placement: "post_scan"))
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
        let app = try #require(challengeJSON["app"] as? [String: Any])
        #expect(app["bundle_id"] as? String == "app.example.publisher")
        #expect(app["version"] as? String == "3.2.1")
        let integrity = try #require(challengeJSON["integrity"] as? [String: Any])
        #expect(integrity["device_verification_id"] as? String == "device-verification-id")
        #expect(requests[3].value(forHTTPHeaderField: "Idempotency-Key") != nil)
    }

    @Test("does not send an impression below the threshold")
    func ignoresUnqualifiedImpression() async throws {
        let transport = MockTransport()
        let client = CrossPromoClient(
            configuration: try CrossPromoConfiguration(
                appKey: "cp_test_example",
                environment: .custom(URL(string: "https://example.test")!)
            ),
            transport: transport,
            deviceContext: MockDeviceContext()
        )
        let card = try #require(await client.fetchCard(placement: "settings"))
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
            json = #"{"session_id":"s_1","challenge_base64":"aGVsbG8=","integrity_mode":"attestation"}"#
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
            installationID: "install_1",
            app: AppDescriptor(
                platform: "ios",
                bundleID: "app.example.publisher",
                version: "3.2.1",
                buildNumber: "42"
            ),
            integrity: IntegrityPreparation(
                provider: "app_attest",
                keyID: "key_1",
                appTransactionJWS: "apple.signed.jws",
                deviceVerificationID: "device-verification-id"
            )
        )
    }

    func generateEvidence(challengeBase64: String, mode: String) async throws -> IntegrityEvidence {
        IntegrityEvidence(provider: "app_attest", keyID: "key_1", payloadBase64: "evidence")
    }

    func resetInstallationID() async {}
}
