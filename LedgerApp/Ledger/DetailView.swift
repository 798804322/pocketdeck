import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    summaryCard
                    entryList
                }
            }
            .navigationTitle("账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEntryView().environmentObject(store)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 顶部汇总

    private var spent: Double {
        store.total(in: Date())
    }

    private var budgetRatio: Double {
        guard store.monthlyBudget > 0 else { return 0 }
        return min(1.0, spent / store.monthlyBudget)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本月支出")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.sub)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.sub)
                Text(money(spent))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
            }
            if store.monthlyBudget > 0 {
                budgetBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var budgetBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.card2)
                        .frame(height: 8)
                    Capsule()
                        .fill(budgetRatio >= 1 ? Theme.red : Theme.accent)
                        .frame(width: max(8, geo.size.width * CGFloat(budgetRatio)), height: 8)
                }
            }
            .frame(height: 8)

            Text("预算 ¥\(money(store.monthlyBudget)) · 剩余 ¥\(money(max(0, store.monthlyBudget - spent)))")
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
        }
    }

    // MARK: - 明细

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [Entry]
        let total: Double
        var id: Date { day }
    }

    private var groupedDays: [DayGroup] {
        let calendar = Calendar.current
        var order: [Date] = []
        var map: [Date: [Entry]] = [:]

        for entry in store.entries {
            let day = calendar.startOfDay(for: entry.date)
            if map[day] == nil { order.append(day) }
            map[day, default: []].append(entry)
        }

        return order.map { day in
            let list = map[day] ?? []
            let total = list.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            return DayGroup(day: day, entries: list, total: total)
        }
    }

    private var entryList: some View {
        ScrollView {
            if store.entries.isEmpty {
                emptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groupedDays) { group in
                        daySection(group)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(Theme.sub)
            Text("还没有记录")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.sub)
            Text("点右上角的 + 记第一笔")
                .font(.system(size: 12))
                .foregroundColor(Theme.sub.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    private func daySection(_ group: DayGroup) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(dayTitle(group.day))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.sub)
                Spacer()
                Text("支出 ¥\(money(group.total))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.sub)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(group.entries) { entry in
                row(entry)
            }
        }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.cat.color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: entry.cat.icon)
                    .font(.system(size: 15))
                    .foregroundColor(entry.cat.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note.isEmpty ? entry.category : entry.note)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(entry.category)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.sub)
            }

            Spacer()

            Text((entry.isIncome ? "+ ¥" : "- ¥") + money(entry.amount))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(entry.isIncome ? Theme.green : Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card)
        .cornerRadius(12)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .contextMenu {
            Button {
                store.delete(id: entry.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
