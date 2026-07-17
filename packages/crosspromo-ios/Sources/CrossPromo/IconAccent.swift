#if canImport(UIKit)
import UIKit

/// Dominant brand color extracted from a promoted app's icon, normalized so
/// every derived color stays rich, legible, and pleasant in both themes.
struct IconAccent: Equatable, Sendable {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat

    init(color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        self.hue = hue
        self.saturation = min(max(saturation, 0.55), 0.85)
        self.brightness = brightness
    }

    /// Downscales the icon and picks the strongest saturated hue family,
    /// ignoring transparent, near-white, near-black, and gray pixels.
    static func extract(from image: UIImage) -> IconAccent? {
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
        let color = UIColor(
            red: reds[best] / weights[best],
            green: greens[best] / weights[best],
            blue: blues[best] / weights[best],
            alpha: 1
        )
        return IconAccent(color: color)
    }

    /// Saturated fill for the call-to-action capsule.
    func ctaColor(darkTheme: Bool) -> UIColor {
        if darkTheme {
            return UIColor(
                hue: hue,
                saturation: min(saturation, 0.75),
                brightness: min(max(brightness, 0.62), 0.84),
                alpha: 1
            )
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: min(max(brightness, 0.5), 0.72),
            alpha: 1
        )
    }

    /// Text color on top of `ctaColor` — dark ink on bright accents (yellows,
    /// limes), white elsewhere, so the button never loses contrast.
    func onCtaColor(darkTheme: Bool) -> UIColor {
        if Self.relativeLuminance(of: ctaColor(darkTheme: darkTheme)) > 0.4 {
            return UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        }
        return .white
    }

    /// Whisper of brand color blended over the neutral card surface.
    func washColor(darkTheme: Bool) -> UIColor {
        UIColor(
            hue: hue,
            saturation: min(saturation, 0.8),
            brightness: darkTheme ? 0.72 : 0.56,
            alpha: darkTheme ? 0.13 : 0.06
        )
    }

    func hairlineColor(darkTheme: Bool) -> UIColor {
        UIColor(
            hue: hue,
            saturation: min(saturation, 0.8),
            brightness: darkTheme ? 0.78 : 0.5,
            alpha: darkTheme ? 0.38 : 0.26
        )
    }

    func glowColor(darkTheme: Bool) -> UIColor {
        UIColor(
            hue: hue,
            saturation: saturation,
            brightness: darkTheme ? 0.72 : 0.6,
            alpha: 1
        )
    }

    func chipBackgroundColor(darkTheme: Bool) -> UIColor {
        UIColor(
            hue: hue,
            saturation: min(saturation, 0.8),
            brightness: darkTheme ? 0.75 : 0.55,
            alpha: darkTheme ? 0.24 : 0.14
        )
    }

    func chipTextColor(darkTheme: Bool) -> UIColor {
        UIColor(
            hue: hue,
            saturation: min(saturation, 0.8),
            brightness: darkTheme ? 0.88 : 0.42,
            alpha: 1
        )
    }

    static func relativeLuminance(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        func linearize(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}
#endif
