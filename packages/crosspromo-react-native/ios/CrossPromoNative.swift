import CryptoKit
import DeviceCheck
import Foundation
import React
import StoreKit
import UIKit

@objc(CrossPromoNative)
final class CrossPromoNative: NSObject {
    private enum Keys {
        static let installationID = "app.crosspromo.sdk.installation-id"
        static let appAttestKeyID = "app.crosspromo.sdk.app-attest-key-id"
    }

    @objc static func requiresMainQueueSetup() -> Bool { false }

    @objc(getAppContext:rejecter:)
    func getAppContext(
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        let bundle = Bundle.main
        resolve([
            "installation_id": installationID(),
            "platform": "ios",
            "bundle_id": bundle.bundleIdentifier ?? "unknown",
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            "build_number": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
        ])
    }

    @objc(prepareIntegrity:rejecter:)
    func prepareIntegrity(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task {
            let appAttest = DCAppAttestService.shared
            let transactionJWS = try? await AppTransaction.shared.jwsRepresentation
            guard appAttest.isSupported else {
                let response: [String: Any] = [
                    "provider": "none",
                    "key_id": NSNull(),
                    "app_transaction_jws": (transactionJWS as Any?) ?? NSNull(),
                    "device_verification_id": (AppStore.deviceVerificationID?.uuidString.lowercased() as Any?) ?? NSNull(),
                ]
                resolve(response)
                return
            }
            do {
                let keyID: String
                if let stored = UserDefaults.standard.string(forKey: Keys.appAttestKeyID) {
                    keyID = stored
                } else {
                    keyID = try await appAttest.generateKey()
                    UserDefaults.standard.set(keyID, forKey: Keys.appAttestKeyID)
                }
                let response: [String: Any] = [
                    "provider": "app_attest",
                    "key_id": keyID,
                    "app_transaction_jws": (transactionJWS as Any?) ?? NSNull(),
                    "device_verification_id": (AppStore.deviceVerificationID?.uuidString.lowercased() as Any?) ?? NSNull(),
                ]
                resolve(response)
            } catch {
                reject("integrity_prepare_failed", error.localizedDescription, error)
            }
        }
    }

    @objc(generateEvidence:resolver:rejecter:)
    func generateEvidence(
        input: [String: Any],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let mode = input["mode"] as? String,
              let challengeBase64 = input["challenge_base64"] as? String else {
            reject("invalid_arguments", "Challenge and mode are required", nil)
            return
        }
        if mode == "none" {
            let response: [String: Any] = [
                "provider": "none",
                "key_id": NSNull(),
                "payload_base64": "",
            ]
            resolve(response)
            return
        }
        guard let challenge = Data(base64Encoded: challengeBase64),
              let keyID = UserDefaults.standard.string(forKey: Keys.appAttestKeyID) else {
            reject("integrity_unavailable", "App Attest key or challenge is unavailable", nil)
            return
        }
        let hash = Data(SHA256.hash(data: challenge))
        Task {
            do {
                let payload: Data
                switch mode {
                case "attestation":
                    payload = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: hash)
                case "assertion":
                    payload = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: hash)
                default:
                    throw IntegrityError.invalidMode
                }
                resolve([
                    "provider": "app_attest",
                    "key_id": keyID,
                    "payload_base64": payload.base64EncodedString(),
                ])
            } catch {
                reject("integrity_evidence_failed", error.localizedDescription, error)
            }
        }
    }

    @objc(openUrl:resolver:rejecter:)
    func openUrl(
        value: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let url = URL(string: value) else {
            reject("invalid_url", "A valid URL is required", nil)
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url) { opened in
                if opened {
                    resolve(nil)
                } else {
                    reject("open_url_failed", "The URL could not be opened", nil)
                }
            }
        }
    }

    @objc(resetInstallationId:rejecter:)
    func resetInstallationId(
        resolve: RCTPromiseResolveBlock,
        reject _: RCTPromiseRejectBlock
    ) {
        UserDefaults.standard.removeObject(forKey: Keys.installationID)
        resolve(nil)
    }

    private func installationID() -> String {
        if let stored = UserDefaults.standard.string(forKey: Keys.installationID) {
            return stored
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: Keys.installationID)
        return value
    }
}

private enum IntegrityError: Error {
    case invalidMode
}
