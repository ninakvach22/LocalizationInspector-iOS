#if canImport(UIKit)
import UIKit

final class NetworkTransactionCell: UITableViewCell {

    static let reuseID = "NetworkTransactionCell"

    private let statusLabel = UILabel()
    private let methodLabel = UILabel()
    private let urlLabel = UILabel()
    private let metaLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        statusLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        methodLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        methodLabel.textColor = .secondaryLabelCompat

        urlLabel.font = .systemFont(ofSize: 13)
        urlLabel.numberOfLines = 2
        urlLabel.lineBreakMode = .byTruncatingMiddle

        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelCompat

        let right = UIStackView(arrangedSubviews: [methodLabel, urlLabel, metaLabel])
        right.axis = .vertical
        right.spacing = 2

        let row = UIStackView(arrangedSubviews: [statusLabel, right])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with transaction: NetworkTransaction) {
        methodLabel.text = transaction.method.uppercased()
        urlLabel.text = transaction.url?.absoluteString ?? "—"

        if transaction.error != nil {
            statusLabel.text = "ERR"
            statusLabel.textColor = .systemRed
        } else if let code = transaction.statusCode {
            statusLabel.text = "\(code)"
            statusLabel.textColor = NetworkFormatting.statusColor(code)
        } else {
            statusLabel.text = "•••"
            statusLabel.textColor = .secondaryLabelCompat
        }

        let size = NetworkFormatting.byteString(transaction.receivedByteCount)
        let duration = NetworkFormatting.durationString(transaction.duration)
        metaLabel.text = "\(duration)  ·  \(size)"
    }
}
#endif
