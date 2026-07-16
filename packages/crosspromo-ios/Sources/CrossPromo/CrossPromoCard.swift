#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
public final class CrossPromoCardUIView: UIView {
    public var placement: String {
        didSet { reload() }
    }
    public var onError: ((Error) -> Void)?
    public var onCardLoaded: ((PromoCardData?) -> Void)?

    private let container = UIStackView()
    private let iconView = UIImageView()
    private let textStack = UIStackView()
    private let appNameLabel = UILabel()
    private let taglineLabel = UILabel()
    private let disclosureLabel = UILabel()
    private let ctaButton = UIButton(type: .system)
    private var card: PromoCardData?
    private var loadTask: Task<Void, Never>?
    private var imageTask: Task<Void, Never>?
    private var viewabilityTracker: ViewabilityTracker?
    private var expandedLayoutConstraints: [NSLayoutConstraint] = []
    private var collapsedHeightConstraint: NSLayoutConstraint!

    public init(placement: String) {
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
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        backgroundColor = .secondarySystemBackground

        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        iconView.layer.cornerRadius = 12
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.backgroundColor = .tertiarySystemFill

        textStack.axis = .vertical
        textStack.spacing = 3
        appNameLabel.font = .preferredFont(forTextStyle: .headline)
        appNameLabel.numberOfLines = 1
        taglineLabel.font = .preferredFont(forTextStyle: .subheadline)
        taglineLabel.textColor = .secondaryLabel
        taglineLabel.numberOfLines = 2
        disclosureLabel.font = .preferredFont(forTextStyle: .caption2)
        disclosureLabel.textColor = .tertiaryLabel
        disclosureLabel.text = "Ad · Indie pick"
        textStack.addArrangedSubview(appNameLabel)
        textStack.addArrangedSubview(taglineLabel)
        textStack.addArrangedSubview(disclosureLabel)

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.cornerStyle = .capsule
        ctaButton.configuration = buttonConfiguration
        ctaButton.addTarget(self, action: #selector(openCard), for: .touchUpInside)

        addSubview(container)
        container.addArrangedSubview(iconView)
        container.addArrangedSubview(textStack)
        container.addArrangedSubview(ctaButton)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 58),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
        ])
        expandedLayoutConstraints = [
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 82),
        ]
        collapsedHeightConstraint = heightAnchor.constraint(equalToConstant: 0)
        setCollapsed(true)
    }

    private func apply(_ card: PromoCardData?) {
        self.card = card
        guard let card else {
            setCollapsed(true)
            return
        }
        appNameLabel.text = card.appName
        taglineLabel.text = card.tagline
        ctaButton.setTitle(card.cta, for: .normal)
        iconView.image = nil
        accessibilityLabel = "Ad. \(card.appName). \(card.tagline)"
        setCollapsed(false)
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
        }
    }

    @objc private func openCard() {
        guard let url = card?.clickURL else { return }
        UIApplication.shared.open(url)
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
    public let placement: String
    public var onError: ((Error) -> Void)?

    public init(placement: String, onError: ((Error) -> Void)? = nil) {
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
