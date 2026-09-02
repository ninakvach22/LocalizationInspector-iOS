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

    /// Master switch. `start(...)` does nothing while this is `false`, so a
    /// release build can leave the call in place. Default: `true`.
    public var isEnabled = true

    public init(entriesProvider: @escaping () -> [String: String]) {
        self.entriesProvider = entriesProvider
    }
}
