#if canImport(UIKit)
import UIKit

/// Builds the text of the result alert and decides what is copyable.
enum ResultFormatter {

    struct Output {
        var message: String
        var copyableKey: String?
        var copyableColor: String?
    }

    static func makeOutput(for view: UIView, hostWindow: UIWindow?, matcher: KeyMatcher) -> Output {
        var lines: [String] = []
        var copyableKey: String?
        var copyableColor: String?

        if let (text, sourceView) = ViewIntrospector.displayedText(startingFrom: view) {
            lines.append("View: \(type(of: sourceView))")
            lines.append("Text: \"\(text)\"")

            if let color = ViewIntrospector.textColor(from: sourceView),
               let hex = ViewIntrospector.hexString(from: color) {
                lines.append("Text Color: \(hex)")
                copyableColor = hex
            }

            if let font = ViewIntrospector.font(from: sourceView) {
                lines.append("Font: \(font.fontName) \(Int(font.pointSize))pt")
            }

            if let window = hostWindow {
                let frame = sourceView.convert(sourceView.bounds, to: window)
                lines.append("Frame: x:\(Int(frame.origin.x)) y:\(Int(frame.origin.y)) w:\(Int(frame.width)) h:\(Int(frame.height))")
            }

            switch matcher.classify(text) {
            case let .backendExact(keys) where keys.count == 1:
                lines.append("\nSource: Backend (CMS) — exact match")
                lines.append("Key: \(keys[0])")
                copyableKey = keys[0]
            case let .backendExact(keys):
                lines.append("\nSource: Backend (CMS) — exact match, \(keys.count) keys share this value")
                lines.append("Keys:\n" + keys.joined(separator: "\n"))
                copyableKey = keys.first
            case let .backendPartial(keys) where keys.count == 1:
                lines.append("\nSource: Backend (CMS) — partial match")
                lines.append("This text contains the value of key: \(keys[0])")
                copyableKey = keys[0]
            case let .backendPartial(keys):
                lines.append("\nSource: Backend (CMS) — partial match, \(keys.count) candidates")
                lines.append("Contains the value of one of:\n" + keys.joined(separator: "\n"))
                copyableKey = keys.first
            case let .backendUndefined(key):
                lines.append("\nSource: Backend (CMS) — key not defined in panel")
                lines.append("Key: \(key)")
                copyableKey = key
            case .staticText:
                lines.append("\nSource: Static (hardcoded in code)")
                lines.append("No matching CMS key found for this text.")
            }
        } else {
            lines.append("View: \(type(of: view))")
            lines.append("No text found on this view.")
            if let window = hostWindow {
                let frame = view.convert(view.bounds, to: window)
                lines.append("Frame: x:\(Int(frame.origin.x)) y:\(Int(frame.origin.y)) w:\(Int(frame.width)) h:\(Int(frame.height))")
            }
        }

        if let (background, backgroundView) = ViewIntrospector.nearestBackgroundColor(from: view),
           let hex = ViewIntrospector.hexString(from: background) {
            let suffix = backgroundView === view ? "" : " (from \(type(of: backgroundView)))"
            lines.append("\nBackground: \(hex)\(suffix)")
            if copyableColor == nil { copyableColor = hex }
        }

        return Output(message: lines.joined(separator: "\n"), copyableKey: copyableKey, copyableColor: copyableColor)
    }
}
#endif
