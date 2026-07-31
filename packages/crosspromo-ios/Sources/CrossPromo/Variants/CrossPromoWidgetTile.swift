#if canImport(UIKit)
import SwiftUI

/// A 155×155pt square in small-home-screen-widget dress: washed accent
/// background, icon top-leading, quiet "Get" affordance along the bottom.
public struct CrossPromoWidgetTile: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Creates a widget-style tile from local data.
    /// - Parameters:
    ///   - ad: The promoted app.
    ///   - opensLinks: When `true`, tapping the tile opens its click URL.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.ad = ad
        self.opensLinks = opensLinks
    }

    private var palette: PromoPalette { PromoPalette(ad: ad) }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PromoAdIcon(
                image: ad.icon,
                side: 40,
                cornerRadius: 9,
                palette: palette,
                glow: true
            )
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(ad.card.appName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(ad.card.tagline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                Text("Get")
                    .font(.caption2.weight(.semibold))
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                Spacer(minLength: 6)
                PromoAdBadge(palette: palette)
            }
            .foregroundStyle(palette.chipText(colorScheme))
        }
        .padding(14)
        .frame(width: 155, height: 155, alignment: .topLeading)
        .background(shape.fill(washGradient))
        .overlay(shape.strokeBorder(palette.hairline(colorScheme), lineWidth: 1))
        .clipShape(shape)
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .promoPressable {
            guard opensLinks else { return }
            promoOpen(ad.card)
        }
        .promoEntrance()
    }

    private var washGradient: LinearGradient {
        LinearGradient(
            colors: [
                palette.washedSurface(colorScheme, intensity: 1.8),
                palette.washedSurface(colorScheme, intensity: 0.4),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
#endif
