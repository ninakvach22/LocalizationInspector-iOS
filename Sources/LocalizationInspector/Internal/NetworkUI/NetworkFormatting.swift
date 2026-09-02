#if canImport(UIKit)
import UIKit

extension UIFont {
    static func inspectorMonospaced(ofSize size: CGFloat) -> UIFont {
        if #available(iOS 13.0, *) {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return UIFont(name: "Menlo", size: size) ?? .systemFont(ofSize: size)
    }
}

enum NetworkScope: Int, CaseIterable {
    case all, api, other

    var title: String {
        switch self {
        case .all: return "All"
        case .api: return "API"
        case .other: return "Other"
        }
    }

    /// `apiHosts` matched as a domain suffix; empty ⇒ fall back to "/api" in the path.
    func includes(_ transaction: NetworkTransaction, apiHosts: [String]) -> Bool {
        switch self {
        case .all:
            return true
        case .api:
            return Self.isAPI(transaction, apiHosts: apiHosts)
        case .other:
            return !Self.isAPI(transaction, apiHosts: apiHosts)
        }
    }

    static func isAPI(_ transaction: NetworkTransaction, apiHosts: [String]) -> Bool {
        guard let url = transaction.url, !isAsset(transaction) else { return false }
        if apiHosts.isEmpty {
            return url.path.lowercased().contains("/api")
        }
        let host = (url.host ?? "").lowercased()
        return apiHosts.contains { suffix in
            let s = suffix.lowercased()
            return host == s || host.hasSuffix("." + s)
        }
    }

    /// Static file / media / download — belongs under "Other", not "API".
    static func isAsset(_ transaction: NetworkTransaction) -> Bool {
        let extensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "heic", "ico",
            "pdf", "mp4", "mov", "m4v", "mp3", "wav", "aac", "m4a",
            "woff", "woff2", "ttf", "otf", "css", "js", "map", "zip", "gz"
        ]
        if let ext = transaction.url?.pathExtension.lowercased(), extensions.contains(ext) {
            return true
        }
        let type = (transaction.contentType ?? "").lowercased()
        return type.hasPrefix("image/") || type.hasPrefix("video/") || type.hasPrefix("audio/")
            || type.hasPrefix("font/") || type.contains("octet-stream")
    }
}

enum NetworkFormatting {

    static func statusColor(_ code: Int?) -> UIColor {
        guard let code = code else { return .systemGray }
        switch code {
        case 200..<300: return .systemGreen
        case 300..<400: return .systemBlue
        case 400..<500: return .systemOrange
        default: return .systemRed
        }
    }

    static func byteString(_ count: Int64) -> String {
        if count < 1024 { return "\(count) B" }
        let kb = Double(count) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.2f MB", kb / 1024)
    }

    static func durationString(_ seconds: TimeInterval?) -> String {
        guard let seconds = seconds else { return "…" }
        if seconds < 1 { return String(format: "%.0f ms", seconds * 1000) }
        return String(format: "%.2f s", seconds)
    }

    /// Pretty-prints JSON; otherwise returns a UTF-8 string; otherwise a hex-ish note.
    static func bodyString(_ data: Data?) -> String {
        guard let data = data, !data.isEmpty else { return "(empty)" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "(\(data.count) bytes of binary data)"
    }

    static func headersString(_ headers: [AnyHashable: Any]?) -> String {
        guard let headers = headers, !headers.isEmpty else { return "(none)" }
        return headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    static func curl(for transaction: NetworkTransaction) -> String {
        var parts = ["curl -v"]
        parts.append("-X \(transaction.method)")
        for (key, value) in transaction.request.allHTTPHeaderFields ?? [:] {
            parts.append("-H '\(key): \(value)'")
        }
        if let body = transaction.requestBody, let string = String(data: body, encoding: .utf8), !string.isEmpty {
            parts.append("--data '\(string)'")
        }
        parts.append("'\(transaction.url?.absoluteString ?? "")'")
        return parts.joined(separator: " \\\n  ")
    }
}
#endif
