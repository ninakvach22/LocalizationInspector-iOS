#if canImport(UIKit)
import UIKit

/// Toggles the inspector when the device is shaken. Installed by swizzling
/// `UIWindow.motionEnded(_:with:)` so it works regardless of the first responder.
enum ShakeDetector {

    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        guard let a = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionEnded(_:with:))),
              let b = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.li_motionEnded(_:with:))) else { return }
        method_exchangeImplementations(a, b)
    }
}

private extension UIWindow {
    @objc func li_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        li_motionEnded(motion, with: event)                 // swapped ⇒ original
        if motion == .motionShake, !(self is InspectorWindow) {
            LocalizationInspector.shared.handleShake()
        }
    }
}
#endif
