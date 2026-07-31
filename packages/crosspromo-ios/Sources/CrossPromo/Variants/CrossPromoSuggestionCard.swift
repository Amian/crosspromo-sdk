#if canImport(UIKit)
import SwiftUI

/// A "Suggested for you" card in the system intelligence idiom: glass surface,
/// sparkle header, ghost call to action. The whole card is one tappable unit.
public struct CrossPromoSuggestionCard: View {
    private let ad: PromoAd
    private let reason: String?
    private let opensLinks: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Creates a suggestion card from local data.
    /// - Parameters:
    ///   - ad: The promoted app.
    ///   - reason: Why it is being suggested, e.g. "Because you scan plants".
    ///     Falls back to the card tagline when `nil`.
    ///   - opensLinks: When `true`, tapping the card opens its click URL.
    public init(ad: PromoAd, reason: String? = nil, opensLinks: Bool = false) {
        self.ad = ad
        self.reason = reason
        self.opensLinks = opensLinks
    }

    private var palette: PromoPalette { PromoPalette(ad: ad) }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(palette.chipText(colorScheme))
                Text("SUGGESTED FOR YOU")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                PromoAdBadge(palette: palette)
            }
            HStack(spacing: 12) {
                PromoAdIcon(
                    image: ad.icon,
                    side: 44,
                    cornerRadius: 10,
                    palette: palette
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(ad.card.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(reason ?? ad.card.tagline)
                        .font(.footnote)
                        .foregroundStyle(reasonColor)
                        .lineLimit(2)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(ad.card.cta)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.chipText(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                palette.chipText(colorScheme).opacity(0.35),
                                lineWidth: 1
                            )
                    )
                    .fixedSize()
            }
        }
        .padding(14)
        .background(shape.fill(.ultraThinMaterial))
        .overlay(shape.strokeBorder(palette.hairline(colorScheme), lineWidth: 1))
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .promoPressable {
            guard opensLinks else { return }
            promoOpen(ad.card)
        }
        .promoEntrance()
    }

    private var reasonColor: Color {
        reason == nil
            ? Color(uiColor: .secondaryLabel)
            : palette.chipText(colorScheme)
    }
}
#endif
