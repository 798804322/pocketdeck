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
            self.view.endEditing(true)
            if self.model.absoluteMode, let target = self.mapToScreen(point) {
                self.model.moveCursorTo(target)
            }
            self.model.press()
        }
        trackpad.onMove = { [weak self] point, delta in
            guard let self else { return }
            if self.model.absoluteMode {
                if let target = self.mapToScreen(point) { self.model.moveCursorTo(target) }
            } else {
                self.model.moveCursor(dx: delta.x * 2.4, dy: delta.y * 2.4)
            }
        }
        trackpad.onEnd = { [weak self] _ in self?.model.release() }
        trackpad.onTap = { [weak self] point in
            guard let self else { return }
            if self.model.absoluteMode, let target = self.mapToScreen(point) {
                self.model.moveCursorTo(target)
            }
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

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 240, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "收起键盘", style: .done, target: self, action: #selector(hideKeyboard))
        ]
        toolbar.sizeToFit()
        keyboardField.inputAccessoryView = toolbar

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

    /// 只认触控板里那块「大屏」矩形，按等比映射
    private func mapToScreen(_ point: CGPoint) -> CGPoint? {
        let rect = trackpad.screenFrame
        guard rect.width > 1, rect.height > 1, rect.contains(point) else { return nil }
        let x = (point.x - rect.minX) / rect.width * model.screenSize.width
        let y = (point.y - rect.minY) / rect.height * model.screenSize.height
        return CGPoint(x: min(max(0, x), model.screenSize.width - 2),
                       y: min(max(0, y), model.screenSize.height - 2))
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
        trackpad.screenAspect = model.screenSize.width / max(model.screenSize.height, 1)
        trackpad.setAbsoluteMode(model.absoluteMode)
    }

    // MARK: - 诊断

    @objc private func refreshDiagnostics() {
        let screens = UIScreen.screens.count
        let scenes = UIApplication.shared.connectedScenes.count
        let external = model.externalSceneCreated ? "已创建" : "未创建"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        diagLabel.text = "v\(version) · 屏\(screens) 场景\(scenes) 外接\(external) 触\(model.touchCount) · 点开看详情"
    }

    @objc private func showDiagnostics() {
        var lines: [String] = []
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        lines.append("版本: \(version) (build \(build))")
        lines.append("")
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

    @objc private func hideKeyboard() {
        view.endEditing(true)
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
            sheet.addAction(UIAlertAction(title: "桌面 · \(app.title)", style: .default) { [weak self] _ in
                self?.model.open(app)
            })
        }
        for native in NativeAppCatalog.all {
            sheet.addAction(UIAlertAction(title: "手机 · \(native.name)（会切出去）", style: .default) { [weak self] _ in
                guard let self else { return }
                NativeAppLauncher.open(native) { ok in
                    if !ok { self.showMissing(native.name) }
                }
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

    private func showMissing(_ name: String) {
        let alert = UIAlertController(title: "打不开",
                                      message: "手机里没装「\(name)」，或者它不支持被这样唤起。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
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
