import Foundation

/// Records `key → resolved value` pairs as the app resolves them, so a label's
/// text can be traced back to the exact key it was set from instead of guessed
/// by matching the string against every CMS entry.
final class KeyResolutionRecorder {

    static let shared = KeyResolutionRecorder()

    private var byValue: [String: [String]] = [:]
    private var order: [String] = []
    private let queue = DispatchQueue(label: "LocalizationInspector.KeyRecorder")
    private let cap = 4000

    private(set) var isActive = false

    private init() {}

    func activate() { isActive = true }

    func record(key: String, value: String) {
        guard key != value else { return }        // undefined key ⇒ nothing to trace
        queue.sync {
            var keys = byValue[value] ?? []
            if let existing = keys.firstIndex(of: key) {
                keys.remove(at: existing)
            } else {
                order.append(value)
                if order.count > cap, let oldest = order.first {
                    order.removeFirst()
                    byValue[oldest] = nil
                }
            }
            keys.insert(key, at: 0)               // most-recent first
            byValue[value] = keys
        }
    }

    /// Keys observed to resolve to exactly this string, newest first.
    func keys(for value: String) -> [String] {
        queue.sync { byValue[value] ?? [] }
    }
}
