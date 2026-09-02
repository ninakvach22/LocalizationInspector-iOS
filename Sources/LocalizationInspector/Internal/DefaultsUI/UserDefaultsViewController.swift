#if canImport(UIKit)
import UIKit

final class UserDefaultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
                                        UISearchResultsUpdating {

    private struct Entry {
        let key: String
        let value: Any
    }

    private let defaults = UserDefaults.standard
    private var all: [Entry] = []
    private var filtered: [Entry] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let scopeControl = UISegmentedControl(items: ["App", "All"])
    private let search = UISearchController(searchResultsController: nil)

    private static let systemPrefixes = ["Apple", "NS", "com.apple", "kSC", "AK", "PK",
                                         "WebKit", "INNext", "METAL", "CADisableMinimumFrameDuration",
                                         "GoogleMobileAds", "GADApplicationIdentifier"]

    init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UserDefaults"
        view.backgroundColor = .systemBackgroundCompat
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload))

        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Filter by key"
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false

        scopeControl.selectedSegmentIndex = 0
        scopeControl.addTarget(self, action: #selector(applyFilter), for: .valueChanged)
        let scopeBar = UIView()
        scopeBar.translatesAutoresizingMaskIntoConstraints = false
        scopeControl.translatesAutoresizingMaskIntoConstraints = false
        scopeBar.addSubview(scopeControl)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: "cell")

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

        reload()
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func reload() {
        all = defaults.dictionaryRepresentation()
            .map { Entry(key: $0.key, value: $0.value) }
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
        applyFilter()
    }

    func updateSearchResults(for searchController: UISearchController) { applyFilter() }

    @objc private func applyFilter() {
        let term = search.searchBar.text?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let appOnly = scopeControl.selectedSegmentIndex == 0
        filtered = all.filter { entry in
            if appOnly, Self.systemPrefixes.contains(where: { entry.key.hasPrefix($0) }) { return false }
            if !term.isEmpty, !entry.key.lowercased().contains(term) { return false }
            return true
        }
        scopeControl.setTitle("App (\(all.filter { e in !Self.systemPrefixes.contains { e.key.hasPrefix($0) } }.count))", forSegmentAt: 0)
        scopeControl.setTitle("All (\(all.count))", forSegmentAt: 1)
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.isEmpty ? 1 : filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if filtered.isEmpty {
            cell.textLabel?.text = "No matching keys"
            cell.detailTextLabel?.text = nil
            cell.textLabel?.textColor = .secondaryLabelCompat
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        }
        let entry = filtered[indexPath.row]
        cell.textLabel?.text = entry.key
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = Self.preview(of: entry.value)
        cell.detailTextLabel?.textColor = .secondaryLabelCompat
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !filtered.isEmpty else { return }
        let entry = filtered[indexPath.row]
        let message = "Type: \(Self.typeName(of: entry.value))\n\n\(Self.fullString(of: entry.value))"
        let alert = UIAlertController(title: entry.key, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy value", style: .default) { _ in
            UIPasteboard.general.string = Self.fullString(of: entry.value)
        })
        alert.addAction(UIAlertAction(title: "Delete key", style: .destructive) { [weak self] _ in
            self?.defaults.removeObject(forKey: entry.key)
            self?.reload()
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Value formatting

    private static func typeName(of value: Any) -> String {
        switch value {
        case is String: return "String"
        case let number as NSNumber:
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? "Bool" : "Number"
        case is Data: return "Data"
        case is Date: return "Date"
        case is [Any]: return "Array"
        case is [String: Any]: return "Dictionary"
        default: return String(describing: type(of: value))
        }
    }

    private static func preview(of value: Any) -> String {
        let s = fullString(of: value).replacingOccurrences(of: "\n", with: " ")
        return s.count > 120 ? String(s.prefix(120)) + "…" : s
    }

    private static func fullString(of value: Any) -> String {
        if let data = value as? Data {
            if let object = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
               let text = String(data: pretty, encoding: .utf8) {
                return text
            }
            if let text = String(data: data, encoding: .utf8) { return text }
            return "\(data.count) bytes"
        }
        if JSONSerialization.isValidJSONObject(value),
           let pretty = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(describing: value)
    }
}

private final class SubtitleCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) { fatalError() }
}
#endif
