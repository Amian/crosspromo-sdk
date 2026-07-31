#if canImport(UIKit)
import SwiftUI

/// A slim floating capsule, sized to its content, meant to hover over the
/// bottom of a screen the way the system's Now Playing pill does.
public struct CrossPromoAmbientPill: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let onDismiss: (() -> Void)?
    private let palette: PromoPalette
    @Environment(\.colorScheme) private var colorScheme

    /// Creates the pill. Set `opensLinks` to open the promoted app's link on
    /// tap; pass `onDismiss` to show the dismiss button.
    public init(ad: PromoAd, opensLinks: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.ad = ad
        self.opensLinks = opensLinks
        self.onDismiss = onDismiss
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        HStack(spacing: 10) {
            content
                .promoPressable { if opensLinks { promoOpen(ad.card) } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss ad")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, onDismiss == nil ? 12 : 10)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(palette.hairline(colorScheme), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        .promoEntrance()
    }

    private var content: some View {
        HStack(spacing: 8) {
            PromoAdIcon(image: ad.icon, side: 22, cornerRadius: 6, palette: palette)
            HStack(spacing: 0) {
                Text(ad.card.appName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(" · ")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
                Text(ad.card.tagline)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 260, alignment: .leading)
            PromoAdBadge(palette: palette)
        }
        .contentShape(Capsule(style: .continuous))
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? palette.glow(colorScheme).opacity(0.28)
            : .black.opacity(0.12)
    }
}
#endif
