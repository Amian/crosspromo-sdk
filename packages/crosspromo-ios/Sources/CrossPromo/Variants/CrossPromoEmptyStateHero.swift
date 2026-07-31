#if canImport(UIKit)
import SwiftUI
import UIKit

/// Centered hero for otherwise-empty screens — no container, so it reads as
/// part of the page rather than an ad slot.
public struct CrossPromoEmptyStateHero: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let palette: PromoPalette
    @Environment(\.colorScheme) private var colorScheme

    /// Creates the empty-state hero for one promoted app.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.ad = ad
        self.opensLinks = opensLinks
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(palette.glow(colorScheme).opacity(0.06))
                    .frame(width: 180, height: 180)
                    .promoEntrance(delay: 0.16)
                Circle()
                    .fill(palette.glow(colorScheme).opacity(0.10))
                    .frame(width: 132, height: 132)
                    .promoEntrance(delay: 0.08)
                PromoAdIcon(
                    image: ad.icon,
                    side: 88,
                    cornerRadius: 20,
                    palette: palette,
                    glow: true
                )
            }
            .frame(width: 180, height: 180)
            Text(ad.card.appName)
                .font(.title3.bold())
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 18)
            Text(ad.card.tagline)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 40)
                .padding(.top, 6)
            Text(ad.card.cta)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.onCta(colorScheme))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(palette.cta(colorScheme)))
                .padding(.top, 18)
            PromoAdBadge(palette: palette, detail: "Indie pick")
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .promoPressable(action: open)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .accessibilityAddTraits(.isButton)
        .promoEntrance()
    }

    private func open() {
        guard opensLinks else { return }
        promoOpen(ad.card)
    }
}
#endif
