import UIKit
import UniformTypeIdentifiers

/// 底部工具栏按钮：图标在上、文字在下
final class PadButton: UIControl {

    private let icon = UIImageView()
    private let label = UILabel()

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.borderWidth = 0.8
        layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor

        icon.image = UIImage(systemName: symbol)
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        addSubview(icon)

        label.text = title
        label.font = .systemFont(ofSize: 10.5, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isOn = false {
        didSet {
            backgroundColor = isOn
                ? UIColor.systemBlue.withAlphaComponent(0.35)
                : UIColor.white.withAlphaComponent(0.06)
        }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 22
        icon.frame = CGRect(x: (bounds.width - side) / 2, y: 10, width: side, height: side)
        label.frame = CGRect(x: 2, y: bounds.height - 20, width: bounds.width - 4, height: 14)
    }
}

/// 手机这一侧：状态条 + 触控板 + 底部工具栏
final class PhoneViewController: UIViewController, UITextFieldDelegate, UIDocumentPickerDelegate {

    private let model = DeckModel.shared

    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let infoButton = UIButton(type: .system)
    private let emptyHint = UILabel()
    private let trackpad = TrackpadView()
    private let keyboardField = UITextField()

    private var keyboardButton: PadButton!
    private var startButton: PadButton!
    private var appsButton: PadButton!
    private var pointButton: PadButton!
    private var closeButton: PadButton!
    private var buttons: [PadButton] = []
    private var keyboardHeight: CGFloat = 0
    private var lastFieldText = ""
    private let bgGradient = CAGradientLayer()

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        // plist 里的设置可能被构建工具覆盖，这里再强制一次
        UIApplication.shared.isStatusBarHidden = true
    }

    /// 蓝牙键盘：方向键移光标、回车=单击、Esc=关窗、Tab=切窗口
    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []
        func add(_ input: String, _ action: Selector) {
            let command = UIKeyCommand(input: input, modifierFlags: [], action: action)
            command.wantsPriorityOverSystemBehavior = true
            commands.append(command)
        }
        add(UIKeyCommand.inputUpArrow, #selector(keyUp))
        add(UIKeyCommand.inputDownArrow, #selector(keyDown))
        add(UIKeyCommand.inputLeftArrow, #selector(keyLeft))
        add(UIKeyCommand.inputRightArrow, #selector(keyRight))
        add("\r", #selector(keyEnter))
        add(UIKeyCommand.inputEscape, #selector(keyEscape))
        add("\t", #selector(keyTab))
        return commands
    }

    @objc private func keyUp() { model.moveCursor(dx: 0, dy: -22) }
    @objc private func keyDown() { model.moveCursor(dx: 0, dy: 22) }
    @objc private func keyLeft() { model.moveCursor(dx: -22, dy: 0) }
    @objc private func keyRight() { model.moveCursor(dx: 22, dy: 0) }
    @objc private func keyEnter() { model.click() }
    @objc private func keyTab() { model.cycleWindows() }
    @objc private func keyEscape() {
        if let id = model.focusID { model.close(id) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)

        bgGradient.colors = [
            UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 1).cgColor,
            UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.07, blue: 0.12, alpha: 1).cgColor
        ]
        bgGradient.startPoint = CGPoint(x: 0.5, y: 0)
        bgGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(bgGradient, at: 0)

        statusDot.backgroundColor = UIColor(red: 1.0, green: 0.62, blue: 0.45, alpha: 1)
        statusDot.layer.cornerRadius = 3
        view.addSubview(statusDot)

        statusLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        statusLabel.text = "未连接显示器"
        statusLabel.isUserInteractionEnabled = true
        statusLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cycleSpeed)))
        view.addSubview(statusLabel)

        infoButton.setTitle("ⓘ", for: .normal)
        infoButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        infoButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        infoButton.addTarget(self, action: #selector(showDiagnostics), for: .touchUpInside)
        view.addSubview(infoButton)

        emptyHint.text = "用 USB-C 转 HDMI 线接上显示器或电视\n桌面会出现在大屏上"
        emptyHint.font = .systemFont(ofSize: 13)
        emptyHint.textColor = UIColor.white.withAlphaComponent(0.35)
        emptyHint.textAlignment = .center
        emptyHint.numberOfLines = 2
        emptyHint.isUserInteractionEnabled = false
        trackpad.addSubview(emptyHint)

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
                self.model.moveCursor(dx: delta.x * self.model.cursorSpeed,
                                      dy: delta.y * self.model.cursorSpeed)
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
        trackpad.onScroll = { [weak self] dy in
            guard let self else { return }
            let dir: CGFloat = self.model.scrollInverted ? -1 : 1
            self.model.scroll(dy * 1.6 * dir)
        }
        trackpad.onTwoFingerTap = { [weak self] in self?.model.cycleWindows() }
        trackpad.onHold = { [weak self] in self?.model.beginDrag() }
        view.addSubview(trackpad)

        keyboardButton = PadButton(title: "键盘", symbol: "keyboard")
        startButton = PadButton(title: "开始", symbol: "square.grid.2x2")
        appsButton = PadButton(title: "应用", symbol: "list.bullet")
        pointButton = PadButton(title: "点触", symbol: "hand.point.up.left")
        closeButton = PadButton(title: "收窗", symbol: "rectangle.compress.vertical")

        keyboardButton.addTarget(self, action: #selector(showKeyboard), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(toggleStart), for: .touchUpInside)
        appsButton.addTarget(self, action: #selector(showApps(_:)), for: .touchUpInside)
        pointButton.addTarget(self, action: #selector(togglePoint), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeAll), for: .touchUpInside)

        buttons = [keyboardButton, startButton, appsButton, pointButton, closeButton]
        buttons.forEach { view.addSubview($0) }

        keyboardField.delegate = self
        keyboardField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
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
            UIBarButtonItem(title: "⌫ 退格", style: .plain, target: self, action: #selector(backspaceKey)),
            UIBarButtonItem(title: "粘贴", style: .plain, target: self, action: #selector(pasteFromPhone)),
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
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        model.pickFileHandler = { [weak self] in
            guard let self else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = self
            self.present(picker, animated: true)
        }

        updateStatus()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        model.finishFilePick(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        model.finishFilePick(nil)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        keyboardHeight = max(0, view.bounds.maxY - converted.minY)
        view.setNeedsLayout()
    }

    @objc private func keyboardWillHide() {
        keyboardHeight = 0
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradient.frame = view.bounds

        let w = view.bounds.width
        let h = view.bounds.height
        let top = view.safeAreaInsets.top
        let bottom = view.safeAreaInsets.bottom

        let headerY = max(2, top - 8)
        statusDot.frame = CGRect(x: 22, y: headerY + 11, width: 6, height: 6)
        statusLabel.frame = CGRect(x: 36, y: headerY, width: w - 36 - 52, height: 28)
        infoButton.frame = CGRect(x: w - 44, y: headerY, width: 30, height: 28)

        let keyboardUp = keyboardHeight > 0
        let rowHeight: CGFloat = 60
        let bottomInset = keyboardUp ? max(bottom, keyboardHeight) : bottom
        let rowY = h - bottomInset - (keyboardUp ? 4 : 6) - rowHeight
        for button in buttons { button.isHidden = keyboardUp }
        let gap: CGFloat = 8
        let buttonWidth = (w - 32 - gap * 4) / 5
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 16 + CGFloat(index) * (buttonWidth + gap),
                                  y: rowY, width: buttonWidth, height: rowHeight)
        }

        let padTop = headerY + 26
        let padBottom = keyboardUp ? (h - keyboardHeight - 8) : (rowY - 10)
        trackpad.frame = CGRect(x: 14, y: padTop, width: w - 28,
                                height: max(120, padBottom - padTop))
        emptyHint.frame = CGRect(x: 0, y: trackpad.bounds.midY - 34,
                                 width: trackpad.bounds.width, height: 44)
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

    // MARK: - 状态

    @objc private func updateStatus() {
        UIApplication.shared.isIdleTimerDisabled = model.connected
        emptyHint.isHidden = model.connected
        trackpad.setAbsoluteMode(model.absoluteMode)
        trackpad.screenAspect = model.screenSize.width / max(model.screenSize.height, 1)
        pointButton.isOn = model.absoluteMode

        if model.connected {
            let size = model.screenSize
            let speed = String(format: "%.1f", model.cursorSpeed)
            statusDot.backgroundColor = UIColor(red: 0.42, green: 0.86, blue: 0.62, alpha: 1)
            let phone = UIScreen.main.bounds.size
            statusLabel.text = "v\(AppInfo.version) · 手机 \(Int(phone.width))×\(Int(phone.height)) · \(speed)×"
            statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        } else {
            statusDot.backgroundColor = UIColor(red: 1.0, green: 0.62, blue: 0.45, alpha: 1)
            statusLabel.text = "未连接显示器"
            statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        }
    }

    @objc private func cycleSpeed() {
        let speeds: [CGFloat] = [1.6, 2.4, 3.6]
        let index = speeds.firstIndex(where: { abs($0 - model.cursorSpeed) < 0.01 }) ?? 1
        model.cursorSpeed = speeds[(index + 1) % speeds.count]
        updateStatus()
    }

    // MARK: - 诊断

    @objc private func showDiagnostics() {
        var lines: [String] = []
        lines.append("版本 \(AppInfo.version) (build \(AppInfo.build))")
        lines.append("手机屏: \(Int(UIScreen.main.bounds.width))×\(Int(UIScreen.main.bounds.height)) @\(Int(UIScreen.main.scale))x")
        lines.append("")
        lines.append("外接屏: \(model.externalSceneCreated ? "已创建" : "未创建")")
        lines.append("分辨率: \(Int(model.screenSize.width))×\(Int(model.screenSize.height))")
        lines.append("窗口: \(model.windows.count) 个")
        lines.append("触屏事件: \(model.touchCount)（苹果不给外接屏触摸）")
        lines.append("")
        lines.append("滑 = 移光标，轻点 = 单击")
        lines.append("双指滑 = 滚轮，双指轻点 = 切窗口")
        lines.append("标题栏长按 0.2 秒再拖 = 移动，拖到边缘 = 分屏")
        lines.append("点顶部这一行 = 调光标速度")

        let alert = UIAlertController(title: "状态", message: lines.joined(separator: "\n"),
                                      preferredStyle: .alert)
        let title = model.scrollInverted ? "恢复正常滚动方向" : "反转滚动方向"
        alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.model.scrollInverted.toggle()
        })
        alert.addAction(UIAlertAction(title: "好", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 动作

    @objc private func showKeyboard() {
        keyboardField.becomeFirstResponder()
    }

    @objc private func hideKeyboard() {
        view.endEditing(true)
    }

    @objc private func backspaceKey() {
        model.backspace()
    }

    @objc private func pasteFromPhone() {
        let text = UIPasteboard.general.string ?? ""
        if text.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        model.paste(text)
    }

    @objc private func toggleStart() {
        model.toggleStartMenu()
    }

    @objc private func togglePoint() {
        model.absoluteMode.toggle()
        updateStatus()
    }

    @objc private func showApps(_ sender: PadButton) {
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
        alert.addAction(UIAlertAction(title: "好", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 键盘

    /// 输入法安全：不主动清空输入框，而是和上一次内容做差分
    /// —— 这样拼音能正常选字，退格也一定能发出去
    @objc private func fieldChanged() {
        guard keyboardField.markedTextRange == nil else { return }
        let text = keyboardField.text ?? ""
        guard text != lastFieldText else { return }

        if text.hasPrefix(lastFieldText) {
            let added = String(text.dropFirst(lastFieldText.count))
            if !added.isEmpty { model.type(added) }
        } else if lastFieldText.hasPrefix(text) {
            let removed = lastFieldText.count - text.count
            for _ in 0..<removed { model.backspace() }
        } else {
            for _ in 0..<lastFieldText.count { model.backspace() }
            if !text.isEmpty { model.type(text) }
        }
        lastFieldText = text

        if text.count > 200 {
            keyboardField.text = ""
            lastFieldText = ""
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.text = ""
        lastFieldText = ""
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        model.newline()
        return false
    }
}
