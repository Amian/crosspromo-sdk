#if canImport(UIKit)
import SwiftUI

/// A promotion shaped like a native inset-grouped settings row, so it can sit
/// between real rows in a Settings or Profile list.
public struct CrossPromoInlineRow: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let palette: PromoPalette

    /// Creates the row. Set `opensLinks` to open the promoted app's link on tap.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.ad = ad
        self.opensLinks = opensLinks
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        HStack(spacing: 12) {
            PromoAdIcon(image: ad.icon, side: 29, cornerRadius: 7, palette: palette)
            VStack(alignment: .leading, spacing: 1) {
                Text(ad.card.appName)
                    .font(.body)
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(2)
                Text(ad.card.tagline)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            PromoAdBadge(palette: palette)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .promoPressable { if opensLinks { promoOpen(ad.card) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .promoEntrance()
    }
}
#endif
