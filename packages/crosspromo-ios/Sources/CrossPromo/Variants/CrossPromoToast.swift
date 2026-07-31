#if canImport(UIKit)
import SwiftUI

/// A reward-moment toast: a floating, full-width row for celebrating a moment
/// in the host app and pointing at a sibling app on the way out.
public struct CrossPromoToast: View {
    private let ad: PromoAd
    private let opensLinks: Bool
    private let onTap: (() -> Void)?
    private let palette: PromoPalette
    @Environment(\.colorScheme) private var colorScheme

    /// Creates the toast. Set `opensLinks` to open the promoted app's link on tap.
    public init(ad: PromoAd, opensLinks: Bool = false) {
        self.init(ad: ad, opensLinks: opensLinks, onTap: nil)
    }

    init(ad: PromoAd, opensLinks: Bool, onTap: (() -> Void)?) {
        self.ad = ad
        self.opensLinks = opensLinks
        self.onTap = onTap
        palette = PromoPalette(ad: ad)
    }

    public var body: some View {
        HStack(spacing: 12) {
            PromoAdIcon(image: ad.icon, side: 36, cornerRadius: 9, palette: palette)
            VStack(alignment: .leading, spacing: 2) {
                Text("Also from us")
                    .font(.caption2)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                Text(ad.card.appName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            PromoAdBadge(palette: palette)
            Text(ad.card.cta)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.onCta(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(palette.cta(colorScheme)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.washedSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.hairline(colorScheme), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .promoPressable {
            if opensLinks { promoOpen(ad.card) }
            onTap?()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ad. \(ad.card.appName). \(ad.card.tagline)")
        .padding(.horizontal, 16)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? palette.glow(colorScheme).opacity(0.3)
            : .black.opacity(0.1)
    }
}

private struct CrossPromoToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let ad: PromoAd
    let opensLinks: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if isPresented {
                    CrossPromoToast(ad: ad, opensLinks: opensLinks, onTap: dismiss)
                        .offset(y: dragOffset)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    dragOffset = max(0, value.translation.height)
                                }
                                .onEnded { value in
                                    if value.translation.height > 40 {
                                        dismiss()
                                    } else {
                                        withAnimation(
                                            .spring(response: 0.3, dampingFraction: 0.85)
                                        ) { dragOffset = 0 }
                                    }
                                }
                        )
                        .transition(transition)
                        .task(id: ad.id) {
                            try? await Task.sleep(nanoseconds: 6_000_000_000)
                            guard !Task.isCancelled else { return }
                            dismiss()
                        }
                }
            }
            .padding(.bottom, 12)
            .animation(presentationAnimation, value: isPresented)
        }
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 24))
    }

    private var presentationAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.25)
            : .spring(response: 0.45, dampingFraction: 0.82)
    }

    private func dismiss() {
        dragOffset = 0
        isPresented = false
    }
}

extension View {
    /// Presents a `CrossPromoToast` over the bottom of this view. It rises with
    /// a spring, can be swiped down, and clears itself after six seconds.
    public func crossPromoToast(
        isPresented: Binding<Bool>,
        ad: PromoAd,
        opensLinks: Bool = false
    ) -> some View {
        modifier(
            CrossPromoToastModifier(
                isPresented: isPresented,
                ad: ad,
                opensLinks: opensLinks
            )
        )
    }
}
#endif
