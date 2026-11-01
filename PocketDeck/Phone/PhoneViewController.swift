import UIKit

/// 手机这一侧：触控板 + 键盘 + 启动器 + 诊断
final class PhoneViewController: UIViewController, UITextFieldDelegate {

    private let model = DeckModel.shared

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()
    private let diagLabel = UILabel()
    private let trackpad = TrackpadView()
    private let keyboardField = UITextField()

    private var keyboardButton: UIButton!
    private var startButton: UIButton!
    private var appsButton: UIButton!
    private var pointButton: UIButton!
    private var closeButton: UIButton!
    private var buttons: [UIButton] = []
    private var diagTimer: Timer?

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    deinit {
        diagTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)

        titleLabel.text = "口袋电脑"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        view.addSubview(statusLabel)

        hintLabel.font = .systemFont(ofSize: 11.5)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.42)
        hintLabel.numberOfLines = 2
        view.addSubview(hintLabel)

        diagLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        diagLabel.textColor = UIColor.white.withAlphaComponent(0.32)
        diagLabel.isUserInteractionEnabled = true
        diagLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showDiagnostics)))
        view.addSubview(diagLabel)

        trackpad.onBegin = { [weak self] point in
            guard let self else { return }
            if self.model.absoluteMode { self.model.moveCursorTo(self.mapToScreen(point)) }
            self.model.press()
        }
        trackpad.onMove = { [weak self] point, delta in
            guard let self else { return }
            if self.model.absoluteMode {
                self.model.moveCursorTo(self.mapToScreen(point))
            } else {
                self.model.moveCursor(dx: delta.x * 2.4, dy: delta.y * 2.4)
            }
        }
        trackpad.onEnd = { [weak self] _ in self?.model.release() }
        trackpad.onTap = { [weak self] point in
            guard let self else { return }
            if self.model.absoluteMode { self.model.moveCursorTo(self.mapToScreen(point)) }
            self.model.click()
        }
        trackpad.onScroll = { [weak self] dy in self?.model.scroll(dy * 1.6) }
        view.addSubview(trackpad)

        keyboardButton = makeButton(title: "键盘", symbol: "keyboard", action: #selector(showKeyboard))
        startButton = makeButton(title: "开始", symbol: "square.grid.2x2", action: #selector(toggleStart))
        appsButton = makeButton(title: "应用", symbol: "list.bullet", action: #selector(showApps(_:)))
        pointButton = makeButton(title: "点触", symbol: "hand.point.up.left", action: #selector(togglePoint))
        closeButton = makeButton(title: "收窗", symbol: "rectangle.compress.vertical", action: #selector(closeAll))

        buttons = [keyboardButton, startButton, appsButton, pointButton, closeButton]
        buttons.forEach { view.addSubview($0) }

        keyboardField.delegate = self
        keyboardField.autocorrectionType = .no
        keyboardField.autocapitalizationType = .none
        keyboardField.spellCheckingType = .no
        keyboardField.returnKeyType = .default
        keyboardField.alpha = 0.02
        keyboardField.backgroundColor = .clear
        keyboardField.textColor = .clear
        keyboardField.tintColor = .clear
        view.addSubview(keyboardField)

        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus),
                                               name: .deckChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus),
                                               name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus),
                                               name: UIScreen.didDisconnectNotification, object: nil)

        diagTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshDiagnostics()
        }
        updateStatus()
        refreshDiagnostics()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let w = view.bounds.width
        let h = view.bounds.height
        let top = view.safeAreaInsets.top
        let bottom = view.safeAreaInsets.bottom

        titleLabel.frame = CGRect(x: 22, y: top + 10, width: w - 44, height: 32)
        statusLabel.frame = CGRect(x: 22, y: top + 44, width: w - 44, height: 18)
        hintLabel.frame = CGRect(x: 22, y: top + 66, width: w - 44, height: 32)
        diagLabel.frame = CGRect(x: 22, y: top + 100, width: w - 44, height: 14)

        let rowHeight: CGFloat = 54
        let rowY = h - bottom - 12 - rowHeight
        let gap: CGFloat = 8
        let buttonWidth = (w - 32 - gap * 4) / 5
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 16 + CGFloat(index) * (buttonWidth + gap),
                                  y: rowY, width: buttonWidth, height: rowHeight)
        }

        let padTop = top + 122
        trackpad.frame = CGRect(x: 16, y: padTop, width: w - 32,
                                height: max(120, rowY - 14 - padTop))
        keyboardField.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func mapToScreen(_ point: CGPoint) -> CGPoint {
        let bounds = trackpad.bounds
        guard bounds.width > 1, bounds.height > 1 else { return model.cursor }
        let scaleX = model.screenSize.width / bounds.width
        let scaleY = model.screenSize.height / bounds.height
        return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
    }

    // MARK: - 控件

    private func makeButton(title: String, symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        button.layer.cornerRadius = 13
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 0.8
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func updateStatus() {
        if model.connected {
            let size = model.screenSize
            statusLabel.text = "已连接 · \(Int(size.width))×\(Int(size.height))"
            statusLabel.textColor = UIColor(red: 0.42, green: 0.86, blue: 0.62, alpha: 1)
            hintLabel.text = "滑动移光标；按住标题栏拖窗口，拖到左右边缘自动分屏；右下角拖拽改大小。"
        } else {
            statusLabel.text = "未检测到外接显示器"
            statusLabel.textColor = UIColor(red: 1.0, green: 0.62, blue: 0.45, alpha: 1)
            hintLabel.text = "用 USB-C 转 HDMI 线接显示器或电视，桌面会出现在大屏上。"
        }
        pointButton.backgroundColor = model.absoluteMode
            ? UIColor.systemBlue.withAlphaComponent(0.38)
            : UIColor.white.withAlphaComponent(0.07)
    }

    // MARK: - 诊断

    @objc private func refreshDiagnostics() {
        let screens = UIScreen.screens.count
        let scenes = UIApplication.shared.connectedScenes.count
        let external = model.externalSceneCreated ? "已创建" : "未创建"
        diagLabel.text = "屏\(screens) 场景\(scenes) 外接\(external) 触\(model.touchCount) · 点开看详情"
    }

    @objc private func showDiagnostics() {
        var lines: [String] = []
        lines.append("UIScreen.screens = \(UIScreen.screens.count)")
        for (index, screen) in UIScreen.screens.enumerated() {
            lines.append("  \(index): \(Int(screen.bounds.width))×\(Int(screen.bounds.height)) @\(Int(screen.scale))x")
        }
        lines.append("")
        lines.append("connectedScenes = \(UIApplication.shared.connectedScenes.count)")
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene {
                lines.append("  \(ws.session.role.rawValue)")
                lines.append("    \(Int(ws.screen.bounds.width))×\(Int(ws.screen.bounds.height))")
            }
        }
        lines.append("")
        lines.append("外接场景已创建: \(model.externalSceneCreated)")
        lines.append("model.connected: \(model.connected)")
        lines.append("窗口数: \(model.windows.count)")
        lines.append("触屏事件数: \(model.touchCount)")

        let alert = UIAlertController(title: "诊断信息", message: lines.joined(separator: "\n"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 动作

    @objc private func showKeyboard() {
        keyboardField.becomeFirstResponder()
    }

    @objc private func toggleStart() {
        model.toggleStartMenu()
    }

    @objc private func togglePoint() {
        model.absoluteMode.toggle()
        updateStatus()
    }

    @objc private func showApps(_ sender: UIButton) {
        let sheet = UIAlertController(title: "在大屏上打开", message: nil, preferredStyle: .actionSheet)
        for app in DeckApp.allCases {
            sheet.addAction(UIAlertAction(title: app.title, style: .default) { [weak self] _ in
                self?.model.open(app)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func closeAll() {
        model.minimizeAll()
    }

    // MARK: - 键盘

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string.isEmpty && range.length > 0 {
            model.backspace()
        } else if string == "\n" {
            model.newline()
        } else {
            model.type(string)
        }
        textField.text = ""
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        model.newline()
        return false
    }
}
