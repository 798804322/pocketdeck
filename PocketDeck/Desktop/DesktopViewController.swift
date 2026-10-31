import UIKit

final class DesktopViewController: UIViewController {

    private let model = DeckModel.shared
    private let wallpaper = WallpaperView()
    private let menuBar = MenuBarView()
    private let dock = DockView()
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
        view.addSubview(menuBar)
        view.addSubview(dock)
        view.addSubview(cursor)

        NotificationCenter.default.addObserver(self, selector: #selector(sync),
                                               name: .deckChanged, object: nil)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        model.reportScreen(view.bounds.size)
        layout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        model.reportScreen(view.bounds.size)
        layout()
    }

    @objc private func sync() {
        let size = view.bounds.size
        if abs(size.width - model.screenSize.width) > 2 || abs(size.height - model.screenSize.height) > 2 {
            model.reportScreen(size)
        }
        layout()
    }

    private func tick() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        menuBar.setClock(formatter.string(from: Date()))
        for wv in windowViews.values { wv.updateClock() }
    }

    private func layout() {
        wallpaper.frame = view.bounds
        menuBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: model.menuBarHeight)
        dock.frame = model.dockBackgroundFrame()
        dock.layout(with: model)
        cursor.frame = CGRect(x: model.cursor.x - 3, y: model.cursor.y - 2, width: 22, height: 28)

        var alive = Set<UUID>()
        for win in model.windows {
            alive.insert(win.id)
            let wv: DeckWindowView
            if let existing = windowViews[win.id] {
                wv = existing
            } else {
                wv = DeckWindowView(deckWindow: win, model: model)
                windowViews[win.id] = wv
                view.addSubview(wv)
            }
            wv.frame = win.frame
            wv.refresh()
        }

        for id in Array(windowViews.keys) where !alive.contains(id) {
            windowViews[id]?.removeFromSuperview()
            windowViews.removeValue(forKey: id)
        }

        for win in model.windows {
            if let wv = windowViews[win.id] { view.bringSubviewToFront(wv) }
        }
        view.bringSubviewToFront(dock)
        view.bringSubviewToFront(menuBar)
        view.bringSubviewToFront(cursor)
    }
}
