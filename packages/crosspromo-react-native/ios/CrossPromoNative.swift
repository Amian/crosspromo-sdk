import Foundation
import React
import StoreKit
import UIKit

@objc(CrossPromoNative)
final class CrossPromoNative: NSObject {
    @objc static func requiresMainQueueSetup() -> Bool { false }

    @objc(getAppContext:rejecter:)
    func getAppContext(
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        let bundle = Bundle.main
        resolve([
            "platform": "ios",
            "bundle_id": bundle.bundleIdentifier ?? "unknown",
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            "build_number": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
        ])
    }

    @objc(generateEvidence:resolver:rejecter:)
    func generateEvidence(
        input: [String: Any],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let mode = input["mode"] as? String else {
            reject("invalid_arguments", "Verification mode is required", nil)
            return
        }
        if mode == "none" {
            resolve([
                "provider": "none",
                "app_transaction_jws": NSNull(),
            ])
            return
        }
        guard mode == "app_transaction" else {
            reject("invalid_mode", "Unsupported verification mode", nil)
            return
        }
        Task {
            let transactionJWS = try? await AppTransaction.shared.jwsRepresentation
            resolve([
                "provider": "app_transaction",
                "app_transaction_jws": (transactionJWS as Any?) ?? NSNull(),
            ])
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

}
