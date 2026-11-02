import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var budgetText = ""
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var showClear = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        budgetCard
                        dataCard
                        aboutCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .alert(isPresented: $showClear) {
                Alert(title: Text("清空全部记录？"),
                      message: Text("这会删掉本机所有账目，不能恢复。"),
                      primaryButton: .destructive(Text("清空")) {
                          store.clearAll()
                      },
                      secondaryButton: .cancel(Text("取消")))
            }
            .onAppear {
                if store.monthlyBudget > 0 {
                    budgetText = String(Int(store.monthlyBudget))
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每月预算")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("¥")
                        .foregroundColor(Theme.sub)
                    TextField("不设限制", text: $budgetText)
                        .keyboardType(.numberPad)
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.card2)
                .cornerRadius(10)

                Button {
                    saveBudget()
                } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .cornerRadius(10)
                }
            }
            Text("设了预算后，首页会显示进度条；填 0 表示不设。")
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
        }
        .padding(16)
        .card()
    }

    private var dataCard: some View {
        VStack(spacing: 0) {
            Button {
                exportCSV()
            } label: {
                settingRow(icon: "square.and.arrow.up",
                           title: "导出 CSV",
                           subtitle: "可以发到微信或用 Excel 打开",
                           color: Theme.accent)
            }
            Divider().background(Theme.card2).padding(.leading, 52)
            Button {
                showClear = true
            } label: {
                settingRow(icon: "trash",
                           title: "清空数据",
                           subtitle: "共 \(store.entries.count) 条记录",
                           color: Theme.red)
            }
        }
        .card()
    }

    private func settingRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.sub)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.sub.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("账本 1.0")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("数据只存在这台手机的本地文件里，不上传、不联网、不需要账号。")
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
            Text("删除 App 会一起删掉数据，重要账目请先导出 CSV。")
                .font(.system(size: 11))
                .foregroundColor(Theme.red.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card()
    }

    private func saveBudget() {
        let value = Double(budgetText.trimmingCharacters(in: .whitespaces)) ?? 0
        store.monthlyBudget = max(0, value)
        budgetText = value > 0 ? String(Int(value)) : ""
    }

    private func exportCSV() {
        shareURL = store.exportCSV()
        showShare = shareURL != nil
    }
}
