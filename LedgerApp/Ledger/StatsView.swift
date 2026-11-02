import SwiftUI
import Foundation

struct StatsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var month = Date()

    private var total: Double {
        store.total(in: month)
    }

    private var rows: [CategoryTotal] {
        store.byCategory(in: month)
    }

    private var lastSixMonths: [Date] {
        let calendar = Calendar.current
        var list: [Date] = []
        for offset in stride(from: 5, through: 0, by: -1) {
            if let date = calendar.date(byAdding: .month, value: -offset, to: Date()) {
                list.append(date)
            }
        }
        return list
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        monthHeader
                        totalCard
                        categoryCard
                        trendCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.sub)
                    .frame(width: 36, height: 36)
                    .background(Theme.card)
                    .cornerRadius(10)
            }
            Spacer()
            Text(monthTitle(month))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
            Spacer()
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.sub)
                    .frame(width: 36, height: 36)
                    .background(Theme.card)
                    .cornerRadius(10)
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("支出合计")
                .font(.system(size: 12))
                .foregroundColor(Theme.sub)
            Text("¥" + money(total))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
            Text("收入 ¥\(money(store.income(in: month))) · 共 \(store.entries(in: month).count) 笔")
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类占比")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)

            if rows.isEmpty {
                Text("这个月还没有支出")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.sub)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(rows) { item in
                    categoryRow(item.category, item.amount)
                }
            }
        }
        .padding(16)
        .card()
    }

    private func categoryRow(_ category: LedgerCategory, _ amount: Double) -> some View {
        let ratio = total > 0 ? amount / total : 0
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("¥" + money(amount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.text)
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.sub)
                    .frame(width: 34, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.card2)
                        .frame(height: 6)
                    Capsule()
                        .fill(category.color)
                        .frame(width: max(4, geo.size.width * CGFloat(ratio)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近 6 个月")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(lastSixMonths, id: \.self) { date in
                    trendBar(date)
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .card()
    }

    private func trendBar(_ date: Date) -> some View {
        let value = store.total(in: date)
        let maxValue = maxValueOfSixMonths
        let height = max(3, CGFloat(value / maxValue) * 70)
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(value > 0 ? money(value) : "")
                .font(.system(size: 9))
                .foregroundColor(Theme.sub)
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.accent.opacity(0.85))
                .frame(height: height)
            Text(formatter.string(from: date))
                .font(.system(size: 9))
                .foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private var maxValueOfSixMonths: Double {
        let values = lastSixMonths.map { store.total(in: $0) }
        return max(1, values.max() ?? 1)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = next
        }
    }
}
