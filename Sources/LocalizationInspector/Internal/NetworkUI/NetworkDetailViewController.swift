#if canImport(UIKit)
import UIKit

final class NetworkDetailViewController: UITableViewController {

    private enum Section {
        case text(title: String, body: String)
        case image(title: String, image: UIImage)

        var title: String {
            switch self {
            case let .text(title, _), let .image(title, _): return title
            }
        }
    }

    private let transaction: NetworkTransaction
    private var sections: [Section] = []

    init(transaction: NetworkTransaction) {
        self.transaction = transaction
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = transaction.url?.lastPathComponent ?? "Request"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped))

        tableView.register(MonospaceCell.self, forCellReuseIdentifier: MonospaceCell.reuseID)
        tableView.register(ImagePreviewCell.self, forCellReuseIdentifier: ImagePreviewCell.reuseID)
        tableView.separatorStyle = .none
        buildSections()

        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
                                               name: NetworkTransactionStore.didChangeNotification, object: nil)
    }

    @objc private func rebuild() {
        buildSections()
        tableView.reloadData()
    }

    private func buildSections() {
        var overview = [
            "URL: \(transaction.url?.absoluteString ?? "—")",
            "Method: \(transaction.method)",
            "Status: \(transaction.statusCode.map(String.init) ?? "—")",
            "Started: \(Self.timeFormatter.string(from: transaction.startedAt))",
            "Duration: \(NetworkFormatting.durationString(transaction.duration))",
            "Received: \(NetworkFormatting.byteString(transaction.receivedByteCount))"
        ]
        if let error = transaction.error {
            overview.append("Error: \(error.localizedDescription)")
        }
        if transaction.responseBodyTruncated {
            overview.append("Note: response body truncated for storage")
        }

        sections = [
            .text(title: "Overview", body: overview.joined(separator: "\n")),
            .text(title: "Request Headers", body: NetworkFormatting.headersString(transaction.request.allHTTPHeaderFields)),
            .text(title: "Request Body", body: NetworkFormatting.bodyString(transaction.requestBody)),
            .text(title: "Response Headers", body: NetworkFormatting.headersString(transaction.response?.allHeaderFields)),
            responseBodySection()
        ]
    }

    private func responseBodySection() -> Section {
        if let data = transaction.responseBody, !transaction.responseBodyTruncated,
           let image = UIImage(data: data) {
            return .image(title: "Response Body (image · \(Int(image.size.width))×\(Int(image.size.height)))", image: image)
        }
        return .text(title: "Response Body", body: NetworkFormatting.bodyString(transaction.responseBody))
    }

    @objc private func shareTapped() {
        var items: [Any] = [NetworkFormatting.curl(for: transaction)]
        if case let .image(_, image) = sections.last {
            items.append(image)
        } else {
            items.append("--- Response (\(transaction.statusCode.map(String.init) ?? "—")) ---\n"
                         + NetworkFormatting.bodyString(transaction.responseBody))
        }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case let .text(_, body):
            let cell = tableView.dequeueReusableCell(withIdentifier: MonospaceCell.reuseID, for: indexPath) as! MonospaceCell
            cell.setText(body)
            return cell
        case let .image(_, image):
            let cell = tableView.dequeueReusableCell(withIdentifier: ImagePreviewCell.reuseID, for: indexPath) as! ImagePreviewCell
            cell.setImage(image)
            return cell
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

private final class MonospaceCell: UITableViewCell {

    static let reuseID = "MonospaceCell"

    private let textView = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = .inspectorMonospaced(ofSize: 12)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ text: String) { textView.text = text }
}

private final class ImagePreviewCell: UITableViewCell {

    static let reuseID = "ImagePreviewCell"

    private let preview = UIImageView()
    private let checkerboard = CheckerboardView()
    private var aspectConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        preview.contentMode = .scaleAspectFit
        preview.translatesAutoresizingMaskIntoConstraints = false
        checkerboard.translatesAutoresizingMaskIntoConstraints = false
        checkerboard.layer.cornerRadius = 8
        checkerboard.clipsToBounds = true
        contentView.addSubview(checkerboard)
        checkerboard.addSubview(preview)
        NSLayoutConstraint.activate([
            checkerboard.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            checkerboard.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            checkerboard.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            checkerboard.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: checkerboard.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: checkerboard.trailingAnchor),
            preview.topAnchor.constraint(equalTo: checkerboard.topAnchor),
            preview.bottomAnchor.constraint(equalTo: checkerboard.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setImage(_ image: UIImage) {
        preview.image = image
        aspectConstraint?.isActive = false
        let ratio = image.size.height / max(image.size.width, 1)
        let c = preview.heightAnchor.constraint(equalTo: preview.widthAnchor, multiplier: min(ratio, 2))
        c.priority = .defaultHigh
        c.isActive = true
        aspectConstraint = c
    }
}

/// Light/dark checker so transparent PNGs are readable.
private final class CheckerboardView: UIView {
    override func draw(_ rect: CGRect) {
        let size: CGFloat = 10
        let light = UIColor(white: 0.85, alpha: 1)
        let dark = UIColor(white: 0.72, alpha: 1)
        var y: CGFloat = 0
        var row = 0
        while y < rect.height {
            var x: CGFloat = 0
            var col = 0
            while x < rect.width {
                ((row + col) % 2 == 0 ? light : dark).setFill()
                UIRectFill(CGRect(x: x, y: y, width: size, height: size))
                x += size; col += 1
            }
            y += size; row += 1
        }
    }
}
#endif
