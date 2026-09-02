import Foundation

/// Reverse-resolves an on-screen string to its CMS localization key(s).
/// Pure value type, no UIKit — unit tested in isolation.
struct KeyMatcher {

    enum Classification: Equatable {
        /// The text matches the resolved value of one or more keys.
        case backendDefined(keys: [String])
        /// The text itself is a key path that has no entry — i.e. the CMS
        /// returned the raw key because it is not defined in the panel yet.
        case backendUndefined(key: String)
        /// No key produces this text; it is hardcoded in code.
        case staticText
    }

    let entries: [String: String]
    var allowsPartialMatch = true
    var detectsUndefinedKeys = true

    private static let keyPathPattern = "^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+$"

    func classify(_ rawText: String) -> Classification {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .staticText }

        let matched = matchingKeys(for: text)
        if !matched.isEmpty {
            return .backendDefined(keys: matched)
        }

        if detectsUndefinedKeys, entries[text] == nil, looksLikeKeyPath(text) {
            return .backendUndefined(key: text)
        }

        return .staticText
    }

    /// Keys whose resolved value equals `text` (exact), or — falling back —
    /// whose value is contained in `text`. Whitespace-only values (e.g. a `" "`
    /// placeholder) are ignored, and partial matching needs a value of at least
    /// two visible characters so a stray `"-"` or `"."` doesn't match everything.
    func matchingKeys(for text: String) -> [String] {
        let meaningful = entries.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let exact = meaningful.filter { $0.value == text }.map { $0.key }
        if !exact.isEmpty {
            return exact.sorted()
        }

        guard allowsPartialMatch else { return [] }
        let partial = meaningful
            .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && text.contains($0.value) }
            .map { $0.key }
        return partial.sorted()
    }

    private func looksLikeKeyPath(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        return text.range(of: Self.keyPathPattern, options: .regularExpression) != nil
    }
}
