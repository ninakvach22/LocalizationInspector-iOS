#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime

/// Swizzles the common UIKit text setters so that, whenever a string that the
/// app just resolved from a key is assigned, the originating key(s) are stored
/// on the view as an associated object — an exact, non-guessed answer.
enum TextSetterSwizzler {

    private static var installed = false
    static var associatedKey: UInt8 = 0

    static func install() {
        guard !installed else { return }
        installed = true
        swizzle(UILabel.self, #selector(setter: UILabel.text), to: #selector(UILabel.li_setText(_:)))
        swizzle(UITextField.self, #selector(setter: UITextField.text), to: #selector(UITextField.li_setText(_:)))
        swizzle(UITextView.self, #selector(setter: UITextView.text), to: #selector(UITextView.li_setText(_:)))
        swizzle(UIButton.self, #selector(UIButton.setTitle(_:for:)), to: #selector(UIButton.li_setTitle(_:for:)))
    }

    static func recordedKeys(for view: UIView) -> [String] {
        (objc_getAssociatedObject(view, &associatedKey) as? [String]) ?? []
    }

    static func attachKeys(for text: String?, to view: UIView) {
        guard KeyResolutionRecorder.shared.isActive,
              let text = text, !text.isEmpty else { return }
        let keys = KeyResolutionRecorder.shared.keys(for: text)
        objc_setAssociatedObject(view, &associatedKey, keys.isEmpty ? nil : keys,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static func swizzle(_ cls: AnyClass, _ original: Selector, to replacement: Selector) {
        guard let a = class_getInstanceMethod(cls, original),
              let b = class_getInstanceMethod(cls, replacement) else { return }
        method_exchangeImplementations(a, b)
    }
}

private extension UILabel {
    @objc func li_setText(_ text: String?) {
        li_setText(text)                              // swapped ⇒ calls the original
        TextSetterSwizzler.attachKeys(for: text, to: self)
    }
}

private extension UITextField {
    @objc func li_setText(_ text: String?) {
        li_setText(text)
        TextSetterSwizzler.attachKeys(for: text, to: self)
    }
}

private extension UITextView {
    @objc func li_setText(_ text: String?) {
        li_setText(text)
        TextSetterSwizzler.attachKeys(for: text, to: self)
    }
}

private extension UIButton {
    @objc func li_setTitle(_ title: String?, for state: UIControl.State) {
        li_setTitle(title, for: state)
        if state == .normal { TextSetterSwizzler.attachKeys(for: title, to: self) }
    }
}
#endif
