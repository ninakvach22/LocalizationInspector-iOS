#if canImport(UIKit)
import UIKit

final class ViewDetailViewController: UITableViewController {

    private weak var target: UIView?
    private var sections: [ViewDescribe.Section] = []
    private var showsRuntime = false

    init(view: UIView) {
        self.target = view
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = target.map { String(describing: type(of: $0)) } ?? "View"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share)),
            UIBarButtonItem(title: "Runtime", style: .plain, target: self, action: #selector(toggleRuntime))
        ]
        tableView.register(PropertyCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 48
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
        if let target = target { ViewHighlighter.highlight(target) }
    }

    private func rebuild() {
        guard let target = target else { sections = []; tableView.reloadData(); return }
        sections = ViewDescribe.sections(for: target)
        if showsRuntime {
            sections += RuntimeIntrospect.propertySections(for: target)
            if let ivars = RuntimeIntrospect.ivarSection(for: target) { sections.append(ivars) }
        }
        tableView.reloadData()
    }

    @objc private func toggleRuntime() {
        showsRuntime.toggle()
        navigationItem.rightBarButtonItems?.last?.style = showsRuntime ? .done : .plain
        rebuild()
    }

    @objc private func share() {
        guard let target = target else { return }
        let sheet = UIActivityViewController(activityItems: [ViewDescribe.plainText(for: target)], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(sheet, animated: true)
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.textLabel?.text = row.label
        cell.textLabel?.font = .systemFont(ofSize: 12)
        cell.textLabel?.textColor = .secondaryLabelCompat
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.font = .inspectorMonospaced(ofSize: 12)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = nil
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = sections[indexPath.section].rows[indexPath.row].value
    }
}

private final class PropertyCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) { fatalError() }
}
#endif
