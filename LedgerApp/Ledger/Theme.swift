import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0B0D12)
    static let card = Color(hex: 0x161A22)
    static let card2 = Color(hex: 0x1E2430)
    static let accent = Color(hex: 0x5B8CFF)
    static let green = Color(hex: 0x4DD08A)
    static let red = Color(hex: 0xFF6B6B)
    static let text = Color.white
    static let sub = Color.white.opacity(0.55)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: 1.0)
    }
}

func money(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    if value == value.rounded() {
        formatter.minimumFractionDigits = 0
    } else {
        formatter.minimumFractionDigits = 2
    }
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

func monthTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy 年 M 月"
    return formatter.string(from: date)
}

func dayTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M 月 d 日 EEEE"
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter.string(from: date)
}
