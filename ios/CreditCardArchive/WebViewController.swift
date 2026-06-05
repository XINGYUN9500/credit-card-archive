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

struct CardEnvelope: Codable {
    var cards: [CreditCard]
}

final class CardStore {
    static let shared = CardStore()
    private let key = "credit-card-archive-native-ios-v1"
    private(set) var cards: [CreditCard] = []

    private init() { load() }

    func upsert(_ card: CreditCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
        save()
    }

    func delete(at index: Int) {
        cards.remove(at: index)
        save()
    }

    func replaceAll(_ newCards: [CreditCard]) {
        cards = newCards
        save()
    }

    func exportText() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(CardEnvelope(cards: cards)), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "{\n  \"cards\": []\n}"
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
        let imported = rawItems.compactMap { item -> CreditCard? in
            guard let dict = item as? [String: Any] else { return nil }
            let bank = string(dict, ["bank", "bankName", "issuer"])
            let name = string(dict, ["name", "cardName", "card_name", "title"])
            let last4 = string(dict, ["last4", "tail", "tailNumber"])
            let statement = string(dict, ["statementDay", "statement", "billDay"])
            let payment = string(dict, ["paymentDay", "payment", "dueDay"])
            let cashbackParts = [
                string(dict, ["cashback"]),
                string(dict, ["cashbackType"]),
                string(dict, ["cashbackRate"]),
                string(dict, ["campaignName"])
            ].filter { !$0.isEmpty }
            let cashback = Array(Set(cashbackParts)).joined(separator: " / ")
            let notes = string(dict, ["notes", "remark", "memo", "replacement"])
            return CreditCard(
                id: string(dict, ["id"]).isEmpty ? UUID().uuidString : string(dict, ["id"]),
                bank: bank,
                name: name,
                last4: last4,
                statementDay: statement,
                paymentDay: payment,
                cashback: cashback,
                notes: notes
            )
        }
        replaceAll(imported)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
        viewControllers = [
            UINavigationController(rootViewController: ArchiveViewController()),
            UINavigationController(rootViewController: ReminderViewController()),
            UINavigationController(rootViewController: DataViewController())
        ]
    }
}

final class ArchiveViewController: UITableViewController {
    private var cards: [CreditCard] { CardStore.shared.cards }

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "档案"
        tabBarItem = UITabBarItem(title: "档案", image: UIImage(systemName: "creditcard"), tag: 0)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(cards.count, 1) }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if cards.isEmpty {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = "暂无卡片"
            cell.detailTextLabel?.text = "点右上角 + 新增，或到“数据”页粘贴 JSON 导入。"
            cell.selectionStyle = .none
            return cell
        }
        let card = cards[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = card.bank.isEmpty ? "未填写银行" : card.bank
        let cashback = card.cashback.isEmpty ? "未设置返利" : "返利: \(card.cashback)"
        cell.detailTextLabel?.numberOfLines = 3
        cell.detailTextLabel?.text = "\(card.name.isEmpty ? "未命名" : card.name) · 尾号 \(card.last4.isEmpty ? "未填" : card.last4)\n账单 \(card.statementDay.isEmpty ? "未设" : card.statementDay) · 还款 \(card.paymentDay.isEmpty ? "未设" : card.paymentDay) · \(cashback)"
        cell.accessoryType = .disclosureIndicator
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
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    @objc private func addCard() { showForm(nil) }

    private func showForm(_ card: CreditCard?) {
        let controller = CardFormViewController(card: card)
        let nav = UINavigationController(rootViewController: controller)
        present(nav, animated: true)
    }
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

    init(card: CreditCard?) {
        self.editingCard = card
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = editingCard == nil ? "新增卡片" : "编辑卡片"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        [
            field(bank, "银行，例如 中信银行"),
            field(name, "卡名，例如 VISA Signature"),
            field(last4, "尾号", keyboard: .numberPad),
            field(statementDay, "账单日", keyboard: .numberPad),
            field(paymentDay, "还款日", keyboard: .numberPad),
            field(cashback, "返利/活动，例如 Visa境外返现")
        ].forEach(stack.addArrangedSubview)

        notes.layer.borderColor = UIColor.separator.cgColor
        notes.layer.borderWidth = 1
        notes.layer.cornerRadius = 8
        notes.font = .preferredFont(forTextStyle: .body)
        notes.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(notes)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32)
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
        guard let card = editingCard else { notes.text = "备注"; notes.textColor = .secondaryLabel; return }
        bank.text = card.bank
        name.text = card.name
        last4.text = card.last4
        statementDay.text = card.statementDay
        paymentDay.text = card.paymentDay
        cashback.text = card.cashback
        notes.text = card.notes
        notes.textColor = .label
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let card = CreditCard(
            id: editingCard?.id ?? UUID().uuidString,
            bank: bank.text ?? "",
            name: name.text ?? "",
            last4: last4.text ?? "",
            statementDay: statementDay.text ?? "",
            paymentDay: paymentDay.text ?? "",
            cashback: cashback.text ?? "",
            notes: notes.textColor == .secondaryLabel ? "" : notes.text
        )
        CardStore.shared.upsert(card)
        dismiss(animated: true)
    }
}

final class ReminderViewController: UITableViewController {
    private var items: [(String, String, Date)] = []

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "提醒"
        tabBarItem = UITabBarItem(title: "提醒", image: UIImage(systemName: "bell"), tag: 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
        tableView.reloadData()
    }

    private func rebuild() {
        items = CardStore.shared.cards.flatMap { card in
            var output: [(String, String, Date)] = []
            if let date = nextDate(card.statementDay) {
                output.append(("\(card.bank) 账单日", "\(format(date)) · \(daysUntil(date))天后 · 默认提前2天10:00提醒", date))
            }
            if let date = nextDate(card.paymentDay) {
                output.append(("\(card.bank) 还款日", "\(format(date)) · \(daysUntil(date))天后 · 默认提前2天10:00提醒", date))
            }
            return output
        }.sorted { $0.2 < $1.2 }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(items.count, 1) }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if items.isEmpty {
            cell.textLabel?.text = "暂无提醒"
            cell.detailTextLabel?.text = "填写账单日或还款日后会出现在这里。"
        } else {
            let item = items[indexPath.row]
            cell.textLabel?.text = item.0
            cell.detailTextLabel?.text = item.1
        }
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
        tabBarItem = UITabBarItem(title: "数据", image: UIImage(systemName: "doc.text"), tag: 2)
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "导出", style: .plain, target: self, action: #selector(exportData))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导入", style: .done, target: self, action: #selector(importData))
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
        exportData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        exportData()
    }

    @objc private func exportData() {
        textView.text = CardStore.shared.exportText()
        UIPasteboard.general.string = textView.text
    }

    @objc private func importData() {
        do {
            try CardStore.shared.importText(textView.text)
            showAlert("导入成功", "已导入 \(CardStore.shared.cards.count) 张卡。")
        } catch {
            showAlert("导入失败", "JSON 格式不对，或没有 cards 数组。")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

private func nextDate(_ dayText: String) -> Date? {
    guard let day = Int(dayText), day >= 1 else { return nil }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var comps = calendar.dateComponents([.year, .month], from: today)
    comps.day = min(day, 28)
    var date = calendar.date(from: comps)
    if let current = date, current < today {
        comps.month = (comps.month ?? 1) + 1
        date = calendar.date(from: comps)
    }
    return date
}

private func daysUntil(_ date: Date) -> Int {
    let today = Calendar.current.startOfDay(for: Date())
    return Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
}

private func format(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M月d日"
    return formatter.string(from: date)
}
