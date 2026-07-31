#if canImport(UIKit)
import SwiftUI

/// A "More from the maker" icon shelf: two to four promoted apps laid out as
/// evenly spaced home-screen-style icons with no container chrome, so it sits
/// directly on the host background. Each entry is individually tappable.
public struct CrossPromoAppShelf: View {
    private let ads: [PromoAd]
    private let title: String
    private let opensLinks: Bool

    /// Creates a shelf from local data.
    /// - Parameters:
    ///   - ads: Two to four promoted apps. Anything past the fourth is ignored.
    ///   - title: Section header shown above the icons.
    ///   - opensLinks: When `true`, tapping an entry opens its click URL.
    public init(
        ads: [PromoAd],
        title: String = "More from the maker",
        opensLinks: Bool = false
    ) {
        self.ads = ads
        self.title = title
        self.opensLinks = opensLinks
    }

    private var entries: [PromoAd] { Array(ads.prefix(4)) }

    private var headerPalette: PromoPalette {
        entries.first.map(PromoPalette.init(ad:)) ?? PromoPalette(accent: nil)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                PromoAdBadge(palette: headerPalette)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, ad in
                    PromoShelfEntry(ad: ad, opensLinks: opensLinks)
                        .promoEntrance(delay: Double(index) * 0.05)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PromoShelfEntry: View {
    let ad: PromoAd
    let opensLinks: Bool

    private var palette: PromoPalette { PromoPalette(ad: ad) }

    var body: some View {
        VStack(spacing: 8) {
            PromoAdIcon(
                image: ad.icon,
                side: 64,
                cornerRadius: 14,
                palette: palette,
                glow: true
            )
            Text(ad.card.appName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 84)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .promoPressable {
            guard opensLinks else { return }
            promoOpen(ad.card)
        }
    }
}
#endif
