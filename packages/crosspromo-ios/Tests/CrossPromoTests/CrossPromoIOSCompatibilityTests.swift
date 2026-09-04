//
//  CrossPromoIOSCompatibilityTests.swift
//  CrossPromoTests
//
//  Created by Angelo Cammalleri on 29.08.26.
//

#if canImport(UIKit)
import SwiftUI
import Testing
import UIKit
import CrossPromo

@Suite("CrossPromo UIKit compatibility")
struct CrossPromoIOSCompatibilityTests {
    @Test("SwiftUI card preserves the legacy UIKit representable API")
    @MainActor
    func swiftUICardPreservesLegacyUIKitAPI() {
        let card = CrossPromoCard(placement: .settings) { _ in }

        requireLegacyUIKitAPI(card)
        #expect(card.placement == .settings)
        #expect(card.onError != nil)
        #expect(card.onCardLoaded == nil)

        let observedCard = card.onCardLoaded { _ in }
        requireLegacyUIKitAPI(observedCard)
        #expect(observedCard.onError != nil)
        #expect(observedCard.onCardLoaded != nil)
    }

    @MainActor
    private func requireLegacyUIKitAPI<T: UIViewRepresentable>(_ value: T)
    where T.UIViewType == CrossPromoCardUIView {
        let make = value.makeUIView
        let update = value.updateUIView
        let size = value.sizeThatFits
        _ = (make, update, size)
    }
}
#endif
