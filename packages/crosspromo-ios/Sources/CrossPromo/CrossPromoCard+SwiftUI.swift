//
//  CrossPromoCard+SwiftUI.swift
//  CrossPromo
//
//  Created by Angelo Cammalleri on 29.08.26.
//

import SwiftUI

/// A platform-native CrossPromo card for SwiftUI.
///
/// The SDK selects and sizes the appropriate native renderer. Consumers use
/// the same view on every supported platform and never need UIKit/AppKit
/// bridges or platform conditionals.
public struct CrossPromoCard: View {
    public let placement: CrossPromoPlacement
    public var onError: ((Error) -> Void)?

    @State private var preferredHeight: CGFloat = 0
    @State private var measuredPlacement: CrossPromoPlacement?

    public init(placement: CrossPromoPlacement, onError: ((Error) -> Void)? = nil) {
        self.placement = placement
        self.onError = onError
    }

    public var body: some View {
        CrossPromoPlatformCard(
            placement: placement,
            onError: onError,
            onHeightChange: { height in
                updatePreferredHeight(height, for: placement)
            }
        )
        .frame(height: measuredPlacement == placement ? preferredHeight : 0)
    }

    private func updatePreferredHeight(
        _ height: CGFloat,
        for placement: CrossPromoPlacement
    ) {
        let normalizedHeight = max(0, height)
        guard measuredPlacement != placement
                || abs(normalizedHeight - preferredHeight) > 0.5 else { return }
        measuredPlacement = placement
        preferredHeight = normalizedHeight
    }
}
