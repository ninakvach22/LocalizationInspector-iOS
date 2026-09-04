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
    private var configuration: LocalizationInspectorConfiguration?

    private init() {}

    public var isRunning: Bool { window != nil }

    /// Whether the floating buttons are currently on screen.
    public var isVisible: Bool { window?.isHidden == false }

    /// Opt in to running in a Release build that is *not* App Store production
    /// even without the sandbox receipt (e.g. an enterprise or ad-hoc QA build).
    /// Leave `false` for normal use. Never enables an App Store build on its own
    /// — set it only in a target/config that never ships to the App Store.
    public static var enableInRelease = false

    private static let hasSandboxReceipt: Bool =
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    /// Kill switch. The tool runs in a DEBUG build, or in a Release build
    /// installed via TestFlight / development (sandbox receipt), or when
    /// `enableInRelease` is set. It never runs in a build downloaded from the
    /// App Store.
    private var allowed: Bool {
        #if DEBUG
        return true
        #else
        return Self.enableInRelease || Self.hasSandboxReceipt
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

    /// Arms the inspector. **Call this once at the top of
    /// `application(_:didFinishLaunchingWithOptions:)`** — it installs the
    /// network interceptor and key recorder immediately, so requests made
    /// during launch / Splash are captured even though the floating buttons
    /// stay hidden. Every launch starts hidden; a shake (`config.togglesOnShake`)
    /// reveals the buttons for that session. `config.startsVisible` overrides.
    /// The UI window is only created when the buttons are first shown, so an
    /// early call is safe.
    public func start(configuration: LocalizationInspectorConfiguration) {
        guard allowed, configuration.isEnabled else { return }
        self.configuration = configuration

        if configuration.observesNetwork {
            NetworkTransactionStore.shared.maxBodyBytes = configuration.maxNetworkBodyBytes
            NetworkTransactionStore.shared.maxTransactions = configuration.maxNetworkTransactions
            NetworkObserver.install()
        }
        if configuration.togglesOnShake {
            onMain { ShakeDetector.install() }
        }
        if configuration.startsVisible {
            onMain { self.show() }
        }
    }

    /// Show the floating buttons now.
    public func show() {
        guard allowed, configuration != nil else { return }
        onMain {
            if self.window == nil {
                let window = InspectorWindow()
                (window.rootViewController as? InspectorRootViewController)?.configuration = self.configuration
                self.window = window
            }
            self.window?.isHidden = false
        }
    }

    /// Hide the floating buttons.
    public func stop() {
        onMain {
            self.window?.isHidden = true
            self.window = nil
        }
    }

    public func toggle() { isVisible ? stop() : show() }

    func handleShake() {
        guard allowed, configuration?.togglesOnShake == true else { return }
        let willShow = !isVisible
        toggle()
        Toast.show(willShow ? "Inspector shown" : "Inspector hidden — shake to show")
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}
#endif
