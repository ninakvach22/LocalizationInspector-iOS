#if canImport(UIKit)
import UIKit

/// Pulls the displayed text and its styling out of the common text-bearing
/// UIKit views (UILabel / UIButton / UITextField / UITextView).
enum ViewIntrospector {

    static func text(from view: UIView) -> String? {
        switch view {
        case let label as UILabel: return label.text
        case let button as UIButton: return button.currentTitle
        case let textField as UITextField: return textField.text
        case let textView as UITextView: return textView.text
        default: return nil
        }
    }

    static func textColor(from view: UIView) -> UIColor? {
        switch view {
        case let label as UILabel: return label.textColor
        case let button as UIButton: return button.currentTitleColor
        case let textField as UITextField: return textField.textColor
        case let textView as UITextView: return textView.textColor
        default: return nil
        }
    }

    static func font(from view: UIView) -> UIFont? {
        switch view {
        case let label as UILabel: return label.font
        case let button as UIButton: return button.titleLabel?.font
        case let textField as UITextField: return textField.font
        case let textView as UITextView: return textView.font
        default: return nil
        }
    }

    /// Walks up at most `maxDepth` levels looking for a view that carries text.
    static func displayedText(startingFrom view: UIView, maxDepth: Int = 4) -> (text: String, view: UIView)? {
        var current: UIView? = view
        var depth = 0
        while let candidate = current, depth <= maxDepth {
            if let value = text(from: candidate), !value.isEmpty {
                return (value, candidate)
            }
            current = candidate.superview
            depth += 1
        }
        return nil
    }

    /// Nearest visible (non-nil, non-transparent) background color, walking up.
    static func nearestBackgroundColor(from view: UIView, maxDepth: Int = 6) -> (color: UIColor, view: UIView)? {
        var current: UIView? = view
        var depth = 0
        while let candidate = current, depth <= maxDepth {
            if let background = candidate.backgroundColor, background.cgColor.alpha > 0.01 {
                return (background, candidate)
            }
            current = candidate.superview
            depth += 1
        }
        return nil
    }

    /// "#RRGGBB", or "#RRGGBBAA" when translucent.
    static func hexString(from color: UIColor) -> String? {
        guard let components = color.cgColor.components else { return nil }
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        switch color.cgColor.numberOfComponents {
        case 2:
            red = components[0]; green = components[0]; blue = components[0]; alpha = components[1]
        case 3:
            red = components[0]; green = components[1]; blue = components[2]; alpha = 1
        case 4:
            red = components[0]; green = components[1]; blue = components[2]; alpha = components[3]
        default:
            return nil
        }
        let r = Int(round(red * 255)), g = Int(round(green * 255)), b = Int(round(blue * 255))
        if alpha < 0.999 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, Int(round(alpha * 255)))
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
#endif
