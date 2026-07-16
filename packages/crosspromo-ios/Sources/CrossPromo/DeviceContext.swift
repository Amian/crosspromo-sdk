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
    }

    private let defaults: UserDefaults
    private let bundle: Bundle
    private var cachedAppTransactionJWS: String?

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.defaults = defaults
        self.bundle = bundle
    }

    func snapshot() async throws -> DeviceSnapshot {
        let installationID = currentInstallationID()
        let app = AppDescriptor(
            platform: "ios",
            bundleID: bundle.bundleIdentifier ?? "unknown",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )

        return DeviceSnapshot(
            installationID: installationID,
            app: app,
            integrity: IntegrityPreparation(
                provider: "app_transaction",
                appTransactionJWS: await appTransactionJWS()
            )
        )
    }

    func generateEvidence(challengeBase64 _: String, mode: String) async throws -> IntegrityEvidence {
        switch mode {
        case "none":
            return IntegrityEvidence(provider: "none", appTransactionJWS: nil)
        case "app_transaction":
            return IntegrityEvidence(
                provider: "app_transaction",
                appTransactionJWS: await appTransactionJWS()
            )
        default:
            throw CrossPromoError.invalidResponse
        }
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
        if let cachedAppTransactionJWS {
            return cachedAppTransactionJWS
        }
        guard #available(iOS 16.0, macOS 13.0, *) else { return nil }
        do {
            let value = try await AppTransaction.shared.jwsRepresentation
            cachedAppTransactionJWS = value
            return value
        } catch {
            return nil
        }
    }
}
