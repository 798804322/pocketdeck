import UIKit

extension Notification.Name {
    static let deckChanged = Notification.Name("deck.changed")
}

/// 桌面上的应用
enum DeckApp: String, CaseIterable {
    case notes, web, clock

    var title: String {
        switch self {
        case .notes: return "笔记"
        case .web:   return "浏览器"
        case .clock: return "时钟"
        }
    }

    var symbol: String {
        switch self {
        case .notes: return "note.text"
        case .web:   return "safari"
        case .clock: return "clock"
        }
    }

    var tint: UIColor {
        switch self {
        case .notes: return UIColor(red: 0.96, green: 0.72, blue: 0.26, alpha: 1)
        case .web:   return UIColor(red: 0.36, green: 0.56, blue: 1.00, alpha: 1)
        case .clock: return UIColor(red: 0.50, green: 0.55, blue: 0.64, alpha: 1)
        }
    }
}

struct DeckWindow: Identifiable {
    let id = UUID()
    var app: DeckApp
    var frame: CGRect
}

/// 整个 App 共享的唯一状态：手机端写入，外接屏读取渲染。
final class DeckModel {

    static let shared = DeckModel()

    let menuBarHeight: CGFloat = 40
    let dockItemSize: CGFloat = 66
    let dockGap: CGFloat = 14
    let dockPadding: CGFloat = 14
    let dockBottomInset: CGFloat = 30

    private(set) var screenSize = CGSize(width: 1920, height: 1080)
    private(set) var windows: [DeckWindow] = []
    private(set) var focusID: UUID?
    private(set) var connected = false

    var cursor = CGPoint(x: 960, y: 540)
    var notesText = "用手机滑动移动光标，轻点一下就是单击。\n\n点手机上的「键盘」，敲的字会出现在这里。"
    var webURL = "https://www.apple.com.cn"
    var dragMode = false

    private init() {}

    // MARK: - 屏幕

    func reportScreen(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let changed = abs(size.width - screenSize.width) > 2 || abs(size.height - screenSize.height) > 2
        if !changed && connected { return }
        screenSize = size
        connected = true
        if changed || windows.isEmpty {
            cursor = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
            if windows.isEmpty {
                open(.notes, silent: true)
            } else {
                windows = windows.map { var w = $0; w.frame = clamped(w.frame); return w }
            }
        }
        post()
    }

    func reportDisconnect() {
        connected = false
        post()
    }

    private func post() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .deckChanged, object: nil)
        } else {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .deckChanged, object: nil) }
        }
    }

    // MARK: - 光标 / 拖动

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        if dragMode, let id = focusID, let idx = windows.firstIndex(where: { $0.id == id }) {
            var f = windows[idx].frame
            f.origin.x += dx
            f.origin.y += dy
            windows[idx].frame = clamped(f)
        }
        let nx = cursor.x + dx
        let ny = cursor.y + dy
        cursor = CGPoint(x: min(max(0, nx), max(0, screenSize.width - 3)),
                         y: min(max(menuBarHeight, ny), max(menuBarHeight, screenSize.height - 3)))
        post()
    }

    // MARK: - 单击

    func click() {
        let p = cursor

        // 程序坞在视觉上永远压在窗口上面，所以先判 dock
        for (index, app) in DeckApp.allCases.enumerated() {
            if dockFrame(index).contains(p) {
                open(app)
                return
            }
        }

        for win in Array(windows.reversed()) {
            guard win.frame.contains(p), let idx = windows.firstIndex(where: { $0.id == win.id }) else { continue }
            let closeRect = CGRect(x: win.frame.minX + 8, y: win.frame.minY + 4, width: 44, height: 40)
            if closeRect.contains(p) {
                windows.remove(at: idx)
                if focusID == win.id { focusID = nil }
                post()
                return
            }
            focusID = win.id
            if p.y < win.frame.minY + 48 {
                windows.append(windows.remove(at: idx))
            }
            post()
            return
        }
    }

    // MARK: - 程序坞

    func dockTotalWidth() -> CGFloat {
        let n = CGFloat(DeckApp.allCases.count)
        return n * dockItemSize + (n - 1) * dockGap
    }

    func dockFrame(_ index: Int) -> CGRect {
        let total = dockTotalWidth()
        let left = (screenSize.width - total) / 2 + CGFloat(index) * (dockItemSize + dockGap)
        let top = screenSize.height - dockBottomInset - dockItemSize
        return CGRect(x: left, y: top, width: dockItemSize, height: dockItemSize)
    }

    func dockBackgroundFrame() -> CGRect {
        let total = dockTotalWidth()
        let top = screenSize.height - dockBottomInset - dockItemSize
        return CGRect(x: (screenSize.width - total) / 2 - dockPadding,
                      y: top - dockPadding,
                      width: total + dockPadding * 2,
                      height: dockItemSize + dockPadding * 2)
    }

    // MARK: - 窗口

    func open(_ app: DeckApp, silent: Bool = false) {
        if let idx = windows.firstIndex(where: { $0.app == app }) {
            focusID = windows[idx].id
            windows.append(windows.remove(at: idx))
            if !silent { post() }
            return
        }

        let w = screenSize.width
        let h = screenSize.height
        let width = min(820, max(430, w * 0.52))
        let height = min(560, max(300, h * 0.56))
        let step = CGFloat(windows.count % 4)
        let x = min(max(24, w * 0.10 + step * 38), max(24, w - width - 24))
        let y = min(max(menuBarHeight + 28, menuBarHeight + 44 + step * 32), max(menuBarHeight + 28, h - height - 130))

        let win = DeckWindow(app: app,
                             frame: CGRect(x: x, y: y, width: width, height: height))
        windows.append(win)
        focusID = win.id
        if !silent { post() }
    }

    func closeAll() {
        windows.removeAll()
        focusID = nil
        post()
    }

    func remove(_ id: UUID) {
        windows.removeAll { $0.id == id }
        if focusID == id { focusID = nil }
        post()
    }

    // MARK: - 键盘

    func type(_ text: String) {
        guard !text.isEmpty else { return }
        if !windows.contains(where: { $0.app == .notes }) { open(.notes) }
        notesText += text
        post()
    }

    func backspace() {
        if !notesText.isEmpty { notesText.removeLast() }
        post()
    }

    func newline() {
        notesText += "\n"
        post()
    }

    // MARK: - 工具

    private func clamped(_ rect: CGRect) -> CGRect {
        var f = rect
        f.origin.x = min(max(-f.width * 0.3, f.origin.x), max(0, screenSize.width - 90))
        f.origin.y = min(max(menuBarHeight + 2, f.origin.y), max(menuBarHeight + 2, screenSize.height - 90))
        return f
    }
}
