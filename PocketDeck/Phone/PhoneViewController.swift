import UIKit

/// 手机这一侧：触控板 + 键盘 + 启动器
final class PhoneViewController: UIViewController, UITextFieldDelegate {

    private let model = DeckModel.shared

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()
    private let trackpad = TrackpadView()
    private let keyboardField = UITextField()

    private var keyboardButton: UIButton!
    private var appsButton: UIButton!
    private var dragButton: UIButton!
    private var closeButton: UIButton!
    private var buttons: [UIButton] = []

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)

        titleLabel.text = "口袋电脑"
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.62, green: 0.70, blue: 1.0, alpha: 1)
        view.addSubview(statusLabel)

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.42)
        hintLabel.numberOfLines = 2
        view.addSubview(hintLabel)

        trackpad.onMove = { [weak self] delta in
            guard let self else { return }
            self.model.moveCursor(dx: delta.x * 2.4, dy: delta.y * 2.4)
        }
        trackpad.onTap = { [weak self] in
            self?.model.click()
        }
        view.addSubview(trackpad)

        keyboardButton = makeButton(title: "键盘", symbol: "keyboard", action: #selector(showKeyboard))
        appsButton = makeButton(title: "应用", symbol: "square.grid.2x2", action: #selector(showApps(_:)))
        dragButton = makeButton(title: "拖动", symbol: "hand.draw", action: #selector(toggleDrag))
        closeButton = makeButton(title: "收窗", symbol: "rectangle.compress.vertical", action: #selector(closeAll))

        buttons = [keyboardButton, appsButton, dragButton, closeButton]
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
        updateStatus()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let w = view.bounds.width
        let h = view.bounds.height
        let top = view.safeAreaInsets.top
        let bottom = view.safeAreaInsets.bottom

        titleLabel.frame = CGRect(x: 22, y: top + 14, width: w - 44, height: 34)
        statusLabel.frame = CGRect(x: 22, y: top + 50, width: w - 44, height: 18)
        hintLabel.frame = CGRect(x: 22, y: top + 72, width: w - 44, height: 34)

        let rowHeight: CGFloat = 58
        let rowY = h - bottom - 16 - rowHeight
        let gap: CGFloat = 10
        let buttonWidth = (w - 32 - gap * 3) / 4
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 16 + CGFloat(index) * (buttonWidth + gap),
                                  y: rowY, width: buttonWidth, height: rowHeight)
        }

        let padTop = top + 114
        trackpad.frame = CGRect(x: 16, y: padTop, width: w - 32,
                                height: max(120, rowY - 18 - padTop))
        keyboardField.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    // MARK: - 控件

    private func makeButton(title: String, symbol: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 0.8
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func updateStatus() {
        if model.connected {
            let size = model.screenSize
            statusLabel.text = "已连接显示器 · \(Int(size.width))×\(Int(size.height))"
            statusLabel.textColor = UIColor(red: 0.42, green: 0.86, blue: 0.62, alpha: 1)
            hintLabel.text = "在下面滑动＝移动光标，轻点＝单击。点「拖动」可以拖窗口。"
        } else {
            statusLabel.text = "未检测到外接显示器"
            statusLabel.textColor = UIColor(red: 1.0, green: 0.62, blue: 0.45, alpha: 1)
            hintLabel.text = "用 USB-C 转 HDMI 线接上显示器或电视，桌面会出现在大屏上。"
        }
        dragButton.backgroundColor = model.dragMode
            ? UIColor.systemOrange.withAlphaComponent(0.35)
            : UIColor.white.withAlphaComponent(0.07)
    }

    // MARK: - 动作

    @objc private func showKeyboard() {
        keyboardField.becomeFirstResponder()
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

    @objc private func toggleDrag() {
        model.dragMode.toggle()
        updateStatus()
    }

    @objc private func closeAll() {
        model.closeAll()
        updateStatus()
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
