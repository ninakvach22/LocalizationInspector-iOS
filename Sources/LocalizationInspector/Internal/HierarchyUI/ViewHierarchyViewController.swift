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
    private weak var reveal: UIView?
    private let onPickRequested: (() -> Void)?
    private var collapsed = Set<ObjectIdentifier>()
    private var rows: [Row] = []

    private let hScroll = UIScrollView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let search = UISearchController(searchResultsController: nil)
    private var didReveal = false

    init(root: UIView?, reveal: UIView? = nil, onPickRequested: (() -> Void)?) {
        self.root = root
        self.reveal = reveal
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

        hScroll.frame = view.bounds
        hScroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hScroll.alwaysBounceHorizontal = true
        hScroll.showsHorizontalScrollIndicator = true
        if #available(iOS 11.0, *) { hScroll.contentInsetAdjustmentBehavior = .never }
        view.addSubview(hScroll)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 48
        tableView.register(HierarchyCell.self, forCellReuseIdentifier: HierarchyCell.reuseID)
        hScroll.addSubview(tableView)

        rebuild()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutContent()
    }

    private func layoutContent() {
        let maxDepth = CGFloat(rows.map { $0.depth }.max() ?? 0)
        let contentWidth = max(view.bounds.width, view.bounds.width + maxDepth * 14 + 80)
        tableView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: hScroll.bounds.height)
        hScroll.contentSize = CGSize(width: contentWidth, height: hScroll.bounds.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        revealIfNeeded()
    }

    @objc private func close() {
        ViewHighlighter.clear()
        dismiss(animated: true)
    }

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
        layoutContent()
    }

    private func revealIfNeeded() {
        guard !didReveal, let reveal = reveal else { return }
        didReveal = true

        // make sure every ancestor is expanded
        var ancestor = reveal.superview
        while let a = ancestor {
            collapsed.remove(ObjectIdentifier(a))
            if a === root { break }
            ancestor = a.superview
        }
        rebuild()

        guard let index = rows.firstIndex(where: { $0.view === reveal }) else { return }
        let indexPath = IndexPath(row: index, section: 0)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak tableView] in
            tableView?.deselectRow(at: indexPath, animated: true)
        }
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
        cell.onChevronTap = { [weak self] in self?.toggle(row.view) }
        return cell
    }

    private func toggle(_ view: UIView) {
        let id = ObjectIdentifier(view)
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        rebuild()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !rows.isEmpty else { return }
        showDetail(for: rows[indexPath.row].view)
    }

    func showDetail(for view: UIView) {
        ViewHighlighter.highlight(view)
        navigationController?.pushViewController(ViewDetailViewController(view: view), animated: true)
    }
}

// MARK: - Cell

private final class HierarchyCell: UITableViewCell {

    static let reuseID = "HierarchyCell"

    enum Chevron { case none, collapsed, expanded }

    var onChevronTap: (() -> Void)?

    private let chevronButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private var leadingConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        chevronButton.titleLabel?.font = .systemFont(ofSize: 12)
        chevronButton.setTitleColor(.secondaryLabelCompat, for: .normal)
        chevronButton.addTarget(self, action: #selector(chevronTapped), for: .touchUpInside)
        chevronButton.setContentHuggingPriority(.required, for: .horizontal)
        chevronButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.font = .inspectorMonospaced(ofSize: 12)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byClipping
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelCompat
        detailLabel.numberOfLines = 1
        detailLabel.lineBreakMode = .byClipping

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 1

        let stack = UIStackView(arrangedSubviews: [chevronButton, text])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let leading = stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
        leadingConstraint = leading
        NSLayoutConstraint.activate([
            leading,
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            chevronButton.widthAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func chevronTapped() { onChevronTap?() }

    func configure(label: String, detail: String, depth: Int, chevron: Chevron) {
        titleLabel.text = label
        detailLabel.text = detail
        leadingConstraint?.constant = 8 + CGFloat(depth) * 14
        switch chevron {
        case .none: chevronButton.setTitle("·", for: .normal); chevronButton.isUserInteractionEnabled = false
        case .collapsed: chevronButton.setTitle("▶", for: .normal); chevronButton.isUserInteractionEnabled = true
        case .expanded: chevronButton.setTitle("▼", for: .normal); chevronButton.isUserInteractionEnabled = true
        }
        selectionStyle = .default
    }

    func showPlaceholder(_ message: String) {
        titleLabel.text = message
        titleLabel.font = .systemFont(ofSize: 14)
        detailLabel.text = nil
        chevronButton.setTitle("", for: .normal)
        chevronButton.isUserInteractionEnabled = false
        onChevronTap = nil
        leadingConstraint?.constant = 12
        selectionStyle = .none
    }
}
#endif
