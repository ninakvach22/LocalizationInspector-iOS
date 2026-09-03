#if canImport(UIKit)
import UIKit

/// A single persistent outline drawn over the app to mark the view currently
/// being inspected.
enum ViewHighlighter {

    private static weak var box: UIView?

    static func highlight(_ view: UIView) {
        clear()
        guard let window = view.window else { return }
        let frame = view.convert(view.bounds, to: window)
        let outline = UIView(frame: frame.insetBy(dx: -1, dy: -1))
        outline.isUserInteractionEnabled = false
        outline.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.18)
        outline.layer.borderColor = UIColor.systemTeal.cgColor
        outline.layer.borderWidth = 2
        outline.layer.zPosition = .greatestFiniteMagnitude
        window.addSubview(outline)
        box = outline
    }

    static func clear() {
        box?.removeFromSuperview()
        box = nil
    }
}
#endif
