#if canImport(UIKit)
import UIKit

/// Transparent window that floats above the app at `.statusBar + 1`.
/// Touches pass straight through to the app window except on the inspector's
/// own controls (and, while inspect mode is on, its full-screen tap overlay).
final class InspectorWindow: UIWindow {

    private var inspectorRoot: InspectorRootViewController? {
        rootViewController as? InspectorRootViewController
    }

    convenience init() {
        if #available(iOS 13.0, *), let scene = WindowSceneResolver.activeScene() {
            self.init(windowScene: scene)
        } else {
            self.init(frame: UIScreen.main.bounds)
        }
        windowLevel = .statusBar + 1
        backgroundColor = .clear
        let root = InspectorRootViewController()
        rootViewController = root
        isHidden = false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let root = inspectorRoot else { return nil }

        // A presented alert (our result popup) must stay fully interactive.
        if root.presentedViewController != nil {
            return super.hitTest(point, with: event)
        }

        let hit = super.hitTest(point, with: event)
        if root.wantsTouch(at: point, hitView: hit) {
            return hit
        }
        return nil
    }
}
#endif
