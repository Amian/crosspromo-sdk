import Flutter
import StoreKit
import UIKit

public final class CrossPromoFlutterPlugin: NSObject, FlutterPlugin {
    private enum Keys {
        static let installationID = "app.crosspromo.sdk.installation-id"
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
            let transactionJWS = try? await AppTransaction.shared.jwsRepresentation
            result([
                "provider": "app_transaction",
                "app_transaction_jws": (transactionJWS as Any?) ?? NSNull(),
            ])
        }
    }

    private func generateEvidence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let mode = arguments["mode"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "Verification mode is required", details: nil))
            return
        }
        if mode == "none" {
            result([
                "provider": "none",
                "app_transaction_jws": NSNull(),
            ])
            return
        }
        guard mode == "app_transaction" else {
            result(FlutterError(code: "invalid_mode", message: "Unsupported verification mode", details: nil))
            return
        }
        Task {
            let transactionJWS = try? await AppTransaction.shared.jwsRepresentation
            result([
                "provider": "app_transaction",
                "app_transaction_jws": (transactionJWS as Any?) ?? NSNull(),
            ])
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

}
