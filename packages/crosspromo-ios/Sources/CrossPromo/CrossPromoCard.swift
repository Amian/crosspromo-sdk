#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
public final class CrossPromoCardUIView: UIView {
    public var placement: CrossPromoPlacement {
        didSet { reload() }
    }
    public var onError: ((Error) -> Void)?
    public var onCardLoaded: ((PromoCardData?) -> Void)?

    private let container = UIStackView()
    private let iconWrapper = UIView()
    private let iconView = UIImageView()
    private let textStack = UIStackView()
    private let subtitleRow = UIStackView()
    private let appNameLabel = UILabel()
    private let taglineLabel = UILabel()
    private let adChip = InsetLabel()
    private let ctaButton = UIButton(type: .system)
    private var card: PromoCardData?
    private var accent: IconAccent?
    private var loadTask: Task<Void, Never>?
    private var imageTask: Task<Void, Never>?
    private var viewabilityTracker: ViewabilityTracker?
    private var expandedLayoutConstraints: [NSLayoutConstraint] = []
    private var collapsedHeightConstraint: NSLayoutConstraint!

    public init(placement: CrossPromoPlacement) {
        self.placement = placement
        super.init(frame: .zero)
        configureView()
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(placement:)")
    }

    deinit {
        loadTask?.cancel()
        imageTask?.cancel()
    }

    public func reload() {
        loadTask?.cancel()
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

    private func configureView() {
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        iconWrapper.translatesAutoresizingMaskIntoConstraints = false
        iconWrapper.layer.shadowRadius = 9
        iconWrapper.layer.shadowOffset = CGSize(width: 0, height: 3)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.cornerRadius = 14
        iconView.layer.cornerCurve = .continuous
        iconView.layer.borderWidth = 0.5
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.backgroundColor = .tertiarySystemFill
        iconWrapper.addSubview(iconView)

        textStack.axis = .vertical
        textStack.spacing = 3
        appNameLabel.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
        appNameLabel.adjustsFontForContentSizeCategory = true
        appNameLabel.textColor = .label
        appNameLabel.numberOfLines = 2
        taglineLabel.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 13))
        taglineLabel.adjustsFontForContentSizeCategory = true
        taglineLabel.textColor = .secondaryLabel
        taglineLabel.numberOfLines = 2

        adChip.attributedText = NSAttributedString(
            string: "AD",
            attributes: [
                .font: UIFont.systemFont(ofSize: 7.5, weight: .heavy),
                .kern: 0.5,
            ]
        )
        adChip.layer.cornerRadius = 4
        adChip.layer.cornerCurve = .continuous
        adChip.clipsToBounds = true
        adChip.translatesAutoresizingMaskIntoConstraints = false

        subtitleRow.axis = .horizontal
        subtitleRow.alignment = .center
        subtitleRow.spacing = 10
        subtitleRow.addArrangedSubview(taglineLabel)
        subtitleRow.addArrangedSubview(ctaButton)
        textStack.addArrangedSubview(appNameLabel)
        textStack.addArrangedSubview(subtitleRow)

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.cornerStyle = .capsule
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 8, leading: 16, bottom: 8, trailing: 16
        )
        buttonConfiguration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                return updated
            }
        ctaButton.configuration = buttonConfiguration
        ctaButton.layer.shadowRadius = 7
        ctaButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        ctaButton.setContentHuggingPriority(.required, for: .horizontal)
        ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        ctaButton.addTarget(self, action: #selector(openCard), for: .touchUpInside)

        addSubview(container)
        container.addArrangedSubview(iconWrapper)
        container.addArrangedSubview(textStack)
        addSubview(adChip)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openCard)))

        NSLayoutConstraint.activate([
            iconWrapper.widthAnchor.constraint(equalToConstant: 56),
            iconWrapper.heightAnchor.constraint(equalTo: iconWrapper.widthAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconWrapper.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconWrapper.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
        ])
        expandedLayoutConstraints = [
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            adChip.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            adChip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 84),
        ]
        collapsedHeightConstraint = heightAnchor.constraint(equalToConstant: 0)
        setCollapsed(true)
        applyPalette(animated: false)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
        iconWrapper.layer.shadowPath = UIBezierPath(
            roundedRect: iconWrapper.bounds,
            cornerRadius: iconView.layer.cornerRadius
        ).cgPath
        ctaButton.layer.shadowPath = UIBezierPath(
            roundedRect: ctaButton.bounds,
            cornerRadius: ctaButton.bounds.height / 2
        ).cgPath
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            refreshLayerColors()
        }
    }

    private func apply(_ card: PromoCardData?) {
        self.card = card
        guard let card else {
            setCollapsed(true)
            return
        }
        appNameLabel.text = card.appName
        taglineLabel.text = card.tagline
        ctaButton.configuration?.title = card.cta
        iconView.image = nil
        accent = nil
        applyPalette(animated: false)
        accessibilityLabel = "Ad. \(card.appName). \(card.tagline)"
        setCollapsed(false)
        animateEntrance()
        loadIcon(from: card.iconURL)
        viewabilityTracker = ViewabilityTracker(view: self) { [weak self] fraction, duration in
            guard let self, let currentCard = self.card else { return }
            Task {
                try? await CrossPromo.client.recordImpression(
                    for: currentCard,
                    visibleFraction: fraction,
                    duration: duration
                )
            }
        }
    }

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        container.alpha = 0
        container.transform = CGAffineTransform(translationX: 0, y: 10)
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction]
        ) {
            self.container.alpha = 1
            self.container.transform = .identity
        }
    }

    private func applyPalette(animated: Bool) {
        let apply = {
            self.backgroundColor = self.makeCardBackground()
            self.adChip.backgroundColor = self.makeChipBackground()
            self.adChip.textColor = self.makeChipText()
            self.ctaButton.configuration?.baseBackgroundColor = self.makeCtaBackground()
            self.ctaButton.configuration?.baseForegroundColor = self.makeCtaForeground()
            self.refreshLayerColors()
        }
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(
                with: self,
                duration: 0.35,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: apply
            )
        } else {
            apply()
        }
    }

    /// Layer colors don't resolve dynamic `UIColor`s on their own, so they are
    /// re-resolved here on every palette or light/dark change.
    private func refreshLayerColors() {
        let dark = traitCollection.userInterfaceStyle == .dark
        layer.borderColor = makeHairline().resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = dark ? 0 : 0.07
        iconView.layer.borderColor = (dark
            ? UIColor.white.withAlphaComponent(0.16)
            : UIColor.black.withAlphaComponent(0.08)).cgColor
        if let accent {
            iconWrapper.layer.shadowColor = accent.glowColor(darkTheme: dark).cgColor
            iconWrapper.layer.shadowOpacity = dark ? 0.5 : 0.32
            ctaButton.layer.shadowColor = accent.ctaColor(darkTheme: dark).cgColor
            ctaButton.layer.shadowOpacity = dark ? 0.42 : 0.28
        } else {
            iconWrapper.layer.shadowOpacity = 0
            ctaButton.layer.shadowColor = UIColor.systemBlue
                .resolvedColor(with: traitCollection).cgColor
            ctaButton.layer.shadowOpacity = dark ? 0.35 : 0.22
        }
    }

    private func makeCardBackground() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            let base = dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.125, alpha: 1)
                : UIColor.white
            guard let accent else { return base }
            return Self.blend(accent.washColor(darkTheme: dark), over: base)
        }
    }

    private func makeHairline() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            guard let accent else { return .separator }
            return accent.hairlineColor(darkTheme: dark)
        }
    }

    private func makeChipBackground() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            guard let accent else { return .secondarySystemFill }
            return accent.chipBackgroundColor(darkTheme: dark)
        }
    }

    private func makeChipText() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            guard let accent else { return .secondaryLabel }
            return accent.chipTextColor(darkTheme: dark)
        }
    }

    private func makeCtaBackground() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            guard let accent else { return .systemBlue }
            return accent.ctaColor(darkTheme: dark)
        }
    }

    private func makeCtaForeground() -> UIColor {
        let accent = accent
        return UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            guard let accent else { return .white }
            return accent.onCtaColor(darkTheme: dark)
        }
    }

    private static func blend(_ top: UIColor, over base: UIColor) -> UIColor {
        var topRed: CGFloat = 0
        var topGreen: CGFloat = 0
        var topBlue: CGFloat = 0
        var topAlpha: CGFloat = 0
        top.getRed(&topRed, green: &topGreen, blue: &topBlue, alpha: &topAlpha)
        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: nil)
        return UIColor(
            red: topRed * topAlpha + baseRed * (1 - topAlpha),
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
        } else {
            collapsedHeightConstraint.isActive = false
            NSLayoutConstraint.activate(expandedLayoutConstraints)
        }
        isHidden = collapsed
    }

    private func loadIcon(from url: URL) {
        imageTask?.cancel()
        imageTask = Task { [weak self] in
            guard let self else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  !Task.isCancelled,
                  let image = UIImage(data: data) else { return }
            iconView.image = image
            let extracted = await Task.detached(priority: .utility) {
                IconAccent.extract(from: image)
            }.value
            guard !Task.isCancelled, let extracted else { return }
            accent = extracted
            applyPalette(animated: true)
        }
    }

    @objc private func openCard() {
        guard let url = card?.clickURL else { return }
        UIApplication.shared.open(url)
    }
}

/// Small pill label used for the "AD" disclosure chip.
private final class InsetLabel: UILabel {
    private let contentInsets = UIEdgeInsets(top: 1.5, left: 4, bottom: 1.5, right: 4)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}

@MainActor
private final class ViewabilityTracker {
    private weak var view: UIView?
    private let onQualified: (Double, TimeInterval) -> Void
    // Deinit is nonisolated in Swift 6. All live access still occurs on MainActor.
    nonisolated(unsafe) private var timer: Timer?
    private var visibleSince: Date?
    private var highestFraction = 0.0
    private var didReport = false

    init(view: UIView, onQualified: @escaping (Double, TimeInterval) -> Void) {
        self.view = view
        self.onQualified = onQualified
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }

    deinit { timer?.invalidate() }

    private func sample() {
        guard !didReport,
              UIApplication.shared.applicationState == .active,
              let view,
              let window = view.window,
              !view.isHidden,
              view.alpha > 0.01 else {
            visibleSince = nil
            return
        }
        let rect = view.convert(view.bounds, to: window)
        let intersection = rect.intersection(window.bounds)
        let totalArea = max(1, rect.width * rect.height)
        let fraction = max(0, intersection.width * intersection.height / totalArea)
        guard fraction >= 0.5 else {
            visibleSince = nil
            highestFraction = 0
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
}

public struct CrossPromoCard: UIViewRepresentable {
    public let placement: CrossPromoPlacement
    public var onError: ((Error) -> Void)?

    public init(placement: CrossPromoPlacement, onError: ((Error) -> Void)? = nil) {
        self.placement = placement
        self.onError = onError
    }

    public func makeUIView(context: Context) -> CrossPromoCardUIView {
        let view = CrossPromoCardUIView(placement: placement)
        view.onError = onError
        return view
    }

    public func updateUIView(_ uiView: CrossPromoCardUIView, context: Context) {
        uiView.onError = onError
        if uiView.placement != placement { uiView.placement = placement }
    }
}
#endif
