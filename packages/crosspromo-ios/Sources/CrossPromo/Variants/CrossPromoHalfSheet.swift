#if canImport(UIKit)
import SwiftUI
import UIKit

/// Half-modal recommendation, designed to be presented with
/// `.sheet` + `.presentationDetents([.medium])` — see `crossPromoHalfSheet`.
public struct CrossPromoHalfSheet: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let onDismiss: () -> Void
    private let palette: PromoPalette
    @Environment(\.colorScheme) private var colorScheme

    /// Creates the sheet body for one promoted app. `onDismiss` backs the
    /// "Not now" button.
    public init(ad: PromoAd, opensLinks: Bool = false, onDismiss: @escaping () -> Void) {
        self.ad = ad
        self.opensLinks = opensLinks
        self.onDismiss = onDismiss
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        VStack(spacing: 0) {
            hero
                .promoPressable(action: open)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
                .accessibilityAddTraits(.isButton)
            Spacer(minLength: 24)
            Button(action: open) {
                Text(ad.card.cta)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.onCta(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(palette.cta(colorScheme)))
            }
            .buttonStyle(PromoPressableButtonStyle())
            .padding(.horizontal, 20)
            Button(action: onDismiss) {
                Text("Not now")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .padding(.top, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(background.ignoresSafeArea())
        .promoEntrance()
    }

    private var hero: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [
                        palette.glow(colorScheme).opacity(colorScheme == .dark ? 0.25 : 0.15),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 110
                )
                PromoAdIcon(
                    image: ad.icon,
                    side: 76,
                    cornerRadius: 17,
                    palette: palette,
                    glow: true
                )
            }
            .frame(height: 150)
            Text("A RECOMMENDATION FROM US")
                .font(.caption2.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(palette.chipText(colorScheme))
                .multilineTextAlignment(.center)
            Text(ad.card.appName)
                .font(.title2.bold())
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 10)
            Text(ad.card.tagline)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
                .padding(.top, 6)
            PromoAdBadge(palette: palette, detail: "Indie pick")
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: palette.washedSurface(colorScheme), location: 0),
                .init(color: palette.washedSurface(colorScheme, intensity: 0), location: 0.45),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func open() {
        guard opensLinks else { return }
        promoOpen(ad.card)
    }
}

private struct CrossPromoHalfSheetPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let ad: PromoAd

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) { sheet }
    }

    @ViewBuilder
    private var sheet: some View {
        let body = CrossPromoHalfSheet(ad: ad) { isPresented = false }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        if #available(iOS 16.4, *) {
            body.presentationCornerRadius(24)
        } else {
            body
        }
    }
}

extension View {
    /// Presents `ad` as a medium-detent half sheet with a visible drag
    /// indicator and rounded sheet corners.
    public func crossPromoHalfSheet(isPresented: Binding<Bool>, ad: PromoAd) -> some View {
        modifier(CrossPromoHalfSheetPresenter(isPresented: isPresented, ad: ad))
    }
}
#endif
