#if canImport(UIKit)
import UIKit

final class NetworkDetailViewController: UITableViewController {

    private let transaction: NetworkTransaction
    private var sections: [(title: String, body: String)] = []

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
            ("Overview", overview.joined(separator: "\n")),
            ("Request Headers", NetworkFormatting.headersString(transaction.request.allHTTPHeaderFields)),
            ("Request Body", NetworkFormatting.bodyString(transaction.requestBody)),
            ("Response Headers", NetworkFormatting.headersString(transaction.response?.allHeaderFields)),
            ("Response Body", NetworkFormatting.bodyString(transaction.responseBody))
        ]
    }

    @objc private func shareTapped() {
        let text = """
        \(NetworkFormatting.curl(for: transaction))

        --- Response (\(transaction.statusCode.map(String.init) ?? "—")) ---
        \(NetworkFormatting.bodyString(transaction.responseBody))
        """
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(sheet, animated: true)
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MonospaceCell.reuseID, for: indexPath) as! MonospaceCell
        cell.setText(sections[indexPath.section].body)
        return cell
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
#endif
