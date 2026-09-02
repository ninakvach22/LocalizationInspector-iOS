import Foundation

/// Thread-safe, size-capped history of observed network transactions.
final class NetworkTransactionStore {

    static let shared = NetworkTransactionStore()

    static let didChangeNotification = Notification.Name("LocalizationInspector.NetworkTransactionStore.didChange")

    /// Newest first.
    private(set) var transactions: [NetworkTransaction] = []

    var maxTransactions = 500
    /// Per-response body cap kept in memory.
    var maxBodyBytes = 4 * 1024 * 1024

    private let queue = DispatchQueue(label: "LocalizationInspector.NetworkStore")

    private init() {}

    func insert(_ transaction: NetworkTransaction) {
        queue.sync {
            transactions.insert(transaction, at: 0)
            if transactions.count > maxTransactions {
                transactions.removeLast(transactions.count - maxTransactions)
            }
        }
        postChange()
    }

    /// Call when an existing transaction has been mutated (response / finish).
    func markUpdated(_ transaction: NetworkTransaction) {
        postChange()
    }

    func clear() {
        queue.sync { transactions.removeAll() }
        postChange()
    }

    func snapshot() -> [NetworkTransaction] {
        queue.sync { transactions }
    }

    private func postChange() {
        let post = { NotificationCenter.default.post(name: Self.didChangeNotification, object: nil) }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }
}
