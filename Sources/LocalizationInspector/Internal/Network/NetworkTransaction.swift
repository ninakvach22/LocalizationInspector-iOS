import Foundation

/// One observed HTTP(S) request/response round trip.
final class NetworkTransaction {

    let id = UUID()
    let request: URLRequest
    let startedAt: Date

    private(set) var response: HTTPURLResponse?
    private(set) var responseBody: Data?
    private(set) var responseBodyTruncated = false
    private(set) var error: Error?
    private(set) var finishedAt: Date?

    /// Bytes actually received (before any truncation for storage).
    private(set) var receivedByteCount: Int64 = 0

    init(request: URLRequest, startedAt: Date = Date()) {
        self.request = request
        self.startedAt = startedAt
    }

    func recordResponse(_ response: URLResponse?) {
        self.response = response as? HTTPURLResponse
    }

    func appendReceived(_ data: Data) {
        receivedByteCount += Int64(data.count)
    }

    func finish(body: Data?, truncated: Bool, error: Error?, at date: Date = Date()) {
        self.responseBody = body
        self.responseBodyTruncated = truncated
        self.error = error
        self.finishedAt = date
    }

    // MARK: - Derived

    var url: URL? { request.url }
    var method: String { request.httpMethod ?? "GET" }
    var statusCode: Int? { response?.statusCode }

    /// Case-insensitive response header lookup (iOS 12 compatible).
    func responseHeader(_ name: String) -> String? {
        guard let headers = response?.allHeaderFields else { return nil }
        let lowered = name.lowercased()
        for (key, value) in headers where (key as? String)?.lowercased() == lowered {
            return value as? String
        }
        return nil
    }

    var contentType: String? { responseHeader("Content-Type") }

    var duration: TimeInterval? {
        guard let finishedAt = finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    var isFinished: Bool { finishedAt != nil }

    var requestBody: Data? {
        if let body = request.httpBody { return body }
        if let stream = request.httpBodyStream { return NetworkTransaction.data(from: stream) }
        return nil
    }

    private static func data(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
