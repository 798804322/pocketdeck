import UIKit

/// 手机手柄：十字方向键 + A 键
final class GamepadView: UIView {

    var onCommand: ((GameCommand) -> Void)?

    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.8
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor

        makeKey(tag: 0, symbol: "chevron.up")
        makeKey(tag: 1, symbol: "chevron.down")
        makeKey(tag: 2, symbol: "chevron.left")
        makeKey(tag: 3, symbol: "chevron.right")

        let action = UIButton(type: .system)
        action.tag = 4
        action.setTitle("A", for: .normal)
        action.titleLabel?.font = .systemFont(ofSize: 26, weight: .heavy)
        action.setTitleColor(.white, for: .normal)
        action.backgroundColor = UIColor(red: 0.30, green: 0.88, blue: 0.60, alpha: 0.85)
        action.layer.cornerRadius = 40
        action.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
        addSubview(action)
        buttons.append(action)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeKey(tag: Int, symbol: String) {
        let button = UIButton(type: .system)
        button.tag = tag
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.9)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
        addSubview(button)
        buttons.append(button)
    }

    @objc private func tap(_ sender: UIButton) {
        let command: GameCommand
        switch sender.tag {
        case 0: command = .up
        case 1: command = .down
        case 2: command = .left
        case 3: command = .right
        default: command = .action
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onCommand?(command)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard buttons.count == 5 else { return }

        let h = bounds.height
        let side = min(h * 0.86, bounds.width * 0.46)
        let padX: CGFloat = 16
        let padY = (h - side) / 2
        let cell = side / 3

        buttons[0].frame = CGRect(x: padX + cell, y: padY, width: cell, height: cell)
        buttons[1].frame = CGRect(x: padX + cell, y: padY + cell * 2, width: cell, height: cell)
        buttons[2].frame = CGRect(x: padX, y: padY + cell, width: cell, height: cell)
        buttons[3].frame = CGRect(x: padX + cell * 2, y: padY + cell, width: cell, height: cell)

        let aSide = min(h * 0.58, 92)
        buttons[4].frame = CGRect(x: bounds.width - aSide - 28,
                                  y: (h - aSide) / 2,
                                  width: aSide,
                                  height: aSide)
        buttons[4].layer.cornerRadius = aSide / 2
    }
}
