#if canImport(UIKit)
import UIKit

final class InspectorRootViewController: UIViewController {

    var configuration: LocalizationInspectorConfiguration? {
        didSet { updateNetworkButtonVisibility() }
    }

    private var isInspecting = false
    private var highlightBoxes: [UIView] = []

    private lazy var toggleButton: UIButton = makeFloatingButton(
        title: "🔑", size: 48, fontSize: 22,
        background: UIColor.darkGray.withAlphaComponent(0.85),
        action: #selector(toggleTapped)
    )

    private lazy var scanButton: UIButton = makeFloatingButton(
        title: "⚠️", size: 40, fontSize: 18,
        background: UIColor.systemRed.withAlphaComponent(0.85),
        action: #selector(scanTapped)
    )

    private lazy var networkButton: UIButton = makeFloatingButton(
        title: "🌐", size: 40, fontSize: 18,
        background: UIColor.systemBlue.withAlphaComponent(0.85),
        action: #selector(networkTapped)
    )

    private var showsNetworkButton: Bool { configuration?.observesNetwork == true }

    private lazy var tapOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:))))
        return overlay
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(tapOverlay)
        view.addSubview(toggleButton)
        view.addSubview(scanButton)

        toggleButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(buttonDragged(_:))))
        tapOverlay.isHidden = true
        updateNetworkButtonVisibility()
    }

    private func updateNetworkButtonVisibility() {
        guard isViewLoaded else { return }
        if showsNetworkButton {
            if networkButton.superview == nil {
                view.addSubview(networkButton)
                pinAccessoryButtons()
            }
        } else {
            networkButton.removeFromSuperview()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tapOverlay.frame = view.bounds
        if toggleButton.center == .zero {
            let safeBottom = view.safeAreaInsets.bottom
            toggleButton.center = CGPoint(x: view.bounds.width - 40, y: view.bounds.height - safeBottom - 72)
            pinAccessoryButtons()
        }
    }

    // MARK: - Hit-testing bridge

    func wantsTouch(at point: CGPoint, hitView: UIView?) -> Bool {
        guard let hitView = hitView else { return false }
        if hitView === toggleButton || hitView === scanButton || hitView === networkButton { return true }
        if isInspecting, hitView === tapOverlay { return true }
        return false
    }

    // MARK: - Network

    @objc private func networkTapped() {
        let list = NetworkListViewController(apiHosts: configuration?.apiHosts ?? [])
        let nav = UINavigationController(rootViewController: list)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Toggle

    @objc private func toggleTapped() {
        isInspecting.toggle()
        tapOverlay.isHidden = !isInspecting
        if isInspecting {
            view.insertSubview(tapOverlay, belowSubview: toggleButton)
            toggleButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
            showToast("Key Inspector ON — tap any text")
        } else {
            toggleButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.85)
        }
    }

    // MARK: - Scan

    @objc private func scanTapped() {
        if !highlightBoxes.isEmpty {
            clearHighlights()
            scanButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
            return
        }
        guard let host = HostWindowResolver.keyWindow(), let matcher = makeMatcher() else { return }

        let hits = MissingKeyScanner.scan(host, matcher: matcher, ignoring: [])
        var hardcoded = 0
        var undefined = 0
        var partial = 0
        for hit in hits {
            // Host window and this window are both full-screen at the origin,
            // so a rect in host-window space maps 1:1 into this view's space.
            let frameInSelf = hit.view.convert(hit.view.bounds, to: host)
            guard frameInSelf.width > 0, frameInSelf.height > 0 else { continue }

            let color: UIColor
            switch hit.classification {
            case .backendPartial:
                partial += 1
                color = .systemYellow
            case .backendUndefined:
                undefined += 1
                color = .systemOrange
            default:
                hardcoded += 1
                color = .systemRed
            }

            let box = UIView(frame: frameInSelf.insetBy(dx: -2, dy: -2))
            box.backgroundColor = .clear
            box.layer.borderColor = color.cgColor
            box.layer.borderWidth = 2
            box.isUserInteractionEnabled = false
            view.insertSubview(box, belowSubview: toggleButton)
            highlightBoxes.append(box)
        }

        scanButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        if hits.isEmpty {
            showToast("No unbacked text — everything on screen has an exact CMS key")
        } else {
            showToast("red \(hardcoded) hardcoded · orange \(undefined) undefined · yellow \(partial) partial")
        }
    }

    private func clearHighlights() {
        highlightBoxes.forEach { $0.removeFromSuperview() }
        highlightBoxes.removeAll()
    }

    // MARK: - Tap resolution

    @objc private func overlayTapped(_ gesture: UITapGestureRecognizer) {
        guard let host = HostWindowResolver.keyWindow(), let matcher = makeMatcher() else { return }
        let pointInSelf = gesture.location(in: view)
        let screenPoint = view.window?.convert(pointInSelf, to: nil) ?? pointInSelf
        let pointInHost = host.convert(screenPoint, from: nil)

        let target = deepestTextView(at: pointInHost, in: host, hostWindow: host)
            ?? host.hitTest(pointInHost, with: nil)
            ?? host
        let output = ResultFormatter.makeOutput(for: target, hostWindow: host, matcher: matcher)
        presentResult(output)
    }

    /// Frontmost, deepest text-bearing view containing `point` (in `hostWindow`
    /// coordinates). Unlike the real `hitTest` it does NOT skip views with
    /// `isUserInteractionEnabled == false` (UILabel has it off by default), but it
    /// also never returns a non-text container — so a full-screen transparent
    /// overlay on top of the content is walked past instead of swallowing the tap.
    private func deepestTextView(at point: CGPoint, in view: UIView, hostWindow: UIWindow) -> UIView? {
        guard !view.isHidden, view.alpha > 0.01 else { return nil }
        let local = view.convert(point, from: hostWindow)
        guard view.bounds.contains(local) else { return nil }
        for subview in view.subviews.reversed() {
            if let hit = deepestTextView(at: point, in: subview, hostWindow: hostWindow) {
                return hit
            }
        }
        if let text = ViewIntrospector.text(from: view), !text.isEmpty {
            return view
        }
        return nil
    }

    private func presentResult(_ output: ResultFormatter.Output) {
        let alert = UIAlertController(title: "Localization Inspector", message: output.message, preferredStyle: .alert)
        if let key = output.copyableKey {
            alert.addAction(UIAlertAction(title: "Copy Key", style: .default) { _ in
                UIPasteboard.general.string = key
            })
        }
        if let color = output.copyableColor {
            alert.addAction(UIAlertAction(title: "Copy Color (\(color))", style: .default) { _ in
                UIPasteboard.general.string = color
            })
        }
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Dragging

    @objc private func buttonDragged(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        toggleButton.center = CGPoint(x: toggleButton.center.x + translation.x,
                                      y: toggleButton.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
        pinAccessoryButtons()
        if gesture.state == .ended || gesture.state == .cancelled {
            clamp(toggleButton)
            pinAccessoryButtons()
            clamp(scanButton)
            if showsNetworkButton { clamp(networkButton) }
        }
    }

    private func pinAccessoryButtons() {
        scanButton.center = CGPoint(x: toggleButton.center.x, y: toggleButton.center.y - 56)
        networkButton.center = CGPoint(x: toggleButton.center.x, y: toggleButton.center.y - 108)
    }

    private func clamp(_ button: UIButton) {
        let halfW = button.bounds.width / 2
        let halfH = button.bounds.height / 2
        let insets = view.safeAreaInsets
        button.center.x = min(max(button.center.x, halfW + 8), view.bounds.width - halfW - 8)
        button.center.y = min(max(button.center.y, insets.top + halfH + 8),
                              view.bounds.height - insets.bottom - halfH - 8)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        let label = PaddedLabel()
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.alpha = 0

        let maxWidth = view.bounds.width - 40
        let size = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: (view.bounds.width - min(size.width, maxWidth)) / 2,
                             y: view.safeAreaInsets.top + 16,
                             width: min(size.width, maxWidth),
                             height: size.height)
        view.addSubview(label)
        UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 1.5, options: [], animations: { label.alpha = 0 },
                           completion: { _ in label.removeFromSuperview() })
        })
    }

    // MARK: - Helpers

    private func makeMatcher() -> KeyMatcher? {
        guard let configuration = configuration else { return nil }
        return KeyMatcher(entries: configuration.entriesProvider(),
                          allowsPartialMatch: configuration.allowsPartialMatch,
                          detectsUndefinedKeys: configuration.detectsUndefinedKeys)
    }

    private func makeFloatingButton(title: String, size: CGFloat, fontSize: CGFloat,
                                    background: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: size, height: size)
        button.center = .zero
        button.backgroundColor = background
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: fontSize)
        button.layer.cornerRadius = size / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 4
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

private final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize { addInsets(to: super.intrinsicContentSize) }
    override func sizeThatFits(_ size: CGSize) -> CGSize { addInsets(to: super.sizeThatFits(size)) }
    private func addInsets(to size: CGSize) -> CGSize {
        CGSize(width: size.width + inset.left + inset.right, height: size.height + inset.top + inset.bottom)
    }
}
#endif
