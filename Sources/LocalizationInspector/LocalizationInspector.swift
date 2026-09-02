#if canImport(UIKit)
import UIKit

/// Debug tool for reverse-looking-up the CMS localization key behind any text
/// on screen, and for spotting text that has no defined key.
///
/// Call `start(...)` once, from a debug build:
///
///     #if DEBUG
///     LocalizationInspector.shared.start { ContentManager.shared.newContents }
///     #endif
///
/// A floating 🔑 button toggles inspect mode (tap any label/button/field to see
/// its key, color, font and frame); the ⚠️ button highlights unbacked text.
public final class LocalizationInspector {

    public static let shared = LocalizationInspector()

    private var window: InspectorWindow?

    private init() {}

    public var isRunning: Bool { window != nil }

    /// Start recording network traffic immediately, without showing any UI.
    ///
    /// Call this as early as possible — the top of
    /// `application(_:didFinishLaunchingWithOptions:)` — so the interceptor is
    /// in place before your networking layer creates its `URLSession`
    /// (Alamofire reads `URLSessionConfiguration.default` when its `Session` is
    /// first built, and that only happens once). Idempotent.
    public func observeNetwork() {
        NetworkObserver.install()
    }

    public func start(entriesProvider: @escaping () -> [String: String]) {
        start(configuration: LocalizationInspectorConfiguration(entriesProvider: entriesProvider))
    }

    public func start(configuration: LocalizationInspectorConfiguration) {
        guard configuration.isEnabled, !isRunning else { return }

        if configuration.observesNetwork {
            NetworkObserver.install()
        }

        let install = { [weak self] in
            guard let self = self, !self.isRunning else { return }
            let window = InspectorWindow()
            (window.rootViewController as? InspectorRootViewController)?.configuration = configuration
            self.window = window
        }

        if Thread.isMainThread {
            install()
        } else {
            DispatchQueue.main.async(execute: install)
        }
    }

    public func stop() {
        let teardown = { [weak self] in
            self?.window?.isHidden = true
            self?.window = nil
        }
        if Thread.isMainThread {
            teardown()
        } else {
            DispatchQueue.main.async(execute: teardown)
        }
    }
}
#endif
