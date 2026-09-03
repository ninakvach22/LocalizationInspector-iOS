import Foundation
import os

/// Records `key → resolved value` pairs as the app resolves them, so a label's
/// text can be traced back to the exact key it was set from instead of guessed
/// by matching the string against every CMS entry.
///
/// The hot paths (every `getText`, every swizzled text setter) take a single
/// `os_unfair_lock` — cheaper than a GCD serial queue — and do one dictionary
/// operation. Active only in the app that opts in, typically a DEBUG build.
final class KeyResolutionRecorder {

    static let shared = KeyResolutionRecorder()

    private var byValue: [String: [String]] = [:]
    private var order: [String] = []
    private let lock: os_unfair_lock_t
    private let cap = 4000

    private(set) var isActive = false

    private init() {
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    func activate() { isActive = true }

    func record(key: String, value: String) {
        guard key != value, !value.isEmpty else { return }   // undefined key ⇒ nothing to trace
        os_unfair_lock_lock(lock)
        var keys = byValue[value] ?? []
        if let existing = keys.firstIndex(of: key) {
            keys.remove(at: existing)
        } else {
            order.append(value)
            if order.count > cap {
                let oldest = order.removeFirst()
                byValue[oldest] = nil
            }
        }
        keys.insert(key, at: 0)                               // most-recent first
        byValue[value] = keys
        os_unfair_lock_unlock(lock)
    }

    /// Keys observed to resolve to exactly this string, newest first.
    /// Fast path: returns `[]` immediately when nothing has been recorded.
    func keys(for value: String) -> [String] {
        guard isActive else { return [] }
        os_unfair_lock_lock(lock)
        let keys = byValue[value] ?? []
        os_unfair_lock_unlock(lock)
        return keys
    }
}
