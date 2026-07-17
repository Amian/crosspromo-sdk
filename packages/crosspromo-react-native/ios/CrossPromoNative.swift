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

    @objc(extractIconAccent:resolver:rejecter:)
    func extractIconAccent(
        value: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        guard let url = URL(string: value) else {
            resolve(NSNull())
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  let accent = Self.dominantColor(of: image) else {
                resolve(NSNull())
                return
            }
            resolve(["red": accent.red, "green": accent.green, "blue": accent.blue])
        }
    }

    /// Strongest saturated hue family in the icon, ignoring transparent,
    /// near-white, near-black, and gray pixels. Mirrors the algorithm used by
    /// the native iOS and Flutter SDK cards.
    private static func dominantColor(of image: UIImage) -> (red: Int, green: Int, blue: Int)? {
        guard let cgImage = image.cgImage else { return nil }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        let bucketCount = 12
        var weights = [Double](repeating: 0, count: bucketCount)
        var counts = [Int](repeating: 0, count: bucketCount)
        var reds = [Double](repeating: 0, count: bucketCount)
        var greens = [Double](repeating: 0, count: bucketCount)
        var blues = [Double](repeating: 0, count: bucketCount)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3])
            guard alpha >= 160 else { continue }
            let red = min(1, Double(pixels[index]) / alpha)
            let green = min(1, Double(pixels[index + 1]) / alpha)
            let blue = min(1, Double(pixels[index + 2]) / alpha)
            let value = max(red, green, blue)
            let chroma = value - min(red, green, blue)
            let saturation = value == 0 ? 0 : chroma / value
            if value < 0.16 || saturation < 0.16 { continue }
            if value > 0.95, saturation < 0.2 { continue }
            var hue: Double = 0
            if chroma > 0 {
                if value == red {
                    hue = ((green - blue) / chroma).truncatingRemainder(dividingBy: 6)
                } else if value == green {
                    hue = (blue - red) / chroma + 2
                } else {
                    hue = (red - green) / chroma + 4
                }
                hue /= 6
                if hue < 0 { hue += 1 }
            }
            let bucket = min(bucketCount - 1, Int(hue * Double(bucketCount)))
            let weight = saturation * saturation * value
            weights[bucket] += weight
            counts[bucket] += 1
            reds[bucket] += red * weight
            greens[bucket] += green * weight
            blues[bucket] += blue * weight
        }

        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }),
              counts[best] >= 20, weights[best] > 0 else { return nil }
        return (
            red: Int((reds[best] / weights[best] * 255).rounded()),
            green: Int((greens[best] / weights[best] * 255).rounded()),
            blue: Int((blues[best] / weights[best] * 255).rounded())
        )
    }

}
