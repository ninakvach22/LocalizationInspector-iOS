#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime

/// Objective-C runtime introspection of an object's declared properties and ivars.
enum RuntimeIntrospect {

    /// Keys that are known to crash or have heavy side effects when read via KVC.
    private static let unsafeKeys: Set<String> = [
        "_currentEditingRegion", "recursiveDescription", "_autolayoutTrace",
        "viewForBaselineLayout", "viewForFirstBaselineLayout", "viewForLastBaselineLayout"
    ]

    static func propertySections(for object: NSObject, maxClasses: Int = 6) -> [ViewDescribe.Section] {
        var sections: [ViewDescribe.Section] = []
        var cls: AnyClass? = type(of: object)
        var visited = 0

        while let current = cls, current != NSObject.self, visited < maxClasses {
            let className = String(describing: current)
            var rows: [(String, String)] = []

            var count: UInt32 = 0
            if let list = class_copyPropertyList(current, &count) {
                for i in 0..<Int(count) {
                    let name = String(cString: property_getName(list[i]))
                    rows.append((name, value(of: object, key: name)))
                }
                free(list)
            }
            if !rows.isEmpty {
                rows.sort { $0.0 < $1.0 }
                sections.append(ViewDescribe.Section(title: "@property — \(className)", rows: rows))
            }
            cls = class_getSuperclass(current)
            visited += 1
        }
        return sections
    }

    static func ivarSection(for object: NSObject) -> ViewDescribe.Section? {
        var rows: [(String, String)] = []
        var cls: AnyClass? = type(of: object)
        var visited = 0

        while let current = cls, current != NSObject.self, visited < 6 {
            var count: UInt32 = 0
            if let list = class_copyIvarList(current, &count) {
                for i in 0..<Int(count) {
                    let ivar = list[i]
                    let name = ivar_getName(ivar).map { String(cString: $0) } ?? "?"
                    let encoding = ivar_getTypeEncoding(ivar).map { String(cString: $0) } ?? "?"
                    rows.append((name, ivarValue(object, ivar: ivar, encoding: encoding)))
                }
                free(list)
            }
            cls = class_getSuperclass(current)
            visited += 1
        }
        guard !rows.isEmpty else { return nil }
        rows.sort { $0.0 < $1.0 }
        return ViewDescribe.Section(title: "ivars", rows: rows)
    }

    // MARK: - Value reading

    private static func value(of object: NSObject, key: String) -> String {
        guard !unsafeKeys.contains(key) else { return "<skipped>" }
        let getter = NSSelectorFromString(key)
        guard object.responds(to: getter) else { return "<no getter>" }
        guard let raw = object.value(forKey: key) else { return "nil" }
        return describe(raw)
    }

    private static func ivarValue(_ object: NSObject, ivar: Ivar, encoding: String) -> String {
        if encoding.hasPrefix("@") {
            if let value = object_getIvar(object, ivar) {
                return describe(value)
            }
            return "nil"
        }
        return "<\(encoding)>"
    }

    private static func describe(_ value: Any) -> String {
        switch value {
        case let s as String: return "“\(s)”"
        case let n as NSNumber: return "\(n)"
        case let color as UIColor: return ViewIntrospector.hexString(from: color) ?? "\(color)"
        case let view as UIView: return "<\(type(of: view)) \(ViewDescribe.frameSummary(for: view))>"
        case let array as [Any]: return "[\(array.count) items]"
        case let dict as [AnyHashable: Any]: return "{\(dict.count) keys}"
        default:
            let s = String(describing: value)
            return s.count > 200 ? String(s.prefix(200)) + "…" : s
        }
    }
}
#endif
