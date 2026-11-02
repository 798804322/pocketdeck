import Foundation
import SwiftUI

/// 记账分类
enum LedgerCategory: String, CaseIterable, Codable, Identifiable {
    case food = "餐饮"
    case transport = "交通"
    case material = "材料"
    case fuel = "加油"
    case shopping = "购物"
    case fun = "娱乐"
    case home = "居家"
    case medical = "医疗"
    case social = "人情"
    case other = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .material: return "shippingbox.fill"
        case .fuel: return "fuelpump.fill"
        case .shopping: return "bag.fill"
        case .fun: return "gamecontroller.fill"
        case .home: return "house.fill"
        case .medical: return "cross.case.fill"
        case .social: return "gift.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return Color(hex: 0xFF8A65)
        case .transport: return Color(hex: 0x4FC3F7)
        case .material: return Color(hex: 0xFFD54F)
        case .fuel: return Color(hex: 0xBA68C8)
        case .shopping: return Color(hex: 0xF06292)
        case .fun: return Color(hex: 0x4DB6AC)
        case .home: return Color(hex: 0x9575CD)
        case .medical: return Color(hex: 0xE57373)
        case .social: return Color(hex: 0xA1887F)
        case .other: return Color(hex: 0x90A4AE)
        }
    }
}

struct CategoryTotal: Identifiable {
    let category: LedgerCategory
    let amount: Double
    var id: String { category.rawValue }
}

struct Entry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Double = 0
    var category: String = LedgerCategory.other.rawValue
    var note: String = ""
    var isIncome: Bool = false

    var cat: LedgerCategory {
        LedgerCategory(rawValue: category) ?? .other
    }
}

final class LedgerStore: ObservableObject {
    static let shared = LedgerStore()

    @Published private(set) var entries: [Entry] = []

    @Published var monthlyBudget: Double {
        didSet {
            UserDefaults.standard.set(monthlyBudget, forKey: "ledger.budget")
        }
    }

    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("ledger.json")
        monthlyBudget = UserDefaults.standard.double(forKey: "ledger.budget")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = list.sorted { $0.date > $1.date }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ entry: Entry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persist()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        entries = []
        persist()
    }

    // MARK: - 统计

    func entries(in month: Date) -> [Entry] {
        let calendar = Calendar.current
        let target = calendar.dateComponents([.year, .month], from: month)
        return entries.filter { entry in
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            return comps.year == target.year && comps.month == target.month
        }
    }

    func total(in month: Date) -> Double {
        entries(in: month).filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    func income(in month: Date) -> Double {
        entries(in: month).filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    func byCategory(in month: Date) -> [CategoryTotal] {
        var map: [LedgerCategory: Double] = [:]
        for entry in entries(in: month) where !entry.isIncome {
            map[entry.cat, default: 0] += entry.amount
        }
        return map.map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    func exportCSV() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var csv = "日期,类型,分类,金额,备注\n"
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let kind = entry.isIncome ? "收入" : "支出"
            csv += "\(formatter.string(from: entry.date)),\(kind),\(entry.category),\(entry.amount),\"\(entry.note)\"\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("账本.csv")
        try? csv.data(using: .utf8)?.write(to: url)
        return url
    }
}
