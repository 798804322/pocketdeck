import UIKit

/// 桌面壁纸
final class WallpaperView: UIView {

    private let gradient = CAGradientLayer()
    private let blobA = UIView()
    private let blobB = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradient.colors = [
            UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1).cgColor,
            UIColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1).cgColor,
            UIColor(red: 0.13, green: 0.09, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.03, green: 0.10, blue: 0.13, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)

        blobA.backgroundColor = UIColor(red: 0.35, green: 0.32, blue: 0.95, alpha: 0.30)
        blobB.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.60, alpha: 0.22)
        addSubview(blobA)
        addSubview(blobB)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        let side = max(bounds.width, bounds.height) * 0.9
        blobA.frame = CGRect(x: -side * 0.35, y: -side * 0.45, width: side, height: side)
        blobA.layer.cornerRadius = side / 2
        blobB.frame = CGRect(x: bounds.width - side * 0.55,
                             y: bounds.height - side * 0.7, width: side, height: side)
        blobB.layer.cornerRadius = side / 2
    }
}

/// 任务栏上的一个窗口按钮
final class TaskbarButton: UIView {

    private let icon = UIImageView()
    private let title = UILabel()
    private let running = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        backgroundColor = UIColor.white.withAlphaComponent(0.05)

        icon.contentMode = .scaleAspectFit
        icon.tintColor = .white
        addSubview(icon)

        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = UIColor.white.withAlphaComponent(0.9)
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        running.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        running.layer.cornerRadius = 1.5
        addSubview(running)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(app: DeckApp, text: String, isActive: Bool) {
        icon.image = UIImage(systemName: app.symbol)
        title.text = text
        backgroundColor = UIColor.white.withAlphaComponent(isActive ? 0.18 : 0.05)
        running.isHidden = false
        running.backgroundColor = UIColor.white.withAlphaComponent(isActive ? 1.0 : 0.35)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        icon.frame = CGRect(x: 8, y: (h - 18) / 2, width: 18, height: 18)
        running.frame = CGRect(x: 8, y: h - 4, width: max(0, bounds.width - 16), height: 3)
        let textX: CGFloat = 32
        title.frame = CGRect(x: textX, y: 0, width: max(0, bounds.width - textX - 8), height: h)
    }
}

/// Windows 风格任务栏
final class TaskbarView: UIView {

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let startButton = UIView()
    private let startGlyph = UIView()
    private var buttons: [TaskbarButton] = []
    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private let touchLabel = UILabel()
    private let showDesktop = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false

        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        startButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        startButton.layer.cornerRadius = 6
        startButton.layer.cornerCurve = .continuous
        addSubview(startButton)

        for (row, col) in [(0, 0), (0, 1), (1, 0), (1, 1)] {
            let square = UIView()
            square.backgroundColor = UIColor(red: 0.36, green: 0.56, blue: 1.0, alpha: 1)
            square.tag = 500 + row * 2 + col
            startGlyph.addSubview(square)
        }
        startButton.addSubview(startGlyph)

        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .right
        timeLabel.tag = 601
        addSubview(timeLabel)

        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        dateLabel.textAlignment = .right
        addSubview(dateLabel)

        touchLabel.font = .systemFont(ofSize: 10)
        touchLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        addSubview(touchLabel)

        showDesktop.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        showDesktop.layer.cornerRadius = 2
        addSubview(showDesktop)

        let topLine = UIView()
        topLine.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        topLine.frame = CGRect(x: 0, y: 0, width: 10000, height: 0.5)
        addSubview(topLine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(with model: DeckModel, time: String, date: String) {
        let barTop = model.taskbarFrame().minY
        let localStart = model.startButtonFrame().offsetBy(dx: 0, dy: -barTop)

        startButton.frame = localStart
        startGlyph.frame = CGRect(x: 11, y: 9, width: 18, height: 18)
        for (index, square) in startGlyph.subviews.enumerated() {
            let col = index % 2
            let row = index / 2
            square.frame = CGRect(x: CGFloat(col) * 10, y: CGFloat(row) * 10, width: 8, height: 8)
            square.layer.cornerRadius = 1.5
        }

        // 窗口按钮
        while buttons.count < model.windows.count {
            let button = TaskbarButton()
            buttons.append(button)
            addSubview(button)
        }
        for (index, button) in buttons.enumerated() {
            if index < model.windows.count {
                let win = model.windows[index]
                button.isHidden = false
                let rect = model.windowButtonFrame(index)
                button.frame = rect.offsetBy(dx: 0, dy: -barTop)
                let label = model.title(for: win)
                button.configure(app: win.app, text: label, isActive: win.id == model.focusID && !win.isMinimized)
            } else {
                button.isHidden = true
            }
        }

        timeLabel.text = time
        dateLabel.text = date
        touchLabel.text = "触 \(model.touchCount)"
        touchLabel.sizeToFit()

        let tray = model.trayFrame().offsetBy(dx: 0, dy: -barTop)
        timeLabel.frame = CGRect(x: tray.minX, y: tray.minY + 9, width: tray.width - 8, height: 16)
        dateLabel.frame = CGRect(x: tray.minX, y: tray.minY + 24, width: tray.width - 8, height: 14)
        touchLabel.frame = CGRect(x: tray.minX - 40, y: tray.minY + 16, width: 40, height: 14)

        showDesktop.frame = model.showDesktopFrame().offsetBy(dx: 0, dy: -barTop)
    }
}

/// 开始菜单
final class StartMenuView: UIView {

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let appsTitle = UILabel()
    private let nativeTitle = UILabel()
    private let webTitle = UILabel()
    private let footer = UILabel()
    private var items: [StartItem] = []
    private var nativeItems: [NativeStartItem] = []
    private var webItems: [WebStartItem] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 0.8
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        appsTitle.text = "应用"
        appsTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        appsTitle.textColor = UIColor.white.withAlphaComponent(0.55)
        addSubview(appsTitle)

        nativeTitle.text = "手机 App · 点一下跳到原生 App"
        nativeTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        nativeTitle.textColor = UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.85)
        addSubview(nativeTitle)

        webTitle.text = "网页 · 在大屏窗口里打开"
        webTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        webTitle.textColor = UIColor.white.withAlphaComponent(0.55)
        addSubview(webTitle)

        footer.text = "手机 App 会跳出桌面，大屏随之变成镜像"
        footer.font = .systemFont(ofSize: 10)
        footer.textColor = UIColor.white.withAlphaComponent(0.3)
        addSubview(footer)

        items = DeckApp.allCases.map { StartItem(app: $0) }
        items.forEach { addSubview($0) }

        nativeItems = NativeAppCatalog.all.map { NativeStartItem(native: $0) }
        nativeItems.forEach { addSubview($0) }

        webItems = WebAppCatalog.all.map { WebStartItem(web: $0) }
        webItems.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(with model: DeckModel) {
        let origin = model.startMenuFrame().origin
        appsTitle.frame = CGRect(x: 14, y: 12, width: 240, height: 18)
        nativeTitle.frame = CGRect(x: 14, y: 232, width: 340, height: 18)
        webTitle.frame = CGRect(x: 14, y: 404, width: 320, height: 18)
        footer.frame = CGRect(x: 14, y: bounds.height - 20, width: bounds.width - 28, height: 14)

        for (index, item) in items.enumerated() {
            item.frame = model.startMenuItemFrame(index).offsetBy(dx: -origin.x, dy: -origin.y)
        }
        for (index, item) in nativeItems.enumerated() {
            item.frame = model.startMenuNativeFrame(index).offsetBy(dx: -origin.x, dy: -origin.y)
        }
        for (index, item) in webItems.enumerated() {
            item.frame = model.startMenuWebFrame(index).offsetBy(dx: -origin.x, dy: -origin.y)
        }
    }
}

final class StartItem: UIView {

    let app: DeckApp
    private let tile = UIView()
    private let icon = UIImageView()
    private let label = UILabel()

    init(app: DeckApp) {
        self.app = app
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        tile.backgroundColor = app.tint
        tile.layer.cornerRadius = 13
        tile.layer.cornerCurve = .continuous
        addSubview(tile)

        icon.image = UIImage(systemName: app.symbol)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        addSubview(icon)

        label.text = app.title
        label.font = .systemFont(ofSize: 11)
        label.textColor = UIColor.white.withAlphaComponent(0.88)
        label.textAlignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 44
        tile.frame = CGRect(x: (bounds.width - side) / 2, y: 8, width: side, height: side)
        icon.frame = tile.frame.insetBy(dx: 11, dy: 11)
        label.frame = CGRect(x: 0, y: 58, width: bounds.width, height: 16)
    }
}

/// 开始菜单里的网页应用
final class WebStartItem: UIView {

    private let tile = UIView()
    private let initials = UILabel()
    private let label = UILabel()

    init(web: WebApp) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        tile.backgroundColor = web.tint
        tile.layer.cornerRadius = 11
        tile.layer.cornerCurve = .continuous
        tile.layer.borderWidth = 0.6
        tile.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        addSubview(tile)

        initials.text = web.initials
        initials.font = .systemFont(ofSize: 15, weight: .bold)
        initials.textColor = .white
        initials.textAlignment = .center
        addSubview(initials)

        label.text = web.name
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 42
        tile.frame = CGRect(x: (bounds.width - side) / 2, y: 6, width: side, height: side)
        initials.frame = tile.frame
        label.frame = CGRect(x: 2, y: 52, width: bounds.width - 4, height: 14)
    }
}
/// 鼠标指针
final class CursorView: UIView {

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 22, height: 28))
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 2, y: 1))
        path.addLine(to: CGPoint(x: 2, y: 22))
        path.addLine(to: CGPoint(x: 7.5, y: 16.5))
        path.addLine(to: CGPoint(x: 12, y: 26))
        path.addLine(to: CGPoint(x: 16, y: 24.2))
        path.addLine(to: CGPoint(x: 11.5, y: 15))
        path.addLine(to: CGPoint(x: 19, y: 14.5))
        path.close()
        UIColor.white.setFill()
        path.fill()
        UIColor.black.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 1.3
        path.stroke()
    }
}

/// 桌面上的图标（和 Windows 一样，双击不用，点一下就开）
final class DesktopIconView: UIView {

    let app: DeckApp
    private let tile = UIView()
    private let icon = UIImageView()
    private let label = UILabel()

    init(app: DeckApp) {
        self.app = app
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        tile.backgroundColor = app.tint
        tile.layer.cornerRadius = 12
        tile.layer.cornerCurve = .continuous
        tile.layer.shadowColor = UIColor.black.cgColor
        tile.layer.shadowOpacity = 0.35
        tile.layer.shadowRadius = 8
        tile.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(tile)

        icon.image = UIImage(systemName: app.symbol)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        addSubview(icon)

        label.text = app.title
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.6
        label.layer.shadowRadius = 3
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 52
        tile.frame = CGRect(x: (bounds.width - side) / 2, y: 4, width: side, height: side)
        icon.frame = tile.frame.insetBy(dx: 13, dy: 13)
        label.frame = CGRect(x: 0, y: 62, width: bounds.width, height: 16)
    }
}
/// 开始菜单里的「手机原生 App」项：点了会跳出桌面
final class NativeStartItem: UIView {

    private let tile = UIView()
    private let icon = UIImageView()
    private let badge = UILabel()
    private let label = UILabel()

    init(native: NativeApp) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        tile.backgroundColor = UIColor(red: 0.22, green: 0.42, blue: 0.85, alpha: 0.55)
        tile.layer.cornerRadius = 10
        tile.layer.cornerCurve = .continuous
        tile.layer.borderWidth = 0.6
        tile.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        addSubview(tile)

        icon.image = UIImage(systemName: "arrow.up.forward.app")
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        addSubview(icon)

        badge.text = "↗"
        badge.font = .systemFont(ofSize: 9, weight: .bold)
        badge.textColor = UIColor.white.withAlphaComponent(0.7)
        badge.textAlignment = .center
        addSubview(badge)

        label.text = native.name
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = UIColor.white.withAlphaComponent(0.88)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 36
        tile.frame = CGRect(x: (bounds.width - side) / 2, y: 6, width: side, height: side)
        icon.frame = tile.frame.insetBy(dx: 9, dy: 9)
        badge.frame = CGRect(x: tile.frame.maxX - 12, y: tile.frame.minY, width: 12, height: 10)
        label.frame = CGRect(x: 2, y: 46, width: bounds.width - 4, height: 14)
    }
}