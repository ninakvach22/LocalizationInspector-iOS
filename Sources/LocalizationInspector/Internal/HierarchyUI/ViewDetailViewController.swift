#if canImport(UIKit)
import UIKit

final class ViewDetailViewController: UITableViewController {

    private weak var target: UIView?
    private var sections: [ViewDescribe.Section] = []
    private var flashView: UIView?

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
            UIBarButtonItem(title: "Flash", style: .plain, target: self, action: #selector(flash))
        ]
        tableView.register(PropertyCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 48
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
    }

    private func rebuild() {
        guard let target = target else { sections = []; tableView.reloadData(); return }
        sections = ViewDescribe.sections(for: target)
        tableView.reloadData()
    }

    @objc private func share() {
        guard let target = target else { return }
        let sheet = UIActivityViewController(activityItems: [ViewDescribe.plainText(for: target)], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(sheet, animated: true)
    }

    /// Briefly overlays a colored box on the real view so you can spot it on screen.
    @objc private func flash() {
        guard let target = target, let window = target.window else { return }
        flashView?.removeFromSuperview()
        let box = UIView(frame: target.convert(target.bounds, to: window))
        box.backgroundColor = UIColor.systemPink.withAlphaComponent(0.35)
        box.layer.borderColor = UIColor.systemPink.cgColor
        box.layer.borderWidth = 1
        box.isUserInteractionEnabled = false
        box.layer.zPosition = .greatestFiniteMagnitude
        window.addSubview(box)
        flashView = box
        UIView.animate(withDuration: 0.9, delay: 0.6, options: [], animations: { box.alpha = 0 },
                       completion: { _ in box.removeFromSuperview() })
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
