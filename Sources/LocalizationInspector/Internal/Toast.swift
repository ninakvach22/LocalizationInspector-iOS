#if canImport(UIKit)
import UIKit

enum Toast {
    static func show(_ message: String) {
        guard let window = HostWindowResolver.keyWindow() ?? UIApplication.shared.windows.first else { return }
        let label = UILabel()
        label.text = "  \(message)  "
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.cornerRadius = 9
        label.clipsToBounds = true
        label.alpha = 0
        label.layer.zPosition = .greatestFiniteMagnitude

        let maxWidth = window.bounds.width - 40
        let size = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: (window.bounds.width - min(size.width, maxWidth)) / 2,
                             y: window.safeAreaInsets.top + 14,
                             width: min(size.width, maxWidth),
                             height: size.height + 14)
        window.addSubview(label)
        UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.4, options: [], animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}
#endif
