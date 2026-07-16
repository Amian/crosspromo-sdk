import CryptoKit
import DeviceCheck
import Flutter
import StoreKit
import UIKit

public final class CrossPromoFlutterPlugin: NSObject, FlutterPlugin {
    private enum Keys {
        static let installationID = "app.crosspromo.sdk.installation-id"
        static let appAttestKeyID = "app.crosspromo.sdk.app-attest-key-id"
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "app.crosspromo/sdk",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(CrossPromoFlutterPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAppContext":
            let bundle = Bundle.main
            result([
                "installation_id": installationID(),
                "platform": "ios",
                "bundle_id": bundle.bundleIdentifier ?? "unknown",
                "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                "build_number": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
            ])
        case "prepareIntegrity":
            prepareIntegrity(result: result)
        case "generateEvidence":
            generateEvidence(call: call, result: result)
        case "openUrl":
            guard let arguments = call.arguments as? [String: Any],
                  let value = arguments["url"] as? String,
                  let url = URL(string: value) else {
                result(FlutterError(code: "invalid_url", message: "A valid URL is required", details: nil))
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.open(url) { opened in result(opened) }
            }
        case "resetInstallationId":
            UserDefaults.standard.removeObject(forKey: Keys.installationID)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func prepareIntegrity(result: @escaping FlutterResult) {
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
                result(response)
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
                result(response)
            } catch {
                result(flutterError(error, code: "integrity_prepare_failed"))
            }
        }
    }

    private func generateEvidence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let challengeBase64 = arguments["challenge_base64"] as? String,
              let mode = arguments["mode"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "Challenge and mode are required", details: nil))
            return
        }
        if mode == "none" {
            let response: [String: Any] = [
                "provider": "none",
                "key_id": NSNull(),
                "payload_base64": "",
            ]
            result(response)
            return
        }
        guard let challenge = Data(base64Encoded: challengeBase64),
              let keyID = UserDefaults.standard.string(forKey: Keys.appAttestKeyID) else {
            result(FlutterError(code: "integrity_unavailable", message: "App Attest key or challenge is unavailable", details: nil))
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
                result([
                    "provider": "app_attest",
                    "key_id": keyID,
                    "payload_base64": payload.base64EncodedString(),
                ])
            } catch {
                result(flutterError(error, code: "integrity_evidence_failed"))
            }
        }
    }

    private func installationID() -> String {
        if let stored = UserDefaults.standard.string(forKey: Keys.installationID) {
            return stored
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: Keys.installationID)
        return value
    }

    private func flutterError(_ error: Error, code: String) -> FlutterError {
        FlutterError(code: code, message: error.localizedDescription, details: nil)
    }
}

private enum IntegrityError: Error {
    case invalidMode
}
