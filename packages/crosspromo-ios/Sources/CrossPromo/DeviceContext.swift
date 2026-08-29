import Foundation
import StoreKit

protocol CrossPromoDeviceContextProviding: Sendable {
    func snapshot() async throws -> DeviceSnapshot
    func generateEvidence(challengeBase64: String, mode: String) async throws -> IntegrityEvidence
}

enum CrossPromoRuntimePlatform {
    static var identifier: String {
        #if os(macOS)
        "macos"
        #elseif canImport(UIKit)
        // Preserve the SDK's existing UIKit-family wire value. A future native
        // service identifier can be introduced here without changing consumers.
        "ios"
        #else
        #error("CrossPromo needs an explicit platform identifier before enabling a new platform")
        #endif
    }
}

actor AppleDeviceContextProvider: CrossPromoDeviceContextProviding {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func snapshot() async throws -> DeviceSnapshot {
        let app = AppDescriptor(
            platform: CrossPromoRuntimePlatform.identifier,
            bundleID: bundle.bundleIdentifier ?? "unknown",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )

        return DeviceSnapshot(app: app)
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

    private func appTransactionJWS() async -> String? {
        guard #available(iOS 16.0, macOS 13.0, *) else { return nil }
        do {
            return try await AppTransaction.shared.jwsRepresentation
        } catch {
            return nil
        }
    }
}
