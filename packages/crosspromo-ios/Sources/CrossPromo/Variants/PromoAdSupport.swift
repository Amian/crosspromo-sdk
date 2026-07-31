#if canImport(UIKit)
import SwiftUI
import UIKit

/// One promoted app, fully local: card data + icon + optional explicit accent.
public struct PromoAd: Identifiable {
    public let card: PromoCardData
    public let icon: UIImage
    public let accentColor: UIColor?

    public var id: String { card.cardID }

    public init(card: PromoCardData, icon: UIImage, accentColor: UIColor? = nil) {
        self.card = card
        self.icon = icon
        self.accentColor = accentColor
    }
}

/// Every color a variant needs, derived from the icon exactly like the
/// production card does. Accessors take the scheme rather than reading the
/// environment so containers can resolve colors for gradients and shadows.
struct PromoPalette: Equatable, Sendable {
    let accent: IconAccent?

    var hasAccent: Bool { accent != nil }

    init(ad: PromoAd) {
        accent = ad.accentColor.map(IconAccent.init(color:))
            ?? IconAccent.extract(from: ad.icon)
    }

    init(accent: IconAccent?) {
        self.accent = accent
    }

    func surface(_ scheme: ColorScheme) -> Color {
        washedSurface(scheme)
    }

    /// Base surface with the accent wash composited over it. `intensity` scales
    /// the wash alpha so gradients can lean on a stronger or fainter tint.
    func washedSurface(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        let dark = scheme == .dark
        let base = dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.125, alpha: 1)
            : UIColor.white
        guard let accent else { return Color(uiColor: base) }
        let wash = accent.washColor(darkTheme: dark)
        let tinted = intensity == 1
            ? wash
            : wash.withAlphaComponent(wash.cgColor.alpha * CGFloat(intensity))
        return Color(uiColor: PromoPalette.blend(tinted, over: base))
    }

    func hairline(_ scheme: ColorScheme) -> Color {
        guard let accent else { return Color(uiColor: .separator) }
        return Color(uiColor: accent.hairlineColor(darkTheme: scheme == .dark))
    }

    func wash(_ scheme: ColorScheme) -> Color {
        guard let accent else { return .clear }
        return Color(uiColor: accent.washColor(darkTheme: scheme == .dark))
    }

    func cta(_ scheme: ColorScheme) -> Color {
        guard let accent else { return Color(uiColor: .systemBlue) }
        return Color(uiColor: accent.ctaColor(darkTheme: scheme == .dark))
    }

    func onCta(_ scheme: ColorScheme) -> Color {
        guard let accent else { return .white }
        return Color(uiColor: accent.onCtaColor(darkTheme: scheme == .dark))
    }

    func chipBackground(_ scheme: ColorScheme) -> Color {
        guard let accent else { return Color(uiColor: .secondarySystemFill) }
        return Color(uiColor: accent.chipBackgroundColor(darkTheme: scheme == .dark))
    }

    func chipText(_ scheme: ColorScheme) -> Color {
        guard let accent else { return Color(uiColor: .secondaryLabel) }
        return Color(uiColor: accent.chipTextColor(darkTheme: scheme == .dark))
    }

    func glow(_ scheme: ColorScheme) -> Color {
        guard let accent else { return .clear }
        return Color(uiColor: accent.glowColor(darkTheme: scheme == .dark))
    }

    private static func blend(_ top: UIColor, over base: UIColor) -> UIColor {
        var topRed: CGFloat = 0
        var topGreen: CGFloat = 0
        var topBlue: CGFloat = 0
        var topAlpha: CGFloat = 0
        top.getRed(&topRed, green: &topGreen, blue: &topBlue, alpha: &topAlpha)
        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: nil)
        return UIColor(
            red: topRed * topAlpha + baseRed * (1 - topAlpha),
            green: topGreen * topAlpha + baseGreen * (1 - topAlpha),
            blue: topBlue * topAlpha + baseBlue * (1 - topAlpha),
            alpha: 1
        )
    }
}

/// The "AD" disclosure chip, optionally followed by a short qualifier such as
/// "Indie pick".
struct PromoAdBadge: View {
    private let palette: PromoPalette
    private let detail: String?
    @Environment(\.colorScheme) private var colorScheme

    init(palette: PromoPalette, detail: String? = nil) {
        self.palette = palette
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("AD")
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.8)
                .foregroundStyle(palette.chipText(colorScheme))
                .padding(.vertical, 2.5)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(palette.chipBackground(colorScheme))
                )
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// App icon with the card's continuous corners, hairline border, and optional
/// accent glow.
struct PromoAdIcon: View {
    private let image: UIImage
    private let side: CGFloat
    private let cornerRadius: CGFloat
    private let palette: PromoPalette
    private let glow: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        image: UIImage,
        side: CGFloat,
        cornerRadius: CGFloat,
        palette: PromoPalette,
        glow: Bool = false
    ) {
        self.image = image
        self.side = side
        self.cornerRadius = cornerRadius
        self.palette = palette
        self.glow = glow
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: glowColor, radius: 9, x: 0, y: 3)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.16) : .black.opacity(0.08)
    }

    private var glowColor: Color {
        guard glow else { return .clear }
        return palette.glow(colorScheme).opacity(colorScheme == .dark ? 0.5 : 0.32)
    }
}

private struct PromoEntranceModifier: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || shown ? 1 : 0)
            .offset(y: reduceMotion || shown ? 0 : 10)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(delay)) {
                    shown = true
                }
            }
    }
}

struct PromoPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension View {
    func promoEntrance(delay: Double = 0) -> some View {
        modifier(PromoEntranceModifier(delay: delay))
    }

    /// Wraps the view in a plain `Button` so it picks up the button trait and
    /// hit testing for free, then adds the shared press feedback.
    func promoPressable(action: @escaping () -> Void) -> some View {
        Button(action: action) { self }
            .buttonStyle(PromoPressableButtonStyle())
    }
}

@MainActor
func promoOpen(_ card: PromoCardData) {
    UIApplication.shared.open(card.clickURL)
}
#endif
