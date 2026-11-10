//
//  CrossPromoRemoveAds.swift
//  CrossPromo
//
//  Created by Angelo Cammalleri on 10.11.26.
//

#if canImport(UIKit) || os(macOS)
import SwiftUI

/// An app-owned ad-free offer to show beneath a CrossPromo card.
public struct CrossPromoRemoveAds {
    fileprivate let label: Text
    fileprivate let accessibilityHint: Text
    fileprivate let action: @MainActor () -> Void

    /// Creates an offer with optional app-localized copy.
    /// The action runs on the main actor when the footer button is activated.
    public init(
        label: Text? = nil,
        accessibilityHint: Text? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.label = label ?? Text("ads.removeAds", bundle: .module)
        self.accessibilityHint = accessibilityHint ?? Text("ads.removeAdsHint", bundle: .module)
        self.action = action
    }
}

extension CrossPromoCard {
    /// Offers an ad-free option at this placement while a card is displayed.
    /// Pass `nil` when the app has no offer. Apply card callbacks before this modifier.
    public func removeAds(_ offer: CrossPromoRemoveAds?) -> some View {
        CrossPromoCardWithOffer(card: self, offer: offer)
    }
}

extension CrossPromoCardPreview {
    /// Previews the optional footer alongside the local card fixture.
    public func removeAds(_ offer: CrossPromoRemoveAds?) -> some View {
        CrossPromoOfferLayout(card: self, offer: offer)
    }
}

struct CrossPromoCardMeasurement {
    let placement: CrossPromoPlacement
    let height: CGFloat

    func showsCard(for placement: CrossPromoPlacement) -> Bool {
        self.placement == placement && height > 0
    }
}

private struct CrossPromoCardWithOffer: View {
    let card: CrossPromoCard
    let offer: CrossPromoRemoveAds?
    @State private var measurement: CrossPromoCardMeasurement?

    var body: some View {
        var measuredCard = card
        measuredCard.sharedMeasurement = $measurement
        return CrossPromoOfferLayout(
            card: measuredCard,
            offer: measurement?.showsCard(for: card.placement) == true ? offer : nil
        )
    }
}

private struct CrossPromoOfferLayout<Card: View>: View {
    let card: Card
    let offer: CrossPromoRemoveAds?

    private enum Layout {
        static var gap: CGFloat { 4 }
        static var bottomPadding: CGFloat { 8 }
        static var touchTarget: CGFloat { 44 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            card

            if let offer {
                Button(action: offer.action) {
                    HStack(spacing: Layout.gap) {
                        offer.label
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.forward")
                            .accessibilityHidden(true)
                    }
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, Layout.bottomPadding)
                    #if !os(macOS)
                    .frame(
                        minWidth: Layout.touchTarget,
                        minHeight: Layout.touchTarget,
                        alignment: .leading
                    )
                    #endif
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(offer.label)
                .accessibilityHint(offer.accessibilityHint)
                .accessibilityIdentifier("crossPromo.removeAds")
            }
        }
    }
}
#endif
