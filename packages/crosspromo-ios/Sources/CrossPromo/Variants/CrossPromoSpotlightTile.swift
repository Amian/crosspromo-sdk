#if canImport(UIKit)
import SwiftUI
import UIKit

/// Editorial feature tile with App Store "Today"-card energy, sized to sit in a
/// feed. Renders local data only; tapping opens the promoted app when
/// `opensLinks` is true.
public struct CrossPromoSpotlightTile: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let palette: PromoPalette
    @Environment(\.colorScheme) private var colorScheme

    /// Creates the tile for one promoted app.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.ad = ad
        self.opensLinks = opensLinks
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(palette.hairline(colorScheme), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0 : 0.07),
                radius: 14,
                x: 0,
                y: 6
            )
            .promoPressable(action: open)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
            .accessibilityAddTraits(.isButton)
            .promoEntrance()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("FROM AN INDIE STUDIO")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(palette.chipText(colorScheme))
                    .lineLimit(1)
                Spacer(minLength: 8)
                PromoAdBadge(palette: palette)
            }
            Spacer(minLength: 14)
            PromoAdIcon(
                image: ad.icon,
                side: 56,
                cornerRadius: 14,
                palette: palette,
                glow: true
            )
            .padding(.bottom, 12)
            Text(ad.card.appName)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(2)
            Text(ad.card.tagline)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(2)
                .padding(.top, 3)
            HStack(spacing: 0) {
                Text(ad.card.cta)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.onCta(colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(palette.cta(colorScheme)))
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                palette.washedSurface(colorScheme, intensity: 0),
                palette.washedSurface(colorScheme, intensity: colorScheme == .dark ? 1.55 : 2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [palette.glow(colorScheme).opacity(0.12), .clear],
                center: UnitPoint(x: 0.16, y: 0.52),
                startRadius: 0,
                endRadius: 170
            )
        )
    }

    private func open() {
        guard opensLinks else { return }
        promoOpen(ad.card)
    }
}
#endif
