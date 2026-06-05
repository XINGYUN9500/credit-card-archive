import UIKit

struct CreditCard: Codable, Equatable {
    var id: String
    var bank: String
    var name: String
    var last4: String
    var statementDay: String
    var paymentDay: String
    var cashback: String
    var notes: String
}

struct CardEnvelope: Codable { var cards: [CreditCard] }

final class CardStore {
    static let shared = CardStore()
    private let key = "credit-card-archive-native-ios-v1"
    private(set) var cards: [CreditCard] = []

    private init() { load() }

    func upsert(_ card: CreditCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) { cards[index] = card } else { cards.insert(card, at: 0) }
        save()
    }

    func delete(at index: Int) {
        guard cards.indices.contains(index) else { return }
        cards.remove(at: index)
        save()
    }

    func exportText() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(CardEnvelope(cards: cards))) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{\n  \"cards\": []\n}"
    }

    func importText(_ text: String) throws {
        guard let data = text.data(using: .utf8) else { throw ImportError.invalidText }
        let object = try JSONSerialization.jsonObject(with: data)
        let rawItems: [Any]
        if let list = object as? [Any] {
            rawItems = list
        } else if let dict = object as? [String: Any], let list = dict["cards"] as? [Any] {
            rawItems = list
        } else {
            throw ImportError.invalidFormat
        }

        cards = rawItems.compactMap { item in
            guard let dict = item as? [String: Any] else { return nil }
            let cashbackParts = [Self.string(dict, ["cashback"]), Self.string(dict, ["cashbackType"]), Self.string(dict, ["cashbackRate"]), Self.string(dict, ["campaignName"])].filter { !$0.isEmpty }
            let id = Self.string(dict, ["id"])
            return CreditCard(
                id: id.isEmpty ? UUID().uuidString : id,
                bank: Self.string(dict, ["bank", "bankName", "issuer"]),
                name: Self.string(dict, ["name", "cardName", "card_name", "title"]),
                last4: Self.string(dict, ["last4", "tail", "tailNumber"]),
                statementDay: Self.string(dict, ["statementDay", "statement", "billDay"]),
                paymentDay: Self.string(dict, ["paymentDay", "payment", "dueDay"]),
                cashback: cashbackParts.joined(separator: " / "),
                notes: Self.string(dict, ["notes", "remark", "memo", "replacement"])
            )
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cards) { UserDefaults.standard.set(data, forKey: key) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([CreditCard].self, from: data) else { return }
        cards = decoded
    }

    private static func string(_ dict: [String: Any], _ keys: [String]) -> String {
        for key in keys {
            if let value = dict[key] as? String { return value }
            if let value = dict[key] as? Int { return String(value) }
            if let value = dict[key] as? Double { return String(Int(value)) }
        }
        return ""
    }

    private enum ImportError: Error { case invalidText, invalidFormat }
}

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        tabBar.tintColor = .brand
        tabBar.backgroundColor = .systemBackground
        let archive = makeTab(ArchiveViewController(), title: "档案", icon: "creditcard")
        let reminders = makeTab(ReminderViewController(), title: "提醒", icon: "bell.badge")
        let data = makeTab(DataViewController(), title: "数据", icon: "doc.text")
        viewControllers = [archive, reminders, data]
    }

    private func makeTab(_ root: UIViewController, title: String, icon: String) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.prefersLargeTitles = true
        nav.navigationBar.tintColor = .brand
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), tag: 0)
        return nav
    }
}

final class ArchiveViewController: UITableViewController {
    private var cards: [CreditCard] { CardStore.shared.cards }

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "信用卡档案"
        tableView.backgroundColor = .appBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 112
        tableView.register(CardCell.self, forCellReuseIdentifier: "CardCell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.tableHeaderView = ArchiveHeaderView(cards: cards)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(cards.count, 1) }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if cards.isEmpty {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = "暂无卡片"
            cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
            cell.detailTextLabel?.text = "点右上角 + 新增，或到“数据”页粘贴 JSON 导入。"
            cell.detailTextLabel?.numberOfLines = 2
            cell.selectionStyle = .none
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "CardCell", for: indexPath) as! CardCell
        cell.configure(cards[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !cards.isEmpty else { return }
        showForm(cards[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, !cards.isEmpty else { return }
        CardStore.shared.delete(at: indexPath.row)
        tableView.tableHeaderView = ArchiveHeaderView(cards: cards)
        tableView.reloadData()
    }

    @objc private func addCard() { showForm(nil) }

    private func showForm(_ card: CreditCard?) {
        let controller = CardFormViewController(card: card)
        present(UINavigationController(rootViewController: controller), animated: true)
    }
}

final class ArchiveHeaderView: UIView {
    init(cards: [CreditCard]) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 172))
        backgroundColor = .clear
        let panel = UIView()
        panel.backgroundColor = .brand
        panel.layer.cornerRadius = 18
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        let title = UILabel()
        title.text = "今日用卡概览"
        title.textColor = .white.withAlphaComponent(0.85)
        title.font = .preferredFont(forTextStyle: .subheadline)
        title.translatesAutoresizingMaskIntoConstraints = false

        let count = UILabel()
        count.text = "\(cards.count) 张卡"
        count.textColor = .white
        count.font = .systemFont(ofSize: 32, weight: .bold)
        count.translatesAutoresizingMaskIntoConstraints = false

        let cashback = cards.filter { !$0.cashback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let next = nextReminderCount(cards)
        let stats = UIStackView(arrangedSubviews: [stat("返利卡", "\(cashback)"), stat("7天提醒", "\(next)"), stat("数据", "本机")])
        stats.axis = .horizontal
        stats.distribution = .fillEqually
        stats.spacing = 8
        stats.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(title)
        panel.addSubview(count)
        panel.addSubview(stats)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            count.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            count.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stats.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stats.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stats.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
            stats.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func stat(_ name: String, _ value: String) -> UIView {
        let box = UIView()
        box.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        box.layer.cornerRadius = 12
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.textColor = .white.withAlphaComponent(0.78)
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        let stack = UIStackView(arrangedSubviews: [valueLabel, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: box.centerXAnchor), stack.centerYAnchor.constraint(equalTo: box.centerYAnchor)])
        return box
    }
}

final class CardCell: UITableViewCell {
    private let cardView = UIView()
    private let bank = UILabel()
    private let name = UILabel()
    private let line = UILabel()
    private let chip = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        bank.font = .systemFont(ofSize: 20, weight: .semibold)
        name.font = .preferredFont(forTextStyle: .subheadline)
        name.textColor = .secondaryLabel
        line.font = .preferredFont(forTextStyle: .footnote)
        line.textColor = .secondaryLabel
        line.numberOfLines = 2
        chip.font = .systemFont(ofSize: 12, weight: .semibold)
        chip.textAlignment = .center
        chip.layer.cornerRadius = 10
        chip.layer.masksToBounds = true
        chip.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [bank, name, line])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        cardView.addSubview(chip)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: chip.leadingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            chip.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            chip.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chip.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            chip.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ card: CreditCard) {
        bank.text = card.bank.isEmpty ? "未填写银行" : card.bank
        let cardName = card.name.isEmpty ? "未命名卡片" : card.name
        let tail = card.last4.isEmpty ? "未填" : card.last4
        name.text = "\(cardName) · 尾号 \(tail)"
        let cashback = card.cashback.isEmpty ? "未设置返利" : "返利: \(card.cashback)"
        line.text = "账单 \(label(card.statementDay)) · 还款 \(label(card.paymentDay))\n\(cashback)"
        chip.text = card.cashback.isEmpty ? "档案" : "返利"
        chip.textColor = card.cashback.isEmpty ? .secondaryLabel : .brand
        chip.backgroundColor = card.cashback.isEmpty ? UIColor.secondarySystemBackground : UIColor.brand.withAlphaComponent(0.12)
    }

    private func label(_ value: String) -> String { value.isEmpty ? "未设" : value }
}

final class CardFormViewController: UIViewController {
    private let editingCard: CreditCard?
    private let bank = UITextField()
    private let name = UITextField()
    private let last4 = UITextField()
    private let statementDay = UITextField()
    private let paymentDay = UITextField()
    private let cashback = UITextField()
    private let notes = UITextView()

    init(card: CreditCard?) { editingCard = card; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = editingCard == nil ? "新增卡片" : "编辑卡片"
        view.backgroundColor = .appBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        [field(bank, "银行，例如 中信银行"), field(name, "卡名，例如 VISA Signature"), field(last4, "尾号", keyboard: .numberPad), field(statementDay, "账单日", keyboard: .numberPad), field(paymentDay, "还款日", keyboard: .numberPad), field(cashback, "返利/活动，例如 Visa境外返现")].forEach(stack.addArrangedSubview)
        notes.layer.borderColor = UIColor.separator.cgColor
        notes.layer.borderWidth = 1
        notes.layer.cornerRadius = 10
        notes.font = .preferredFont(forTextStyle: .body)
        notes.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(notes)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16), stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16), stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16), stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32)
        ])
        fill()
    }

    private func field(_ textField: UITextField, _ placeholder: String, keyboard: UIKeyboardType = .default) -> UITextField {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.keyboardType = keyboard
        textField.clearButtonMode = .whileEditing
        return textField
    }

    private func fill() {
        guard let card = editingCard else { notes.text = ""; return }
        bank.text = card.bank; name.text = card.name; last4.text = card.last4; statementDay.text = card.statementDay; paymentDay.text = card.paymentDay; cashback.text = card.cashback; notes.text = card.notes
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func save() {
        CardStore.shared.upsert(CreditCard(id: editingCard?.id ?? UUID().uuidString, bank: bank.text ?? "", name: name.text ?? "", last4: last4.text ?? "", statementDay: statementDay.text ?? "", paymentDay: paymentDay.text ?? "", cashback: cashback.text ?? "", notes: notes.text ?? ""))
        dismiss(animated: true)
    }
}

final class ReminderViewController: UITableViewController {
    private var items: [(String, String, Date)] = []
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); title = "提醒"; tableView.backgroundColor = .appBackground }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        items = CardStore.shared.cards.flatMap { card in
            var output: [(String, String, Date)] = []
            if let date = nextDate(card.statementDay) { output.append(("\(card.bank) 账单日", detail(date), date)) }
            if let date = nextDate(card.paymentDay) { output.append(("\(card.bank) 还款日", detail(date), date)) }
            return output
        }.sorted { $0.2 < $1.2 }
        tableView.reloadData()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(items.count, 1) }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if items.isEmpty { cell.textLabel?.text = "暂无提醒"; cell.detailTextLabel?.text = "填写账单日或还款日后会出现在这里。" } else { let item = items[indexPath.row]; cell.textLabel?.text = item.0; cell.detailTextLabel?.text = item.1 }
        cell.detailTextLabel?.numberOfLines = 2
        cell.selectionStyle = .none
        return cell
    }
}

final class DataViewController: UIViewController {
    private let textView = UITextView()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "数据"
        view.backgroundColor = .appBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "导出", style: .plain, target: self, action: #selector(exportData))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导入", style: .done, target: self, action: #selector(importData))
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 12
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)])
        exportData()
    }
    @objc private func exportData() { textView.text = CardStore.shared.exportText(); UIPasteboard.general.string = textView.text }
    @objc private func importData() {
        do {
            try CardStore.shared.importText(textView.text)
            let alert = UIAlertController(title: "导入成功", message: "已导入 \(CardStore.shared.cards.count) 张卡。点“好”后回到档案。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { _ in self.tabBarController?.selectedIndex = 0 })
            present(alert, animated: true)
        } catch { showAlert("导入失败", "JSON 格式不对，或没有 cards 数组。") }
    }
    private func showAlert(_ title: String, _ message: String) { let alert = UIAlertController(title: title, message: message, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "好", style: .default)); present(alert, animated: true) }
}

private func nextDate(_ dayText: String) -> Date? {
    guard let day = Int(dayText), day >= 1 else { return nil }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var comps = calendar.dateComponents([.year, .month], from: today)
    comps.day = min(day, 28)
    var date = calendar.date(from: comps)
    if let current = date, current < today { comps.month = (comps.month ?? 1) + 1; date = calendar.date(from: comps) }
    return date
}

private func daysUntil(_ date: Date) -> Int { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: date).day ?? 0 }
private func format(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "M月d日"; return formatter.string(from: date) }
private func detail(_ date: Date) -> String { "\(format(date)) · \(daysUntil(date))天后 · 默认提前2天10:00提醒" }
private func nextReminderCount(_ cards: [CreditCard]) -> Int { cards.flatMap { [nextDate($0.statementDay), nextDate($0.paymentDay)] }.compactMap { $0 }.filter { daysUntil($0) <= 7 }.count }

extension UIColor {
    static let brand = UIColor(red: 0.04, green: 0.48, blue: 0.43, alpha: 1)
    static let appBackground = UIColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1)
}
