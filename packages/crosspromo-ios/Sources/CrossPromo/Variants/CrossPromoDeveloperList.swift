#if canImport(UIKit)
import SwiftUI

/// An App Store "More by this developer" section: a grouped container with a
/// titled header and two to four rows, each carrying its own ghost CTA pill and
/// each individually tappable.
public struct CrossPromoDeveloperList: View {
    private let ads: [PromoAd]
    private let title: String
    private let opensLinks: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Creates a developer list from local data.
    /// - Parameters:
    ///   - ads: Two to four promoted apps. Anything past the fourth is ignored.
    ///   - title: Section header shown above the rows.
    ///   - opensLinks: When `true`, tapping a row opens its click URL.
    public init(
        ads: [PromoAd],
        title: String = "More from this studio",
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

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                PromoAdBadge(palette: headerPalette)
            }
            .padding(14)
            ForEach(Array(entries.enumerated()), id: \.offset) { index, ad in
                if index > 0 {
                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 0.5)
                        .padding(.leading, 70)
                }
                PromoDeveloperRow(ad: ad, opensLinks: opensLinks)
                    .promoEntrance(delay: Double(index) * 0.05)
            }
        }
        .background(shape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(headerPalette.hairline(colorScheme), lineWidth: 1))
    }
}

private struct PromoDeveloperRow: View {
    let ad: PromoAd
    let opensLinks: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var palette: PromoPalette { PromoPalette(ad: ad) }

    var body: some View {
        HStack(spacing: 12) {
            PromoAdIcon(
                image: ad.icon,
                side: 44,
                cornerRadius: 10,
                palette: palette
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(ad.card.appName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(ad.card.tagline)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(ad.card.cta)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.chipText(colorScheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                )
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
