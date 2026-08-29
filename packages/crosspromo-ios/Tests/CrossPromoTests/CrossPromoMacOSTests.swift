//
//  CrossPromoMacOSTests.swift
//  CrossPromoTests
//
//  Created by Angelo Cammalleri on 29.08.26.
//

#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import CrossPromo

@Suite("CrossPromo macOS support")
struct CrossPromoMacOSTests {
    @Test("native device context identifies macOS")
    func nativeDeviceContextIdentifiesMacOS() async throws {
        let snapshot = try await AppleDeviceContextProvider(bundle: .main).snapshot()

        #expect(snapshot.app.platform == "macos")
    }

    @Test("AppKit preview exposes the card without configuring the client")
    @MainActor
    func appKitPreviewIsDeterministicAndAccessible() throws {
        let card = PromoCardData(
            cardID: "preview-card",
            appName: "Rock Finder",
            iconURL: try #require(URL(string: "https://example.test/icon.png")),
            tagline: "Find every rock",
            cta: "Get",
            clickURL: try #require(URL(string: "https://example.test/click")),
            impressionToken: "preview-impression",
            expiresAt: .distantFuture
        )
        let icon = solidImage(
            color: NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.9, alpha: 1)
        )

        let view = CrossPromoCardNSView(preview: card, icon: icon)
        _ = CrossPromoCardPreview(card: card, icon: icon)

        #expect(!view.isHidden)
        #expect(view.placement == .result)
        #expect(view.fittingSize.height >= 84)
        #expect(view.subviews.first?.alphaValue == 1, "an unattached preview must not stay transparent")
        #expect(view.accessibilityRole() == .button)
        #expect(view.accessibilityLabel() == "Ad. Rock Finder. Find every rock")
        #expect(!view.accessibilityPerformPress(), "previews must never open a link")
    }

    @Test("SwiftUI facade preserves the shared public API")
    @MainActor
    func swiftUIFacadePreservesPublicAPI() {
        let facade = CrossPromoCard(placement: .settings)

        #expect(facade.placement == .settings)
        #expect(facade.onError == nil)
    }

    @Test("native preferred height follows loading and available width")
    @MainActor
    func nativePreferredHeightFollowsLoadingAndWidth() async throws {
        let card = PromoCardData(
            cardID: "sizing-card",
            appName: "Rock Finder",
            iconURL: try #require(URL(string: "https://example.test/icon.png")),
            tagline: "Find and identify interesting rocks wherever you go.",
            cta: "Get",
            clickURL: try #require(URL(string: "https://example.test/click")),
            impressionToken: "sizing-impression",
            expiresAt: .distantFuture
        )
        let icon = solidImage(
            color: NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.9, alpha: 1)
        )
        let nativeView = CrossPromoCardNSView(placement: .settings)
        nativeView.frame = NSRect(x: 0, y: 0, width: 520, height: 0)
        var reportedHeights: [CGFloat] = []
        let (heightStream, heightContinuation) = AsyncStream.makeStream(of: CGFloat.self)
        nativeView.onPreferredHeightChange = {
            reportedHeights.append($0)
            heightContinuation.yield($0)
        }
        var heightIterator = heightStream.makeAsyncIterator()

        nativeView.layoutSubtreeIfNeeded()
        let collapsedHeight = try #require(await heightIterator.next())
        #expect(collapsedHeight == 0)

        nativeView.displayPreview(card: card, icon: icon)
        nativeView.layoutSubtreeIfNeeded()
        let wideHeight = try #require(await heightIterator.next())
        #expect(wideHeight >= 84)

        nativeView.frame.size.width = 260
        nativeView.needsLayout = true
        nativeView.layoutSubtreeIfNeeded()
        let narrowHeight = try #require(await heightIterator.next())
        #expect(narrowHeight > wideHeight)

        let reportCount = reportedHeights.count
        nativeView.needsLayout = true
        nativeView.layoutSubtreeIfNeeded()
        await drainMainQueue()
        #expect(reportedHeights.count == reportCount)
        heightContinuation.finish()
    }

    @Test("AppKit accent extraction keeps saturated icon color")
    @MainActor
    func appKitAccentExtraction() throws {
        let icon = solidImage(
            color: NSColor(calibratedRed: 0.05, green: 0.5, blue: 0.95, alpha: 1)
        )

        let accent = try #require(IconAccent.extract(from: icon))

        #expect(accent.saturation >= 0.55)
        #expect(IconAccent.relativeLuminance(of: .white) > IconAccent.relativeLuminance(of: .black))
    }

    @MainActor
    private func solidImage(color: NSColor) -> NSImage {
        let size = CGSize(width: 32, height: 32)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor((color.usingColorSpace(.deviceRGB) ?? color).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        return NSImage(cgImage: context.makeImage()!, size: size)
    }

    @MainActor
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
#endif
