//
//  CrossPromoCard+macOS.swift
//  CrossPromo
//
//  Created by Angelo Cammalleri on 29.08.26.
//

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
public final class CrossPromoCardNSView: NSView {
    public var placement: CrossPromoPlacement {
        didSet { reload() }
    }
    public var onError: ((Error) -> Void)?
    public var onCardLoaded: ((PromoCardData?) -> Void)?
    var onPreferredHeightChange: ((CGFloat) -> Void)? {
        didSet { schedulePreferredHeightReport() }
    }

    private let container = NSStackView()
    private let iconWrapper = NSView()
    private let iconView = NSImageView()
    private let textStack = NSStackView()
    private let appNameLabel = NSTextField(wrappingLabelWithString: "")
    private let taglineLabel = NSTextField(wrappingLabelWithString: "")
    private let disclosureRow = NSStackView()
    private let adChip = NSView()
    private let adChipLabel = NSTextField(labelWithString: "AD")
    private let disclosureLabel = NSTextField(labelWithString: "Indie pick")
    private let ctaButton = CapsuleButton()
    private var card: PromoCardData?
    private var accent: IconAccent?
    private var loadTask: Task<Void, Never>?
    private var imageTask: Task<Void, Never>?
    private var viewabilityTracker: MacViewabilityTracker?
    private var allowsOpening = true
    private var expandedLayoutConstraints: [NSLayoutConstraint] = []
    private var collapsedHeightConstraint: NSLayoutConstraint!
    private var lastReportedPreferredHeight: CGFloat = -1
    private var preferredHeightReportIsScheduled = false

    public init(placement: CrossPromoPlacement) {
        self.placement = placement
        super.init(frame: .zero)
        configureView()
        reload()
    }

    /// Creates the production card view from local data without network,
    /// click, or impression side effects.
    public init(preview card: PromoCardData, icon: NSImage, accentColor: NSColor? = nil) {
        placement = .result
        super.init(frame: .zero)
        allowsOpening = false
        configureView()
        displayPreview(card: card, icon: icon, accentColor: accentColor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(placement:)")
    }

    deinit {
        loadTask?.cancel()
        imageTask?.cancel()
    }

    public override var acceptsFirstResponder: Bool {
        allowsOpening && card != nil
    }

    public func reload() {
        loadTask?.cancel()
        imageTask?.cancel()
        allowsOpening = true
        setCollapsed(true)
        card = nil
        accent = nil
        viewabilityTracker = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try CrossPromo.client
                let card = try await client.fetchCard(placement: placement)
                guard !Task.isCancelled else { return }
                apply(card)
                onCardLoaded?(card)
            } catch {
                guard !Task.isCancelled else { return }
                onError?(error)
            }
        }
    }

    public func displayPreview(
        card: PromoCardData,
        icon: NSImage,
        accentColor: NSColor? = nil
    ) {
        loadTask?.cancel()
        imageTask?.cancel()
        allowsOpening = false
        viewabilityTracker = nil
        self.card = card
        appNameLabel.stringValue = card.appName
        taglineLabel.stringValue = card.tagline
        iconView.image = icon
        accent = accentColor.map(IconAccent.init(color:)) ?? IconAccent.extract(from: icon)
        updateAccessibility(for: card)
        applyPalette()
        setCollapsed(false)
        animateEntrance()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    public override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: layer?.cornerRadius ?? 0,
            cornerHeight: layer?.cornerRadius ?? 0,
            transform: nil
        )
        iconWrapper.layer?.shadowPath = CGPath(
            roundedRect: iconWrapper.bounds,
            cornerWidth: iconView.layer?.cornerRadius ?? 0,
            cornerHeight: iconView.layer?.cornerRadius ?? 0,
            transform: nil
        )
        ctaButton.layer?.cornerRadius = ctaButton.bounds.height / 2
        ctaButton.layer?.shadowPath = CGPath(
            roundedRect: ctaButton.bounds,
            cornerWidth: ctaButton.bounds.height / 2,
            cornerHeight: ctaButton.bounds.height / 2,
            transform: nil
        )
        schedulePreferredHeightReport()
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            openCard()
        } else {
            super.keyDown(with: event)
        }
    }

    public override func accessibilityPerformPress() -> Bool {
        guard allowsOpening, card != nil else { return false }
        openCard()
        return true
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -6)

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityHelp("Opens the promoted app in the App Store")

        container.orientation = .horizontal
        container.alignment = .centerY
        container.distribution = .fill
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        iconWrapper.translatesAutoresizingMaskIntoConstraints = false
        iconWrapper.wantsLayer = true
        iconWrapper.layer?.shadowRadius = 9
        iconWrapper.layer?.shadowOffset = CGSize(width: 0, height: -3)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 14
        iconView.layer?.cornerCurve = .continuous
        iconView.layer?.borderWidth = 0.5
        iconView.layer?.masksToBounds = true
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconWrapper.addSubview(iconView)

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.distribution = .fill
        textStack.spacing = 3
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        appNameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        appNameLabel.textColor = .labelColor
        appNameLabel.maximumNumberOfLines = 2
        appNameLabel.lineBreakMode = .byWordWrapping
        appNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        taglineLabel.font = .systemFont(ofSize: 13)
        taglineLabel.textColor = .secondaryLabelColor
        taglineLabel.maximumNumberOfLines = 2
        taglineLabel.lineBreakMode = .byWordWrapping
        taglineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        adChip.translatesAutoresizingMaskIntoConstraints = false
        adChip.wantsLayer = true
        adChip.layer?.cornerRadius = 5
        adChipLabel.translatesAutoresizingMaskIntoConstraints = false
        adChipLabel.font = .systemFont(ofSize: 9, weight: .heavy)
        adChipLabel.alignment = .center
        adChip.addSubview(adChipLabel)
        NSLayoutConstraint.activate([
            adChipLabel.leadingAnchor.constraint(equalTo: adChip.leadingAnchor, constant: 5),
            adChipLabel.trailingAnchor.constraint(equalTo: adChip.trailingAnchor, constant: -5),
            adChipLabel.topAnchor.constraint(equalTo: adChip.topAnchor, constant: 2.5),
            adChipLabel.bottomAnchor.constraint(equalTo: adChip.bottomAnchor, constant: -2.5),
        ])

        disclosureLabel.font = .systemFont(ofSize: 11, weight: .medium)
        disclosureLabel.textColor = .tertiaryLabelColor
        let disclosureSpacer = NSView()
        disclosureSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        disclosureRow.orientation = .horizontal
        disclosureRow.alignment = .centerY
        disclosureRow.spacing = 6
        disclosureRow.addArrangedSubview(adChip)
        disclosureRow.addArrangedSubview(disclosureLabel)
        disclosureRow.addArrangedSubview(disclosureSpacer)

        textStack.addArrangedSubview(appNameLabel)
        textStack.addArrangedSubview(taglineLabel)
        textStack.addArrangedSubview(disclosureRow)
        textStack.setCustomSpacing(5, after: taglineLabel)

        ctaButton.target = self
        ctaButton.action = #selector(openCard)
        ctaButton.setContentHuggingPriority(.required, for: .horizontal)
        ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        ctaButton.setAccessibilityElement(false)

        addSubview(container)
        container.addArrangedSubview(iconWrapper)
        container.addArrangedSubview(textStack)
        container.addArrangedSubview(ctaButton)

        let clickRecognizer = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleCardClick(_:))
        )
        addGestureRecognizer(clickRecognizer)

        NSLayoutConstraint.activate([
            iconWrapper.widthAnchor.constraint(equalToConstant: 56),
            iconWrapper.heightAnchor.constraint(equalTo: iconWrapper.widthAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconWrapper.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconWrapper.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
            ctaButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])
        expandedLayoutConstraints = [
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
        ]
        collapsedHeightConstraint = heightAnchor.constraint(equalToConstant: 0)
        setCollapsed(true)
        applyPalette()
    }

    private func apply(_ card: PromoCardData?) {
        self.card = card
        guard let card else {
            setCollapsed(true)
            return
        }
        appNameLabel.stringValue = card.appName
        taglineLabel.stringValue = card.tagline
        iconView.image = nil
        accent = nil
        updateAccessibility(for: card)
        applyPalette()
        setCollapsed(false)
        animateEntrance()
        loadIcon(from: card.iconURL)
        viewabilityTracker = MacViewabilityTracker(view: self) { [weak self] fraction, duration in
            guard let self, let currentCard = self.card else { return }
            Task {
                guard let client = try? CrossPromo.client else { return }
                try? await client.recordImpression(
                    for: currentCard,
                    visibleFraction: fraction,
                    duration: duration
                )
            }
        }
    }

    private func updateAccessibility(for card: PromoCardData) {
        setAccessibilityLabel("Ad. \(card.appName). \(card.tagline)")
        setAccessibilityEnabled(allowsOpening)
    }

    private func animateEntrance() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              window != nil else {
            container.alphaValue = 1
            return
        }
        container.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            container.animator().alphaValue = 1
        }
    }

    private var darkTheme: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func applyPalette() {
        guard layer != nil else { return }
        let dark = darkTheme
        let background = makeCardBackground(darkTheme: dark)
        layer?.backgroundColor = background.cgColor
        layer?.borderColor = makeHairline(darkTheme: dark).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = dark ? 0 : 0.07

        iconView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        iconView.layer?.borderColor = (dark
            ? NSColor.white.withAlphaComponent(0.16)
            : NSColor.black.withAlphaComponent(0.08)).cgColor
        adChip.layer?.backgroundColor = makeChipBackground(darkTheme: dark).cgColor
        adChipLabel.textColor = makeChipText(darkTheme: dark)
        disclosureLabel.textColor = .tertiaryLabelColor

        let ctaBackground = makeCtaBackground(darkTheme: dark)
        ctaButton.apply(
            title: card?.cta ?? "",
            background: ctaBackground,
            foreground: makeCtaForeground(darkTheme: dark)
        )
        if let accent {
            iconWrapper.layer?.shadowColor = accent.glowColor(darkTheme: dark).cgColor
            iconWrapper.layer?.shadowOpacity = dark ? 0.5 : 0.32
            ctaButton.layer?.shadowColor = ctaBackground.cgColor
            ctaButton.layer?.shadowOpacity = dark ? 0.42 : 0.28
        } else {
            iconWrapper.layer?.shadowOpacity = 0
            ctaButton.layer?.shadowColor = NSColor.controlAccentColor.cgColor
            ctaButton.layer?.shadowOpacity = dark ? 0.35 : 0.22
        }
        needsDisplay = true
    }

    private func makeCardBackground(darkTheme: Bool) -> NSColor {
        let base = darkTheme
            ? NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.125, alpha: 1)
            : NSColor.white
        guard let accent else { return base }
        return Self.blend(accent.washColor(darkTheme: darkTheme), over: base)
    }

    private func makeHairline(darkTheme: Bool) -> NSColor {
        guard let accent else { return .separatorColor }
        return accent.hairlineColor(darkTheme: darkTheme)
    }

    private func makeChipBackground(darkTheme: Bool) -> NSColor {
        guard let accent else { return .quaternaryLabelColor }
        return accent.chipBackgroundColor(darkTheme: darkTheme)
    }

    private func makeChipText(darkTheme: Bool) -> NSColor {
        guard let accent else { return .secondaryLabelColor }
        return accent.chipTextColor(darkTheme: darkTheme)
    }

    private func makeCtaBackground(darkTheme: Bool) -> NSColor {
        guard let accent else { return .controlAccentColor }
        return accent.ctaColor(darkTheme: darkTheme)
    }

    private func makeCtaForeground(darkTheme: Bool) -> NSColor {
        guard let accent else { return .white }
        return accent.onCtaColor(darkTheme: darkTheme)
    }

    private static func blend(_ top: NSColor, over base: NSColor) -> NSColor {
        let topColor = top.usingColorSpace(.deviceRGB) ?? top
        let baseColor = base.usingColorSpace(.deviceRGB) ?? base
        var topRed: CGFloat = 0
        var topGreen: CGFloat = 0
        var topBlue: CGFloat = 0
        var topAlpha: CGFloat = 0
        topColor.getRed(
            &topRed,
            green: &topGreen,
            blue: &topBlue,
            alpha: &topAlpha
        )
        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        baseColor.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: nil)
        return NSColor(
            calibratedRed: topRed * topAlpha + baseRed * (1 - topAlpha),
            green: topGreen * topAlpha + baseGreen * (1 - topAlpha),
            blue: topBlue * topAlpha + baseBlue * (1 - topAlpha),
            alpha: 1
        )
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard collapsedHeightConstraint != nil else { return }
        if collapsed {
            NSLayoutConstraint.deactivate(expandedLayoutConstraints)
            collapsedHeightConstraint.isActive = true
            isHidden = true
        } else {
            isHidden = false
            collapsedHeightConstraint.isActive = false
            NSLayoutConstraint.activate(expandedLayoutConstraints)
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        superview?.needsLayout = true
        schedulePreferredHeightReport()
    }

    private func schedulePreferredHeightReport() {
        guard onPreferredHeightChange != nil,
              !preferredHeightReportIsScheduled else { return }
        preferredHeightReportIsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            reportPreferredHeight()
            preferredHeightReportIsScheduled = false
        }
    }

    private func reportPreferredHeight() {
        guard let onPreferredHeightChange else { return }
        let height: CGFloat
        if isHidden {
            height = 0
        } else {
            let width = bounds.width
            guard width > 0 else { return }
            let widthConstraint = widthAnchor.constraint(equalToConstant: width)
            widthConstraint.isActive = true
            height = fittingSize.height
            widthConstraint.isActive = false
        }
        guard abs(height - lastReportedPreferredHeight) > 0.5 else { return }
        lastReportedPreferredHeight = height
        onPreferredHeightChange(height)
    }

    private func loadIcon(from url: URL) {
        imageTask?.cancel()
        imageTask = Task { [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  !Task.isCancelled else { return }
            let decoded = await Task.detached(priority: .utility) {
                IconAccent.decodeImageAndAccent(from: data)
            }.value
            guard !Task.isCancelled, let (cgImage, extracted) = decoded else { return }
            iconView.image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
            accent = extracted
            applyPalette()
        }
    }

    @objc private func handleCardClick(_ recognizer: NSClickGestureRecognizer) {
        let buttonFrame = convert(ctaButton.bounds, from: ctaButton)
        guard !buttonFrame.contains(recognizer.location(in: self)) else { return }
        openCard()
    }

    @objc private func openCard() {
        guard allowsOpening, let url = card?.clickURL else { return }
        NSWorkspace.shared.open(crossPromoClickURL(url, in: placement))
    }
}

private final class CapsuleButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        wantsLayer = true
        layer?.shadowRadius = 7
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        focusRingType = .default
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 32, height: max(32, size.height + 16))
    }

    func apply(title: String, background: NSColor, foreground: NSColor) {
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: foreground,
            ]
        )
        layer?.backgroundColor = background.cgColor
        invalidateIntrinsicContentSize()
    }
}

@MainActor
private final class MacViewabilityTracker {
    private weak var view: NSView?
    private let onQualified: (Double, TimeInterval) -> Void
    nonisolated(unsafe) private var timer: Timer?
    private var visibleSince: Date?
    private var highestFraction = 0.0
    private var didReport = false

    init(view: NSView, onQualified: @escaping (Double, TimeInterval) -> Void) {
        self.view = view
        self.onQualified = onQualified
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    deinit { timer?.invalidate() }

    private func sample() {
        guard !didReport,
              NSApp.isActive,
              let view,
              let window = view.window,
              window.isVisible,
              !window.isMiniaturized,
              window.attachedSheet == nil,
              window.occlusionState.contains(.visible),
              !view.isHidden,
              view.alphaValue > 0.01 else {
            resetVisibleInterval()
            return
        }
        let totalArea = max(1, view.bounds.width * view.bounds.height)
        let intersection = view.bounds.intersection(view.visibleRect)
        let fraction = max(0, intersection.width * intersection.height / totalArea)
        guard fraction >= 0.5 else {
            resetVisibleInterval()
            return
        }
        highestFraction = max(highestFraction, fraction)
        if visibleSince == nil { visibleSince = Date() }
        let duration = Date().timeIntervalSince(visibleSince ?? Date())
        if duration >= 1 {
            didReport = true
            timer?.invalidate()
            onQualified(highestFraction, duration)
        }
    }

    private func resetVisibleInterval() {
        visibleSince = nil
        highestFraction = 0
    }
}

public struct CrossPromoCard: NSViewRepresentable {
    public let placement: CrossPromoPlacement
    public var onError: ((Error) -> Void)?

    @State private var preferredHeight: CGFloat = 0
    @State private var measuredPlacement: CrossPromoPlacement?

    public init(placement: CrossPromoPlacement, onError: ((Error) -> Void)? = nil) {
        self.placement = placement
        self.onError = onError
    }

    public func makeNSView(context: Context) -> CrossPromoCardNSView {
        let view = CrossPromoCardNSView(placement: placement)
        view.onError = onError
        connectHeightReporting(to: view)
        return view
    }

    public func updateNSView(_ nsView: CrossPromoCardNSView, context: Context) {
        nsView.onError = onError
        connectHeightReporting(to: nsView)
        if nsView.placement != placement { nsView.placement = placement }
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: CrossPromoCardNSView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        guard measuredPlacement == placement, preferredHeight > 0 else {
            return CGSize(width: width, height: 0)
        }
        return fittingSize(for: proposal, nsView: nsView)
    }

    private func connectHeightReporting(to view: CrossPromoCardNSView) {
        let preferredHeight = $preferredHeight
        let measuredPlacement = $measuredPlacement
        let placement = placement
        view.onPreferredHeightChange = { height in
            let normalizedHeight = max(0, height)
            guard measuredPlacement.wrappedValue != placement
                    || abs(normalizedHeight - preferredHeight.wrappedValue) > 0.5 else { return }
            measuredPlacement.wrappedValue = placement
            preferredHeight.wrappedValue = normalizedHeight
        }
    }
}

/// SwiftUI wrapper for deterministic local card previews. It never contacts
/// CrossPromo or reports analytics.
public struct CrossPromoCardPreview: NSViewRepresentable {
    public let card: PromoCardData
    public let icon: NSImage
    public let accentColor: NSColor?

    public init(card: PromoCardData, icon: NSImage, accentColor: NSColor? = nil) {
        self.card = card
        self.icon = icon
        self.accentColor = accentColor
    }

    public func makeNSView(context: Context) -> CrossPromoCardNSView {
        CrossPromoCardNSView(preview: card, icon: icon, accentColor: accentColor)
    }

    public func updateNSView(_ nsView: CrossPromoCardNSView, context: Context) {
        nsView.displayPreview(card: card, icon: icon, accentColor: accentColor)
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: CrossPromoCardNSView,
        context: Context
    ) -> CGSize? {
        fittingSize(for: proposal, nsView: nsView)
    }
}

@MainActor
private func fittingSize(
    for proposal: ProposedViewSize,
    nsView: CrossPromoCardNSView
) -> CGSize? {
    guard let width = proposal.width else { return nil }
    guard !nsView.isHidden else { return CGSize(width: width, height: 0) }
    let widthConstraint = nsView.widthAnchor.constraint(equalToConstant: width)
    widthConstraint.isActive = true
    let size = nsView.fittingSize
    widthConstraint.isActive = false
    return CGSize(width: width, height: size.height)
}
#endif
