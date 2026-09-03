#if canImport(UIKit)
import UIKit

/// Turns a UIView into human-readable sections of properties for the detail screen.
enum ViewDescribe {

    struct Section {
        let title: String
        let rows: [(label: String, value: String)]
    }

    static func shortLabel(for view: UIView) -> String {
        var label = String(describing: type(of: view))
        if let id = view.accessibilityIdentifier, !id.isEmpty {
            label += " #\(id)"
        } else if let text = ViewIntrospector.text(from: view), !text.isEmpty {
            let clipped = text.count > 24 ? String(text.prefix(24)) + "…" : text
            label += " “\(clipped)”"
        }
        return label
    }

    static func frameSummary(for view: UIView) -> String {
        let f = view.frame
        return "(\(fmt(f.origin.x)), \(fmt(f.origin.y)), \(fmt(f.width)), \(fmt(f.height)))"
    }

    static func sections(for view: UIView) -> [Section] {
        var sections: [Section] = []

        var identity: [(String, String)] = [
            ("Class", String(describing: type(of: view))),
            ("Address", String(format: "%p", UInt(bitPattern: ObjectIdentifier(view).hashValue))),
            ("Superclass chain", superclassChain(view)),
            ("Tag", "\(view.tag)")
        ]
        if let id = view.accessibilityIdentifier, !id.isEmpty { identity.append(("a11y id", id)) }
        if let l = view.accessibilityLabel, !l.isEmpty { identity.append(("a11y label", l)) }
        sections.append(Section(title: "Identity", rows: identity))

        let window = view.window
        var geometry: [(String, String)] = [
            ("frame", rect(view.frame)),
            ("bounds", rect(view.bounds)),
            ("center", "(\(fmt(view.center.x)), \(fmt(view.center.y)))")
        ]
        if let window = window {
            geometry.append(("frame in window", rect(view.convert(view.bounds, to: window))))
        }
        geometry.append(("safeAreaInsets", insets(view.safeAreaInsets)))
        geometry.append(("transform", view.transform == .identity ? "identity" : "\(view.transform)"))
        geometry.append(("autoresizingMask", "\(view.autoresizingMask.rawValue)"))
        geometry.append(("translatesAutoresizing…", bool(view.translatesAutoresizingMaskIntoConstraints)))
        geometry.append(("constraints", "\(view.constraints.count)"))
        sections.append(Section(title: "Geometry", rows: geometry))

        var appearance: [(String, String)] = [
            ("isHidden", bool(view.isHidden)),
            ("alpha", fmt(view.alpha)),
            ("opaque", bool(view.isOpaque)),
            ("userInteractionEnabled", bool(view.isUserInteractionEnabled)),
            ("clipsToBounds", bool(view.clipsToBounds)),
            ("contentMode", "\(view.contentMode.rawValue)")
        ]
        if let bg = view.backgroundColor { appearance.append(("backgroundColor", color(bg))) }
        appearance.append(("tintColor", color(view.tintColor)))
        sections.append(Section(title: "Appearance", rows: appearance))

        let layer = view.layer
        var layerRows: [(String, String)] = [
            ("cornerRadius", fmt(layer.cornerRadius)),
            ("borderWidth", fmt(layer.borderWidth)),
            ("masksToBounds", bool(layer.masksToBounds)),
            ("zPosition", fmt(layer.zPosition)),
            ("shadowOpacity", fmt(CGFloat(layer.shadowOpacity)))
        ]
        if let border = layer.borderColor { layerRows.append(("borderColor", color(UIColor(cgColor: border)))) }
        if layer.shadowOpacity > 0 {
            layerRows.append(("shadowRadius", fmt(layer.shadowRadius)))
            layerRows.append(("shadowOffset", "(\(fmt(layer.shadowOffset.width)), \(fmt(layer.shadowOffset.height)))"))
        }
        sections.append(Section(title: "Layer", rows: layerRows))

        if let text = ViewIntrospector.text(from: view) {
            var textRows: [(String, String)] = [("text", "“\(text)”")]
            if let font = ViewIntrospector.font(from: view) {
                textRows.append(("font", "\(font.fontName) \(fmt(font.pointSize))"))
            }
            if let tc = ViewIntrospector.textColor(from: view) {
                textRows.append(("textColor", color(tc)))
            }
            sections.append(Section(title: "Text", rows: textRows))
        }

        sections.append(Section(title: "Hierarchy", rows: [
            ("superview", view.superview.map { String(describing: type(of: $0)) } ?? "nil"),
            ("subviews", "\(view.subviews.count)"),
            ("window", window.map { String(describing: type(of: $0)) } ?? "nil"),
            ("next responder", view.next.map { String(describing: type(of: $0)) } ?? "nil")
        ]))

        return sections
    }

    static func plainText(for view: UIView) -> String {
        sections(for: view).map { section in
            "[\(section.title)]\n" + section.rows.map { "  \($0.label): \($0.value)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    // MARK: - Formatting

    private static func superclassChain(_ view: UIView) -> String {
        var names: [String] = []
        var cls: AnyClass? = type(of: view)
        while let c = cls, c != NSObject.self {
            names.append(String(describing: c))
            cls = class_getSuperclass(c)
        }
        return names.joined(separator: " → ")
    }

    private static func fmt(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
    private static func rect(_ r: CGRect) -> String {
        "{{\(fmt(r.origin.x)), \(fmt(r.origin.y))}, {\(fmt(r.width)), \(fmt(r.height))}}"
    }
    private static func insets(_ i: UIEdgeInsets) -> String {
        "(\(fmt(i.top)), \(fmt(i.left)), \(fmt(i.bottom)), \(fmt(i.right)))"
    }
    private static func bool(_ b: Bool) -> String { b ? "true" : "false" }
    private static func color(_ c: UIColor) -> String {
        ViewIntrospector.hexString(from: c) ?? "\(c)"
    }
}
#endif
