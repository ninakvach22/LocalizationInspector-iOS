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

    /// Hard kill switch: the tool only ever activates in a build compiled with
    /// `DEBUG` defined. SwiftPM builds this package with the app's own
    /// configuration, so a Release / App Store / standard TestFlight archive
    /// makes every entry point below a no-op — the floating window, the
    /// swizzles and the network interceptor cannot run there regardless of what
    /// the app calls.
    private var allowed: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Report a `key → resolved value` pair every time your content layer
    /// resolves one (one line inside `ContentManager.getText`). The inspector
    /// then swizzles the UIKit text setters and, when a recorded string is
    /// assigned to a label / button / field, stores the originating key on that
    /// view — so a tap reports the **exact** key it was set from instead of
    /// guessing by string match. Call it once early (before any text is set);
    /// the first call installs the swizzle.
    ///
    ///     func getText(_ key: String) -> String {
    ///         let value = newContents[key] ?? key
    ///         #if DEBUG
    ///         LocalizationInspector.shared.recordKeyResolution(key: key, value: value)
    ///         #endif
    ///         return value
    ///     }
    public func recordKeyResolution(key: String, value: String) {
        guard allowed else { return }
        if !KeyResolutionRecorder.shared.isActive {
            KeyResolutionRecorder.shared.activate()
            let install = { TextSetterSwizzler.install() }
            if Thread.isMainThread { install() } else { DispatchQueue.main.async(execute: install) }
        }
        KeyResolutionRecorder.shared.record(key: key, value: value)
    }

    /// Start recording network traffic immediately, without showing any UI.
    ///
    /// Call this as early as possible — the top of
    /// `application(_:didFinishLaunchingWithOptions:)` — so the interceptor is
    /// in place before your networking layer creates its `URLSession`
    /// (Alamofire reads `URLSessionConfiguration.default` when its `Session` is
    /// first built, and that only happens once). Idempotent.
    public func observeNetwork() {
        guard allowed else { return }
        NetworkObserver.install()
    }

    public func start(entriesProvider: @escaping () -> [String: String]) {
        start(configuration: LocalizationInspectorConfiguration(entriesProvider: entriesProvider))
    }

    public func start(configuration: LocalizationInspectorConfiguration) {
        guard allowed, configuration.isEnabled, !isRunning else { return }

        if configuration.observesNetwork {
            NetworkTransactionStore.shared.maxBodyBytes = configuration.maxNetworkBodyBytes
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
