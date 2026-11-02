import UIKit

/// 桌面上的应用
enum DeckApp: String, CaseIterable {
    case notes, browser, files, calculator, terminal, clock, snake

    var title: String {
        switch self {
        case .notes:      return "笔记"
        case .browser:    return "浏览器"
        case .files:      return "文件"
        case .calculator: return "计算器"
        case .terminal:   return "终端"
        case .clock:      return "时钟"
        case .snake:      return "贪吃蛇"
        }
    }

    var symbol: String {
        switch self {
        case .notes:      return "note.text"
        case .browser:    return "safari"
        case .files:      return "folder"
        case .calculator: return "plus.forwardslash.minus"
        case .terminal:   return "terminal"
        case .clock:      return "clock"
        case .snake:      return "gamecontroller.fill"
        }
    }

    var tint: UIColor {
        switch self {
        case .notes:      return UIColor(red: 0.96, green: 0.72, blue: 0.26, alpha: 1)
        case .browser:    return UIColor(red: 0.36, green: 0.56, blue: 1.00, alpha: 1)
        case .files:      return UIColor(red: 0.42, green: 0.66, blue: 0.98, alpha: 1)
        case .calculator: return UIColor(red: 0.55, green: 0.60, blue: 0.70, alpha: 1)
        case .terminal:   return UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1)
        case .clock:      return UIColor(red: 0.50, green: 0.55, blue: 0.64, alpha: 1)
        case .snake:      return UIColor(red: 0.30, green: 0.88, blue: 0.60, alpha: 1)
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .notes:      return CGSize(width: 720, height: 480)
        case .browser:    return CGSize(width: 920, height: 600)
        case .files:      return CGSize(width: 660, height: 460)
        case .calculator: return CGSize(width: 360, height: 470)
        case .terminal:   return CGSize(width: 720, height: 420)
        case .clock:      return CGSize(width: 420, height: 260)
        case .snake:      return CGSize(width: 760, height: 560)
        }
    }
}

/// 手柄指令
enum GameCommand {
    case up
    case down
    case left
    case right
    case action
}

struct DeckWindow: Identifiable {
    let id = UUID()
    var app: DeckApp
    var frame: CGRect
    var isMinimized = false
    var isMaximized = false
    var docID: UUID?
    var savedFrame: CGRect?
    var url: String?
}
