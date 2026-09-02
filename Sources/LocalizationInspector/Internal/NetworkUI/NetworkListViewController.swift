#if canImport(UIKit)
import UIKit

final class NetworkListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
                                       UISearchResultsUpdating {

    private let apiHosts: [String]
    private var all: [NetworkTransaction] = []
    private var filtered: [NetworkTransaction] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let scopeControl = UISegmentedControl(items: NetworkScope.allCases.map { $0.title })
    private let search = UISearchController(searchResultsController: nil)
    private var scope: NetworkScope = .all

    init(apiHosts: [String] = []) {
        self.apiHosts = apiHosts
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network"
        view.backgroundColor = .systemBackgroundCompat
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearTapped))

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Filter by URL"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false

        scopeControl.selectedSegmentIndex = 0
        scopeControl.addTarget(self, action: #selector(scopeChanged), for: .valueChanged)
        let scopeBar = UIView()
        scopeBar.translatesAutoresizingMaskIntoConstraints = false
        scopeControl.translatesAutoresizingMaskIntoConstraints = false
        scopeBar.addSubview(scopeControl)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        tableView.register(NetworkTransactionCell.self, forCellReuseIdentifier: NetworkTransactionCell.reuseID)

        view.addSubview(scopeBar)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            scopeBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scopeBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scopeBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scopeControl.topAnchor.constraint(equalTo: scopeBar.topAnchor, constant: 8),
            scopeControl.bottomAnchor.constraint(equalTo: scopeBar.bottomAnchor, constant: -8),
            scopeControl.leadingAnchor.constraint(equalTo: scopeBar.leadingAnchor, constant: 12),
            scopeControl.trailingAnchor.constraint(equalTo: scopeBar.trailingAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: scopeBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: NetworkTransactionStore.didChangeNotification, object: nil)
        reload()
    }

    @objc private func reload() {
        all = NetworkTransactionStore.shared.snapshot()
        applyFilter()
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func clearTapped() { NetworkTransactionStore.shared.clear() }

    @objc private func scopeChanged() {
        scope = NetworkScope(rawValue: scopeControl.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    func updateSearchResults(for searchController: UISearchController) { applyFilter() }

    private func applyFilter() {
        let term = search.searchBar.text?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        filtered = all.filter { transaction in
            guard scope.includes(transaction, apiHosts: apiHosts) else { return false }
            guard !term.isEmpty else { return true }
            return transaction.url?.absoluteString.lowercased().contains(term) ?? false
        }

        let apiCount = all.filter { NetworkScope.isAPI($0, apiHosts: apiHosts) }.count
        scopeControl.setTitle("API (\(apiCount))", forSegmentAt: NetworkScope.api.rawValue)
        scopeControl.setTitle("Other (\(all.count - apiCount))", forSegmentAt: NetworkScope.other.rawValue)
        scopeControl.setTitle("All (\(all.count))", forSegmentAt: NetworkScope.all.rawValue)

        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.isEmpty ? 1 : filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if filtered.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = all.isEmpty ? "No requests observed yet" : "No matches"
            cell.textLabel?.textColor = .secondaryLabelCompat
            cell.selectionStyle = .none
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: NetworkTransactionCell.reuseID, for: indexPath) as! NetworkTransactionCell
        cell.configure(with: filtered[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !filtered.isEmpty else { return }
        navigationController?.pushViewController(NetworkDetailViewController(transaction: filtered[indexPath.row]), animated: true)
    }
}

extension UIColor {
    static var secondaryLabelCompat: UIColor {
        if #available(iOS 13.0, *) { return .secondaryLabel }
        return .darkGray
    }
    static var systemBackgroundCompat: UIColor {
        if #available(iOS 13.0, *) { return .systemBackground }
        return .white
    }
}
#endif
