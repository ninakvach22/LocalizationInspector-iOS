#if canImport(UIKit)
import UIKit

/// A single outline drawn over the app to mark the view being inspected /
/// previewed. Reused across calls so it can update smoothly during a drag.
enum ViewHighlighter {

    /// The live outline view, so hit-testing can ignore it.
    private(set) static weak var box: UIView?
    private static var strongBox: UIView?

    static func highlight(_ view: UIView) {
        guard let window = view.window else { clear(); return }
        let frame = view.convert(view.bounds, to: window).insetBy(dx: -1, dy: -1)

        let outline: UIView
        if let existing = strongBox, existing.window === window {
            outline = existing
        } else {
            clear()
            outline = UIView()
            outline.isUserInteractionEnabled = false
            outline.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.18)
            outline.layer.borderColor = UIColor.systemTeal.cgColor
            outline.layer.borderWidth = 2
            outline.layer.zPosition = .greatestFiniteMagnitude
            window.addSubview(outline)
            strongBox = outline
            box = outline
        }
        window.bringSubviewToFront(outline)
        outline.frame = frame
    }

    static func clear() {
        strongBox?.removeFromSuperview()
        strongBox = nil
        box = nil
    }
}
#endif
