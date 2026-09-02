#if canImport(UIKit)
import UIKit

/// Recursively finds every visible text-bearing view whose text is not backed
/// by a defined CMS key — i.e. hardcoded text or an undefined backend key.
enum MissingKeyScanner {

    struct Hit {
        let view: UIView
        let text: String
        let classification: KeyMatcher.Classification
    }

    static func scan(_ root: UIView, matcher: KeyMatcher, ignoring: [UIView]) -> [Hit] {
        var results: [Hit] = []
        walk(root, matcher: matcher, ignoring: ignoring, into: &results)
        return results
    }

    private static func walk(_ view: UIView, matcher: KeyMatcher, ignoring: [UIView], into results: inout [Hit]) {
        for subview in view.subviews {
            if ignoring.contains(where: { $0 === subview }) { continue }

            if !subview.isHidden, subview.alpha > 0.01,
               let text = ViewIntrospector.text(from: subview), !text.isEmpty {
                let classification = matcher.classify(text)
                switch classification {
                case .backendExact:
                    break
                case .backendPartial, .backendUndefined, .staticText:
                    results.append(Hit(view: subview, text: text, classification: classification))
                }
            }

            walk(subview, matcher: matcher, ignoring: ignoring, into: &results)
        }
    }
}
#endif
