#if canImport(UIKit)
import UIKit

/// Locates the app's key window — the one whose view hierarchy the inspector
/// hit-tests and scans — while ignoring the inspector's own overlay window.
enum HostWindowResolver {

    static func keyWindow() -> UIWindow? {
        let candidates = allWindows().filter { !($0 is InspectorWindow) && !$0.isHidden }
        if let key = candidates.first(where: { $0.isKeyWindow }) {
            return key
        }
        return candidates.max(by: { $0.windowLevel < $1.windowLevel })
    }

    private static func allWindows() -> [UIWindow] {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        }
        return UIApplication.shared.windows
    }
}

@available(iOS 13.0, *)
enum WindowSceneResolver {
    static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}
#endif
