import Foundation

public struct LocalizationInspectorConfiguration {

    /// Returns the current key → resolved-value map for every localized string
    /// the app knows about. Called each time the inspector resolves a tap or
    /// runs a scan, so it always reflects the latest content.
    public var entriesProvider: () -> [String: String]

    /// When the on-screen text is itself a key path (`section.element.modifier`)
    /// that has no entry, report it as an undefined backend key rather than as
    /// hardcoded text. Matches the ContentManager convention of returning the
    /// raw key when the CMS panel has no value for it. Default: `true`.
    public var detectsUndefinedKeys = true

    /// Also match a key when its value is *contained* in the on-screen text,
    /// not only on an exact match. Default: `true`.
    public var allowsPartialMatch = true

    /// Record every HTTP(S) request/response (timing, headers, bodies) made
    /// through `URLSession` and browse them from the 🌐 button. Installs a
    /// URL-loading interceptor, so it is opt-in. Default: `false`.
    public var observesNetwork = false

    /// Largest response body kept in memory per request (bigger ones are stored
    /// truncated and shown as text rather than, say, an image preview).
    /// Default: 4 MB.
    public var maxNetworkBodyBytes = 4 * 1024 * 1024

    /// Hosts that count as "your API" in the 🌐 list's All / API / Other filter,
    /// matched as a domain suffix (`"jety.app"` matches `"mobile.jety.app"`).
    /// When empty, the API filter falls back to "path contains /api". Analytics
    /// and telemetry traffic then lands under "Other". Default: `[]`.
    public var apiHosts: [String] = []

    /// Show the floating buttons as soon as `start(...)` is called. When
    /// `false` (default) the inspector is armed but hidden until a shake or an
    /// explicit `show()` — and it remembers the last state across launches.
    public var startsVisible = false

    /// Shake the device to show / hide the floating buttons. Default: `true`.
    public var togglesOnShake = true

    /// Master switch. `start(...)` does nothing while this is `false`, so a
    /// release build can leave the call in place. Default: `true`.
    public var isEnabled = true

    public init(entriesProvider: @escaping () -> [String: String]) {
        self.entriesProvider = entriesProvider
    }
}
