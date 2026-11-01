import UIKit

final class DesktopViewController: UIViewController {

    private let model = DeckModel.shared
    private let wallpaper = WallpaperView()
    private let taskbar = TaskbarView()
    private let startMenu = StartMenuView()
    private let cursor = CursorView()
    private var windowViews: [UUID: DeckWindowView] = [:]
    private var timer: Timer?

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(wallpaper)
        view.addSubview(taskbar)
        view.addSubview(startMenu)
        view.addSubview(cursor)
        startMenu.isHidden = true

        model.contentTap = { [weak self] id, point in
            self?.windowViews[id]?.handleTap(at: point)
        }
        model.contentFocus = { [weak self] id in
            self?.windowViews[id]?.content?.activate()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(sync),
                                               name: .deckChanged, object: nil)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        model.reportScreen(view.bounds.size)
        sync()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        model.reportScreen(view.bounds.size)
        layoutAll()
    }

    /// 外接屏上的真实触摸（显示器如果能把触控当鼠标上报，这里会收到）
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        model.registerTouch()
        model.clickAt(point)
    }

    @objc private func sync() {
        let size = view.bounds.size
        if abs(size.width - model.screenSize.width) > 2 || abs(size.height - model.screenSize.height) > 2 {
            model.reportScreen(size)
        }
        layoutAll()
    }

    private func tick() {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"
        taskbar.update(with: model,
                       time: timeFormatter.string(from: Date()),
                       date: dateFormatter.string(from: Date()))
    }

    private func layoutAll() {
        wallpaper.frame = view.bounds
        taskbar.frame = model.taskbarFrame()
        taskbar.update(with: model, time: currentTime(), date: currentDate())
        startMenu.frame = model.startMenuFrame()
        startMenu.update(with: model)
        startMenu.isHidden = !model.startMenuOpen
        cursor.frame = CGRect(x: model.cursor.x - 3, y: model.cursor.y - 2, width: 22, height: 28)

        var alive = Set<UUID>()
        for win in model.windows {
            alive.insert(win.id)
            let windowView: DeckWindowView
            if let existing = windowViews[win.id] {
                windowView = existing
            } else {
                windowView = DeckWindowView(deckWindow: win)
                windowViews[win.id] = windowView
                view.addSubview(windowView)
            }
            windowView.isHidden = win.isMinimized
            windowView.frame = win.frame
            windowView.applyTitle(model.title(for: win))
            windowView.refresh()
        }

        for id in Array(windowViews.keys) where !alive.contains(id) {
            windowViews[id]?.removeFromSuperview()
            windowViews.removeValue(forKey: id)
        }

        for win in model.windows where !win.isMinimized {
            if let windowView = windowViews[win.id] { view.bringSubviewToFront(windowView) }
        }
        view.bringSubviewToFront(taskbar)
        view.bringSubviewToFront(startMenu)
        view.bringSubviewToFront(cursor)

        if let focusID = model.focusID, let windowView = windowViews[focusID] {
            windowView.content?.activate()
        }
    }

    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func currentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }
}
