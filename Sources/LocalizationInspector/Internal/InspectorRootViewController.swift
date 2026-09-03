#if canImport(UIKit)
import UIKit

final class InspectorRootViewController: UIViewController {

    var configuration: LocalizationInspectorConfiguration? {
        didSet { relayoutAccessories() }
    }

    private var isInspecting = false

    private lazy var toggleButton: UIButton = makeFloatingButton(
        title: "🔑", size: 48, fontSize: 22,
        background: UIColor.darkGray.withAlphaComponent(0.85),
        action: #selector(toggleTapped)
    )

    private lazy var networkButton: UIButton = makeFloatingButton(
        title: "🌐", size: 40, fontSize: 18,
        background: UIColor.systemBlue.withAlphaComponent(0.85),
        action: #selector(networkTapped)
    )

    private lazy var defaultsButton: UIButton = makeFloatingButton(
        title: "📋", size: 40, fontSize: 18,
        background: UIColor.systemPurple.withAlphaComponent(0.85),
        action: #selector(defaultsTapped)
    )

    private lazy var treeButton: UIButton = makeFloatingButton(
        title: "🌲", size: 40, fontSize: 18,
        background: UIColor.systemTeal.withAlphaComponent(0.85),
        action: #selector(treeTapped)
    )

    private var showsNetworkButton: Bool { configuration?.observesNetwork == true }

    /// Buttons stacked above the drag handle, closest first.
    private var accessoryButtons: [UIButton] {
        (showsNetworkButton ? [networkButton] : []) + [defaultsButton, treeButton]
    }

    private var isPickingView = false
    var isPickingViewOnScreen: Bool { isPickingView }

    private lazy var tapOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:))))
        return overlay
    }()

    private lazy var pickOverlay: UIView = {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.12)
        overlay.layer.borderColor = UIColor.systemTeal.cgColor
        overlay.layer.borderWidth = 3
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickOverlayTapped(_:))))
        return overlay
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(tapOverlay)
        view.addSubview(toggleButton)
        toggleButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(buttonDragged(_:))))
        tapOverlay.isHidden = true
        relayoutAccessories()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tapOverlay.frame = view.bounds
        if toggleButton.center == .zero {
            let safeBottom = view.safeAreaInsets.bottom
            toggleButton.center = CGPoint(x: view.bounds.width - 40, y: view.bounds.height - safeBottom - 72)
        }
        relayoutAccessories()
    }

    private func relayoutAccessories() {
        guard isViewLoaded else { return }
        let active = accessoryButtons
        for button in [networkButton, defaultsButton, treeButton] where !active.contains(button) {
            button.removeFromSuperview()
        }
        for (index, button) in active.enumerated() {
            if button.superview == nil { view.addSubview(button) }
            button.center = CGPoint(x: toggleButton.center.x,
                                    y: toggleButton.center.y - CGFloat(index + 1) * 56)
        }
    }

    // MARK: - Hit-testing bridge

    func wantsTouch(at point: CGPoint, hitView: UIView?) -> Bool {
        guard let hitView = hitView else { return false }
        if hitView === toggleButton || accessoryButtons.contains(where: { $0 === hitView }) { return true }
        if isInspecting, hitView === tapOverlay { return true }
        if isPickingView, hitView === pickOverlay { return true }
        return false
    }

    // MARK: - Accessory actions

    @objc private func networkTapped() {
        presentModally(NetworkListViewController(apiHosts: configuration?.apiHosts ?? []))
    }

    @objc private func defaultsTapped() {
        presentModally(UserDefaultsViewController())
    }

    @objc private func treeTapped() {
        presentModally(makeHierarchyController())
    }

    private func makeHierarchyController() -> ViewHierarchyViewController {
        ViewHierarchyViewController(root: HostWindowResolver.keyWindow()) { [weak self] in
            self?.beginViewPick()
        }
    }

    private func presentModally(_ root: UIViewController) {
        ViewHighlighter.clear()
        let nav = UINavigationController(rootViewController: root)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Pick a view on screen

    private func beginViewPick() {
        ViewHighlighter.clear()
        let show = { [weak self] in
            guard let self = self else { return }
            self.isPickingView = true
            self.setControlsHidden(true)
            self.pickOverlay.frame = self.view.bounds
            self.view.addSubview(self.pickOverlay)
            self.showToast("Tap any view to inspect it")
        }
        if presentedViewController != nil {
            dismiss(animated: true, completion: show)
        } else {
            show()
        }
    }

    private func setControlsHidden(_ hidden: Bool) {
        toggleButton.isHidden = hidden
        for button in [networkButton, defaultsButton, treeButton] { button.isHidden = hidden }
    }

    private func endViewPick() {
        isPickingView = false
        pickOverlay.removeFromSuperview()
        setControlsHidden(false)
    }

    @objc private func pickOverlayTapped(_ gesture: UITapGestureRecognizer) {
        endViewPick()
        guard let host = HostWindowResolver.keyWindow() else { return }
        let pointInSelf = gesture.location(in: view)
        let screenPoint = view.window?.convert(pointInSelf, to: nil) ?? pointInSelf
        let pointInHost = host.convert(screenPoint, from: nil)
        let picked = pickView(at: pointInHost, host: host)

        ViewHighlighter.highlight(picked)

        let hierarchy = makeHierarchyController()
        let detail = ViewDetailViewController(view: picked)
        let nav = UINavigationController(rootViewController: hierarchy)
        nav.viewControllers = [hierarchy, detail]
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    /// Deepest meaningful view under `point`. Walks the key window's subviews
    /// front-to-back and skips any transparent, near-full-screen container
    /// (e.g. an iOS 26 floating tab-bar host) so the tap lands on the real
    /// content behind it. Ignores `isUserInteractionEnabled` so passive labels
    /// are still selectable.
    private func pickView(at point: CGPoint, host: UIWindow) -> UIView {
        for windowSubview in host.subviews.reversed() {
            guard let candidate = deepestLeaf(at: point, in: windowSubview, host: host) else { continue }
            if isSkippableOverlay(candidate, host: host) { continue }
            return candidate
        }
        return host
    }

    private func deepestLeaf(at point: CGPoint, in view: UIView, host: UIWindow) -> UIView? {
        guard !view.isHidden, view.alpha > 0.01 else { return nil }
        guard view.bounds.contains(view.convert(point, from: host)) else { return nil }
        for subview in view.subviews.reversed() {
            if let hit = deepestLeaf(at: point, in: subview, host: host) { return hit }
        }
        return view
    }

    private func isSkippableOverlay(_ view: UIView, host: UIWindow) -> Bool {
        if let text = ViewIntrospector.text(from: view), !text.isEmpty { return false }
        if (view as? UIImageView)?.image != nil { return false }
        if let bg = view.backgroundColor, bg.cgColor.alpha > 0.01 { return false }
        let area = view.bounds.width * view.bounds.height
        let windowArea = host.bounds.width * host.bounds.height
        return windowArea > 0 && area >= windowArea * 0.85
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
        relayoutAccessories()
        if gesture.state == .ended || gesture.state == .cancelled {
            clamp(toggleButton)
            relayoutAccessories()
            accessoryButtons.forEach(clamp)
        }
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
