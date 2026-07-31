#if canImport(UIKit)
import SwiftUI

/// The quietest placement: a single centered colophon line for the end of a
/// scroll or settings page.
public struct CrossPromoFooterBadge: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let palette: PromoPalette

    /// Creates the footer line. Set `opensLinks` to open the promoted app's
    /// link on tap.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.ad = ad
        self.opensLinks = opensLinks
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        HStack(spacing: 8) {
            PromoAdIcon(image: ad.icon, side: 18, cornerRadius: 5, palette: palette)
            Text("From the makers of \(ad.card.appName)")
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
            PromoAdBadge(palette: palette)
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .promoPressable { if opensLinks { promoOpen(ad.card) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .promoEntrance()
    }
}
#endif
