import CryptoKit
import DeviceCheck
import Foundation
import StoreKit

protocol CrossPromoDeviceContextProviding: Sendable {
    func snapshot() async throws -> DeviceSnapshot
    func generateEvidence(challengeBase64: String, mode: String) async throws -> IntegrityEvidence
    func resetInstallationID() async
}

actor AppleDeviceContextProvider: CrossPromoDeviceContextProviding {
    private enum Keys {
        static let installationID = "app.crosspromo.sdk.installation-id"
        static let appAttestKeyID = "app.crosspromo.sdk.app-attest-key-id"
    }

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let appAttest: DCAppAttestService

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        appAttest: DCAppAttestService = .shared
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.appAttest = appAttest
    }

    func snapshot() async throws -> DeviceSnapshot {
        let installationID = currentInstallationID()
        let app = AppDescriptor(
            platform: "ios",
            bundleID: bundle.bundleIdentifier ?? "unknown",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )

        guard appAttest.isSupported else {
            return DeviceSnapshot(
                installationID: installationID,
                app: app,
                integrity: IntegrityPreparation(
                    provider: "none",
                    keyID: nil,
                    appTransactionJWS: await appTransactionJWS(),
                    deviceVerificationID: AppStore.deviceVerificationID?.uuidString.lowercased()
                )
            )
        }

        let keyID: String
        if let stored = defaults.string(forKey: Keys.appAttestKeyID) {
            keyID = stored
        } else {
            keyID = try await appAttest.generateKey()
            defaults.set(keyID, forKey: Keys.appAttestKeyID)
        }

        return DeviceSnapshot(
            installationID: installationID,
            app: app,
            integrity: IntegrityPreparation(
                provider: "app_attest",
                keyID: keyID,
                appTransactionJWS: await appTransactionJWS(),
                deviceVerificationID: AppStore.deviceVerificationID?.uuidString.lowercased()
            )
        )
    }

    func generateEvidence(challengeBase64: String, mode: String) async throws -> IntegrityEvidence {
        guard appAttest.isSupported else {
            throw CrossPromoError.integrityUnavailable("App Attest is not supported on this device")
        }
        guard let keyID = defaults.string(forKey: Keys.appAttestKeyID) else {
            throw CrossPromoError.integrityUnavailable("No App Attest key is available")
        }
        guard let challenge = Data(base64Encoded: challengeBase64) else {
            throw CrossPromoError.invalidResponse
        }

        let digest = Data(SHA256.hash(data: challenge))
        let payload: Data
        switch mode {
        case "attestation":
            payload = try await appAttest.attestKey(keyID, clientDataHash: digest)
        case "assertion":
            payload = try await appAttest.generateAssertion(keyID, clientDataHash: digest)
        default:
            throw CrossPromoError.invalidResponse
        }

        return IntegrityEvidence(
            provider: "app_attest",
            keyID: keyID,
            payloadBase64: payload.base64EncodedString()
        )
    }

    func resetInstallationID() {
        defaults.removeObject(forKey: Keys.installationID)
    }

    private func currentInstallationID() -> String {
        if let existing = defaults.string(forKey: Keys.installationID) {
            return existing
        }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: Keys.installationID)
        return value
    }

    private func appTransactionJWS() async -> String? {
        guard #available(iOS 16.0, macOS 13.0, *) else { return nil }
        do {
            return try await AppTransaction.shared.jwsRepresentation
        } catch {
            return nil
        }
    }
}
