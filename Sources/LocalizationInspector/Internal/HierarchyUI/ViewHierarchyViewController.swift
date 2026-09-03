#if canImport(UIKit)
import UIKit

final class ViewHierarchyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
                                         UISearchResultsUpdating {

    private struct Row {
        let view: UIView
        let depth: Int
        let hasChildren: Bool
    }

    private weak var root: UIView?
    private let onPickRequested: (() -> Void)?
    private var collapsed = Set<ObjectIdentifier>()
    private var rows: [Row] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let search = UISearchController(searchResultsController: nil)

    init(root: UIView?, onPickRequested: (() -> Void)?) {
        self.root = root
        self.onPickRequested = onPickRequested
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "View Hierarchy"
        view.backgroundColor = .systemBackgroundCompat
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
        if onPickRequested != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Pick", style: .plain, target: self, action: #selector(pick))
        }

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Filter by class"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 48
        tableView.register(HierarchyCell.self, forCellReuseIdentifier: HierarchyCell.reuseID)
        view.addSubview(tableView)

        rebuild()
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func pick() { onPickRequested?() }

    func updateSearchResults(for searchController: UISearchController) { rebuild() }

    // MARK: - Tree

    private func rebuild() {
        rows.removeAll()
        guard let root = root else { tableView.reloadData(); return }

        let term = search.searchBar.text?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        if term.isEmpty {
            appendTree(root, depth: 0)
        } else {
            appendMatches(root, term: term)
        }
        tableView.reloadData()
    }

    private func appendTree(_ view: UIView, depth: Int) {
        let hasChildren = !view.subviews.isEmpty
        rows.append(Row(view: view, depth: depth, hasChildren: hasChildren))
        guard hasChildren, !collapsed.contains(ObjectIdentifier(view)) else { return }
        for subview in view.subviews {
            appendTree(subview, depth: depth + 1)
        }
    }

    private func appendMatches(_ view: UIView, term: String) {
        if String(describing: type(of: view)).lowercased().contains(term) {
            rows.append(Row(view: view, depth: 0, hasChildren: false))
        }
        for subview in view.subviews {
            appendMatches(subview, term: term)
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.isEmpty ? 1 : rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HierarchyCell.reuseID, for: indexPath) as! HierarchyCell
        if rows.isEmpty {
            cell.showPlaceholder(root == nil ? "No key window" : "No matches")
            return cell
        }
        let row = rows[indexPath.row]
        cell.configure(label: ViewDescribe.shortLabel(for: row.view),
                       detail: ViewDescribe.frameSummary(for: row.view) + "  ·  \(row.view.subviews.count) subviews",
                       depth: row.depth,
                       chevron: row.hasChildren ? (collapsed.contains(ObjectIdentifier(row.view)) ? .collapsed : .expanded) : .none)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rows.isEmpty else { return }
        let row = rows[indexPath.row]
        if row.hasChildren {
            let id = ObjectIdentifier(row.view)
            if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
            rebuild()
        } else {
            showDetail(for: row.view)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard !rows.isEmpty else { return }
        showDetail(for: rows[indexPath.row].view)
    }

    func showDetail(for view: UIView) {
        navigationController?.pushViewController(ViewDetailViewController(view: view), animated: true)
    }
}

// MARK: - Cell

private final class HierarchyCell: UITableViewCell {

    static let reuseID = "HierarchyCell"

    enum Chevron { case none, collapsed, expanded }

    private let chevronLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private var leadingConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .detailButton

        chevronLabel.font = .systemFont(ofSize: 11)
        chevronLabel.textColor = .secondaryLabelCompat
        chevronLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.font = .inspectorMonospaced(ofSize: 12)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelCompat

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1

        let stack = UIStackView(arrangedSubviews: [chevronLabel, text])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let leading = stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        leadingConstraint = leading
        NSLayoutConstraint.activate([
            leading,
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, detail: String, depth: Int, chevron: Chevron) {
        titleLabel.text = label
        detailLabel.text = detail
        detailLabel.isHidden = false
        leadingConstraint?.constant = 12 + CGFloat(depth) * 14
        switch chevron {
        case .none: chevronLabel.text = "  "
        case .collapsed: chevronLabel.text = "▶"
        case .expanded: chevronLabel.text = "▼"
        }
        accessoryType = .detailButton
        selectionStyle = .default
    }

    func showPlaceholder(_ message: String) {
        titleLabel.text = message
        titleLabel.font = .systemFont(ofSize: 14)
        detailLabel.isHidden = true
        chevronLabel.text = "  "
        leadingConstraint?.constant = 12
        accessoryType = .none
        selectionStyle = .none
    }
}
#endif
