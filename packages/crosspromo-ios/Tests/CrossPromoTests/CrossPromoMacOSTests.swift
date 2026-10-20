//
//  CrossPromoMacOSTests.swift
//  CrossPromoTests
//
//  Created by Angelo Cammalleri on 29.08.26.
//

#if os(macOS)
import AppKit
import Foundation
import SwiftUI
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

    @Test("card click recognizer leaves CTA mouse events to the button")
    @MainActor
    func cardClickRecognizerLeavesCTAEventsToButton() throws {
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
        let view = CrossPromoCardNSView(
            preview: card,
            icon: solidImage(color: .systemBlue)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        view.frame = window.contentView?.bounds ?? .zero
        view.layoutSubtreeIfNeeded()

        let recognizer = try #require(view.gestureRecognizers.first as? NSClickGestureRecognizer)
        let button = try #require(firstSubview(of: NSButton.self, in: view))
        let buttonCenter = button.convert(
            NSPoint(x: button.bounds.midX, y: button.bounds.midY),
            to: view
        )
        let bodyPoint = NSPoint(x: 8, y: view.bounds.midY)

        let buttonEvent = try makeMouseDownEvent(at: buttonCenter, in: view, window: window)
        let bodyEvent = try makeMouseDownEvent(at: bodyPoint, in: view, window: window)
        let buttonAttempt = recognizer.delegate?.gestureRecognizer?(
            recognizer,
            shouldAttemptToRecognizeWith: buttonEvent
        )
        let bodyAttempt = recognizer.delegate?.gestureRecognizer?(
            recognizer,
            shouldAttemptToRecognizeWith: bodyEvent
        )

        #expect(buttonAttempt == false)
        #expect(bodyAttempt == true)
    }

    @Test("SwiftUI facade preserves the shared public API")
    @MainActor
    func swiftUIFacadePreservesPublicAPI() {
        let facade = CrossPromoCard(placement: .settings)

        requireNativeRepresentable(facade)
        #expect(facade.placement == .settings)
        #expect(facade.onError == nil)
        #expect(facade.onCardLoaded == nil)

        let observedFacade = facade.onCardLoaded { _ in }
        requireNativeRepresentable(observedFacade)
        #expect(observedFacade.onCardLoaded != nil)
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

    @Test("card measurement does not modify an attached layout graph")
    @MainActor
    func measurementDoesNotModifyAttachedLayout() throws {
        let card = sizingCard()
        let view = CrossPromoCardNSView(preview: card, icon: solidImage(color: .systemBlue))
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        root.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            view.topAnchor.constraint(equalTo: root.topAnchor),
        ])
        let constraints = Set(view.constraints.map(ObjectIdentifier.init))
        let parentConstraints = Set(root.constraints.map(ObjectIdentifier.init))
        let originalFrame = view.frame
        let widths: [CGFloat?] = [nil, .infinity, .nan, 0, 260, 300, 400, 600]
        for _ in 0..<100 {
            for width in widths {
                let size = view.preferredSize(forWidth: width)
                #expect(size.width.isFinite && size.height.isFinite)
                #expect(size.width >= 0 && size.height >= 0)
                #expect(Set(view.constraints.map(ObjectIdentifier.init)) == constraints)
                #expect(Set(root.constraints.map(ObjectIdentifier.init)) == parentConstraints)
                #expect(view.frame == originalFrame)
            }
        }
        let wide = view.preferredSize(forWidth: 600)
        let narrow = view.preferredSize(forWidth: 260)
        #expect(narrow.height > wide.height)
        #expect(narrow.height < 200, "two-line text must not create an unbounded card")
        view.isHidden = true
        #expect(view.preferredSize(forWidth: 600).height == 0)
    }

    @Test("SwiftUI card remains bounded while a mounted host changes width")
    @MainActor
    func mountedSwiftUICardResizes() async throws {
        let card = sizingCard()
        let icon = solidImage(color: .systemBlue)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 350),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        func content(width: CGFloat) -> some View {
            ScrollView {
                VStack {
                    CrossPromoCardPreview(card: card, icon: icon)
                        .frame(width: width)
                }
            }
        }
        let host = NSHostingView(rootView: content(width: 600))
        host.sizingOptions = []
        window.contentView = host
        for width in [600.0, 300, 260, 400, 600] {
            host.rootView = content(width: width)
            host.layoutSubtreeIfNeeded()
            await drainMainQueue()
            host.layoutSubtreeIfNeeded()
            let native = try #require(firstSubview(of: CrossPromoCardNSView.self, in: host))
            #expect(abs(native.frame.width - width) < 1)
            #expect(native.frame.height >= 84 && native.frame.height < 200)
            let labels = native.subviews.flatMap { $0.subviews }.flatMap { $0.subviews }
                .compactMap { $0 as? NSTextField }.filter { $0.maximumNumberOfLines == 2 }
            #expect(labels.count == 2)
            #expect(labels.allSatisfy { $0.preferredMaxLayoutWidth > 0 })
            if let capturePath = ProcessInfo.processInfo.environment["CROSSPROMO_LAYOUT_CAPTURE_DIR"],
               let bitmap = native.bitmapImageRepForCachingDisplay(in: native.bounds) {
                native.cacheDisplay(in: native.bounds, to: bitmap)
                let url = URL(fileURLWithPath: capturePath).appendingPathComponent("card-\(Int(width)).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }

    private func sizingCard() -> PromoCardData {
        PromoCardData(
            cardID: "sequoia-sizing", appName: "Sample App with a Longer Name",
            iconURL: URL(fileURLWithPath: "/preview-icon"),
            tagline: "A longer local preview that wraps when the browser window becomes narrow.",
            cta: "View App", clickURL: URL(fileURLWithPath: "/preview-click"),
            impressionToken: "sequoia-sizing", expiresAt: .distantFuture
        )
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
    private func firstSubview<T: NSView>(of type: T.Type, in root: NSView) -> T? {
        if let match = root as? T { return match }
        for subview in root.subviews {
            if let match = firstSubview(of: type, in: subview) { return match }
        }
        return nil
    }

    @MainActor
    private func makeMouseDownEvent(
        at point: NSPoint,
        in view: NSView,
        window: NSWindow
    ) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: view.convert(point, to: nil),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ))
    }

    @MainActor
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    @MainActor
    private func requireNativeRepresentable<T: NSViewRepresentable>(_ value: T)
    where T.NSViewType == CrossPromoCardNSView {
        let make = value.makeNSView
        let update = value.updateNSView
        let size = value.sizeThatFits
        _ = (make, update, size)
    }
}
#endif
