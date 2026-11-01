import UIKit

extension Notification.Name {
    static let deckChanged = Notification.Name("deck.changed")
}

/// 全局状态：窗口、光标、任务栏、输入路由
final class DeckModel {

    static let shared = DeckModel()

    let taskbarHeight: CGFloat = 46
    let titleBarHeight: CGFloat = 36

    private(set) var screenSize = CGSize(width: 1920, height: 1080)
    private(set) var windows: [DeckWindow] = []
    private(set) var focusID: UUID?
    private(set) var connected = false
    private(set) var externalSceneCreated = false
    private(set) var touchCount = 0

    var cursor = CGPoint(x: 960, y: 540)
    var startMenuOpen = false
    var dragWindowID: UUID?
    var resizeWindowID: UUID?
    /// 手机「点触」模式：直接点哪儿，大屏点哪儿
    var absoluteMode = false

    private var resizeStart: CGPoint = .zero
    private var resizeStartFrame: CGRect = .zero

    /// 输入路由：由当前获得焦点的内容视图注册
    var insertSink: ((String) -> Void)?
    var backspaceSink: (() -> Void)?
    var returnSink: (() -> Void)?
    var scrollSink: ((CGFloat) -> Void)?

    /// 点击分发：由桌面视图注册
    var contentTap: ((UUID, CGPoint) -> Void)?
    var contentFocus: ((UUID) -> Void)?

    private init() {}

    var workArea: CGRect {
        CGRect(x: 0, y: 0,
               width: screenSize.width,
               height: max(120, screenSize.height - taskbarHeight))
    }

    // MARK: - 屏幕

    func reportScreen(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let changed = abs(size.width - screenSize.width) > 2 || abs(size.height - screenSize.height) > 2
        if !changed && connected { return }
        screenSize = size
        connected = true
        if changed || windows.isEmpty {
            cursor = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
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

    func markExternalScene() {
        externalSceneCreated = true
        post()
    }

    func registerTouch() {
        touchCount += 1
        post()
    }

    private func post() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .deckChanged, object: nil)
        } else {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .deckChanged, object: nil) }
        }
    }

    // MARK: - 光标与按下

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        let target = CGPoint(x: min(max(0, cursor.x + dx), max(0, screenSize.width - 3)),
                             y: min(max(0, cursor.y + dy), max(0, screenSize.height - 3)))

        if let id = resizeWindowID, let index = windows.firstIndex(where: { $0.id == id }) {
            var frame = resizeStartFrame
            frame.size.width = max(300, resizeStartFrame.width + (target.x - resizeStart.x))
            frame.size.height = max(180, resizeStartFrame.height + (target.y - resizeStart.y))
            windows[index].frame = frame
        } else if let id = dragWindowID, let index = windows.firstIndex(where: { $0.id == id }) {
            var frame = windows[index].frame
            frame.origin.x += dx
            frame.origin.y += dy
            windows[index].frame = clamped(frame)
        }

        cursor = target
        post()
    }

    /// 绝对定位：手机点哪儿，大屏就到哪儿
    func moveCursorTo(_ point: CGPoint) {
        let target = CGPoint(x: min(max(0, point.x), max(0, screenSize.width - 3)),
                             y: min(max(0, point.y), max(0, screenSize.height - 3)))
        moveCursor(dx: target.x - cursor.x, dy: target.y - cursor.y)
    }

    /// 手指按下：标题栏 = 拖窗口，右下角 = 改大小
    func press() {
        dragWindowID = nil
        resizeWindowID = nil
        guard let win = windowAt(cursor), !win.isMinimized else { return }
        let localX = cursor.x - win.frame.minX
        let localY = cursor.y - win.frame.minY

        if !win.isMaximized,
           localX > win.frame.width - 26,
           localY > win.frame.height - 26 {
            focus(win.id)
            resizeWindowID = win.id
            resizeStart = cursor
            resizeStartFrame = win.frame
            return
        }

        if localY <= titleBarHeight, localY >= 0 {
            focus(win.id)
            dragWindowID = win.id
        }
    }

    func release() {
        if let id = dragWindowID { applySnap(id) }
        dragWindowID = nil
        resizeWindowID = nil
    }

    /// 拖到屏幕边缘自动分屏（左半 / 右半 / 铺满）
    private func applySnap(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        let area = workArea
        let frame = windows[index].frame
        var snapped: CGRect?

        if frame.minX <= 6 {
            snapped = CGRect(x: 0, y: 0, width: area.width / 2, height: area.height)
        } else if frame.maxX >= area.width - 6 {
            snapped = CGRect(x: area.width / 2, y: 0, width: area.width / 2, height: area.height)
        } else if frame.minY <= 4 {
            snapped = area.insetBy(dx: 4, dy: 4)
        }

        guard let target = snapped else { return }
        windows[index].isMaximized = target.width >= area.width - 10
        windows[index].frame = target
        post()
    }

    func windowAt(_ point: CGPoint) -> DeckWindow? {
        windows.reversed().first { !$0.isMinimized && $0.frame.contains(point) }
    }

    // MARK: - 单击

    func clickAt(_ point: CGPoint) {
        cursor = point
        click()
    }

    func click() {
        let p = cursor

        if startMenuOpen {
            for (index, app) in DeckApp.allCases.enumerated() where startMenuItemFrame(index).contains(p) {
                startMenuOpen = false
                open(app)
                return
            }
            for (index, web) in WebAppCatalog.all.enumerated() where startMenuWebFrame(index).contains(p) {
                startMenuOpen = false
                open(.browser, url: web.url, portrait: web.portrait)
                return
            }
            startMenuOpen = false
            post()
        }

        if taskbarFrame().contains(p) {
            if startButtonFrame().contains(p) {
                startMenuOpen.toggle()
                post()
                return
            }
            if showDesktopFrame().contains(p) {
                minimizeAll()
                return
            }
            for index in windows.indices where windowButtonFrame(index).contains(p) {
                let win = windows[index]
                if win.isMinimized {
                    restore(win.id)
                } else if focusID == win.id {
                    minimize(win.id)
                } else {
                    focus(win.id)
                }
                return
            }
            return
        }

        for win in Array(windows.reversed()) where !win.isMinimized {
            guard win.frame.contains(p), let index = windows.firstIndex(where: { $0.id == win.id }) else { continue }
            if closeButtonRect(win).contains(p) { close(win.id); return }
            if maximizeButtonRect(win).contains(p) { toggleMaximize(win.id); return }
            if minimizeButtonRect(win).contains(p) { minimize(win.id); return }

            let local = CGPoint(x: p.x - win.frame.minX, y: p.y - win.frame.minY)
            if local.y <= titleBarHeight {
                focus(win.id)
                post()
                return
            }
            focus(win.id)
            contentTap?(win.id, local)
            post()
            return
        }

        // 最后才是桌面图标（窗口永远压在上面）
        for (index, app) in DeckApp.allCases.enumerated() where desktopIconFrame(index).contains(p) {
            open(app)
            return
        }
    }

    // MARK: - 任务栏几何

    func taskbarFrame() -> CGRect {
        CGRect(x: 0, y: screenSize.height - taskbarHeight,
               width: screenSize.width, height: taskbarHeight)
    }

    func startButtonFrame() -> CGRect {
        CGRect(x: 8, y: taskbarFrame().minY + 6, width: 40, height: taskbarHeight - 12)
    }

    func showDesktopFrame() -> CGRect {
        CGRect(x: screenSize.width - 10, y: taskbarFrame().minY + 6, width: 8, height: taskbarHeight - 12)
    }

    func trayFrame() -> CGRect {
        CGRect(x: screenSize.width - 160, y: taskbarFrame().minY, width: 140, height: taskbarHeight)
    }

    func windowButtonFrame(_ index: Int) -> CGRect {
        guard index >= 0, index < windows.count else { return .zero }
        let start = startButtonFrame().maxX + 10
        let end = trayFrame().minX - 10
        let count = CGFloat(windows.count)
        let gap: CGFloat = 4
        let available = max(60, end - start)
        let width = min(180, max(40, (available - gap * max(0, count - 1)) / count))
        return CGRect(x: start + CGFloat(index) * (width + gap),
                      y: taskbarFrame().minY + 5,
                      width: width, height: taskbarHeight - 10)
    }

    /// 桌面图标（左侧一列）
    func desktopIconFrame(_ index: Int) -> CGRect {
        let width: CGFloat = 88
        let height: CGFloat = 92
        return CGRect(x: 16, y: 16 + CGFloat(index) * (height + 6), width: width, height: height)
    }

    // MARK: - 开始菜单

    func startMenuFrame() -> CGRect {
        let width: CGFloat = 380
        let webRows = ceil(Double(WebAppCatalog.all.count) / 4.0)
        let height = 44 + 2 * 94 + 30 + CGFloat(webRows) * 88 + 30
        let capped = min(height, max(240, workArea.height - 30))
        return CGRect(x: 8, y: taskbarFrame().minY - capped - 8, width: width, height: capped)
    }

    /// 内置应用（3 列）
    func startMenuItemFrame(_ index: Int) -> CGRect {
        let menu = startMenuFrame()
        let cell = CGSize(width: 106, height: 88)
        let x = menu.minX + 14 + CGFloat(index % 3) * (cell.width + 6)
        let y = menu.minY + 44 + CGFloat(index / 3) * (cell.height + 6)
        return CGRect(x: x, y: y, width: cell.width, height: cell.height)
    }

    /// 网页应用（4 列）
    func startMenuWebFrame(_ index: Int) -> CGRect {
        let menu = startMenuFrame()
        let cell = CGSize(width: 82, height: 86)
        let top = menu.minY + 44 + 2 * 94 + 30
        let x = menu.minX + 14 + CGFloat(index % 4) * (cell.width + 4)
        let y = top + CGFloat(index / 4) * (cell.height + 2)
        return CGRect(x: x, y: y, width: cell.width, height: cell.height)
    }

    func title(for win: DeckWindow) -> String {
        switch win.app {
        case .notes:
            return NotesStore.shared.doc(win.docID)?.title ?? "笔记"
        case .browser:
            guard let raw = win.url, let host = URL(string: raw)?.host else { return "浏览器" }
            return host.replacingOccurrences(of: "www.", with: "")
        default:
            return win.app.title
        }
    }

    // MARK: - 窗口按钮

    func closeButtonRect(_ win: DeckWindow) -> CGRect {
        CGRect(x: win.frame.maxX - 46, y: win.frame.minY, width: 46, height: titleBarHeight)
    }

    func maximizeButtonRect(_ win: DeckWindow) -> CGRect {
        CGRect(x: win.frame.maxX - 92, y: win.frame.minY, width: 46, height: titleBarHeight)
    }

    func minimizeButtonRect(_ win: DeckWindow) -> CGRect {
        CGRect(x: win.frame.maxX - 138, y: win.frame.minY, width: 46, height: titleBarHeight)
    }

    // MARK: - 窗口操作

    func open(_ app: DeckApp, docID: UUID? = nil, url: String? = nil,
              portrait: Bool = false, silent: Bool = false) {
        let existing = windows.first(where: { win -> Bool in
            guard win.app == app else { return false }
            switch app {
            case .notes:   return docID == nil || win.docID == docID
            case .browser: return win.url == url
            default:       return true
            }
        })
        if let existing {
            restore(existing.id)
            focus(existing.id)
            return
        }

        var doc = docID
        if app == .notes, doc == nil {
            doc = NotesStore.shared.create(title: "未命名").id
        }

        let area = workArea
        let target = (app == .browser && portrait)
            ? CGSize(width: 440, height: min(780, area.height - 30))
            : app.defaultSize
        let size = CGSize(width: min(target.width, area.width - 40),
                          height: min(target.height, area.height - 40))
        let step = CGFloat(windows.count % 4)
        let x = min(max(20, area.width * 0.08 + step * 34), max(20, area.width - size.width - 20))
        let y = min(max(20, area.height * 0.06 + step * 28), max(20, area.height - size.height - 20))

        windows.append(DeckWindow(app: app, frame: CGRect(origin: CGPoint(x: x, y: y), size: size), docID: doc, url: url))
        focusID = windows.last?.id
        startMenuOpen = false
        if !silent { post() }
    }

    func focus(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMinimized = false
        let win = windows.remove(at: index)
        windows.append(win)
        focusID = id
        clearTextSinks()
        contentFocus?(id)
        post()
    }

    func clearTextSinks() {
        insertSink = nil
        backspaceSink = nil
        returnSink = nil
        scrollSink = nil
    }

    func toggleStartMenu() {
        startMenuOpen.toggle()
        post()
    }

    func minimize(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMinimized = true
        if focusID == id { focusID = windows.last(where: { !$0.isMinimized })?.id }
        post()
    }

    func restore(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].isMinimized = false
        focus(id)
    }

    func minimizeAll() {
        for index in windows.indices { windows[index].isMinimized = true }
        focusID = nil
        startMenuOpen = false
        post()
    }

    func toggleMaximize(_ id: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        var win = windows[index]
        if win.isMaximized {
            win.isMaximized = false
            if let saved = win.savedFrame { win.frame = saved }
        } else {
            win.savedFrame = win.frame
            win.isMaximized = true
            win.frame = workArea.insetBy(dx: 6, dy: 6)
        }
        windows[index] = win
        post()
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
        if focusID == id { focusID = windows.last(where: { !$0.isMinimized })?.id }
        if let next = focusID { contentFocus?(next) }
        post()
    }

    // MARK: - 输入

    private func frontDocID() -> UUID? {
        windows.reversed().first { $0.app == .notes && !$0.isMinimized }?.docID
    }

    func type(_ text: String) {
        guard !text.isEmpty else { return }
        if let insertSink {
            insertSink(text)
            return
        }
        if let id = frontDocID() {
            NotesStore.shared.append(id, text)
            post()
            return
        }
        let doc = NotesStore.shared.create(title: "未命名")
        open(.notes, docID: doc.id)
    }

    func backspace() {
        if let backspaceSink {
            backspaceSink()
            return
        }
        if let id = frontDocID() {
            NotesStore.shared.backspace(id)
            post()
        }
    }

    func newline() {
        if let returnSink {
            returnSink()
            return
        }
        type("\n")
    }

    func scroll(_ dy: CGFloat) {
        scrollSink?(dy)
    }

    // MARK: - 工具

    private func clamped(_ rect: CGRect) -> CGRect {
        var frame = rect
        let area = workArea
        frame.origin.x = min(max(-frame.width * 0.25, frame.origin.x), max(0, area.width - 100))
        frame.origin.y = min(max(0, frame.origin.y), max(0, area.height - 60))
        return frame
    }
}
