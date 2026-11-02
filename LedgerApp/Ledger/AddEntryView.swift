import SwiftUI

struct AddEntryView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = "0"
    @State private var category: LedgerCategory = .food
    @State private var note = ""
    @State private var isIncome = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    private let keyRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    private var amountValue: Double {
        Double(amountText) ?? 0
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                amountArea
                categoryGrid
                noteField
                keypad
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }

    private var topBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .foregroundColor(Theme.sub)
            Spacer()
            Picker("", selection: $isIncome) {
                Text("支出").tag(false)
                Text("收入").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 140)
            Spacer()
            Text(" ").frame(width: 32)
        }
    }

    private var amountArea: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("¥")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Theme.sub)
            Text(amountText)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundColor(isIncome ? Theme.green : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LedgerCategory.allCases) { item in
                categoryCell(item)
            }
        }
    }

    private func categoryCell(_ item: LedgerCategory) -> some View {
        let selected = item == category
        return Button {
            category = item
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                Text(item.rawValue)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? item.color.opacity(0.22) : Theme.card)
            .foregroundColor(selected ? item.color : Theme.sub)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var noteField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .foregroundColor(Theme.sub)
                .font(.system(size: 13))
            TextField("备注（可选）", text: $note)
                .foregroundColor(Theme.text)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.card)
        .cornerRadius(12)
    }

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(keyRows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            appendKey(key)
        } label: {
            Text(key)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(key == "⌫" ? Theme.red : Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.card2)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(amountValue > 0 ? Theme.accent : Theme.card2)
                .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(amountValue <= 0)
    }

    private func appendKey(_ key: String) {
        switch key {
        case "⌫":
            if amountText.count <= 1 {
                amountText = "0"
            } else {
                amountText.removeLast()
            }
        case ".":
            if !amountText.contains(".") {
                amountText += "."
            }
        default:
            if amountText == "0" {
                amountText = key
            } else if amountText.count < 9 {
                amountText += key
            }
        }
    }

    private func save() {
        guard amountValue > 0 else { return }
        let entry = Entry(date: Date(),
                          amount: amountValue,
                          category: category.rawValue,
                          note: note,
                          isIncome: isIncome)
        store.add(entry)
        dismiss()
    }
}
