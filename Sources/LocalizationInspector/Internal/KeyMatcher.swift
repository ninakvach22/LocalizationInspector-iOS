import Foundation

/// Reverse-resolves an on-screen string to its CMS localization key(s).
/// Pure value type, no UIKit — unit tested in isolation.
struct KeyMatcher {

    enum Classification: Equatable {
        /// The text is exactly the resolved value of one or more keys.
        case backendExact(keys: [String])
        /// The text only *contains* the resolved value of one or more keys —
        /// e.g. a composed string, or a value interpolated into a sentence.
        case backendPartial(keys: [String])
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

        // Whitespace-only values (a " " placeholder key) never count as a match.
        let meaningful = entries.filter {
            !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let exact = meaningful.filter { $0.value == text }.map { $0.key }.sorted()
        if !exact.isEmpty {
            return .backendExact(keys: exact)
        }

        if allowsPartialMatch {
            let partial = meaningful
                .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && text.contains($0.value) }
                .map { $0.key }
                .sorted()
            if !partial.isEmpty {
                return .backendPartial(keys: partial)
            }
        }

        if detectsUndefinedKeys, entries[text] == nil, looksLikeKeyPath(text) {
            return .backendUndefined(key: text)
        }

        return .staticText
    }

    private func looksLikeKeyPath(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        return text.range(of: Self.keyPathPattern, options: .regularExpression) != nil
    }
}
