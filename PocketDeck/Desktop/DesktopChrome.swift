import UIKit

/// 桌面壁纸：深色渐变 + 两团柔光
final class WallpaperView: UIView {

    private let gradient = CAGradientLayer()
    private let blobA = UIView()
    private let blobB = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradient.colors = [
            UIColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1).cgColor,
            UIColor(red: 0.09, green: 0.10, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.11, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.04, green: 0.12, blue: 0.15, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)

        blobA.backgroundColor = UIColor(red: 0.35, green: 0.32, blue: 0.95, alpha: 0.30)
        blobB.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.60, alpha: 0.22)
        [blobA, blobB].forEach {
            $0.layer.cornerRadius = 0
            addSubview($0)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        let side = max(bounds.width, bounds.height) * 0.9
        blobA.frame = CGRect(x: -side * 0.35, y: -side * 0.45, width: side, height: side)
        blobA.layer.cornerRadius = side / 2
        blobB.frame = CGRect(x: bounds.width - side * 0.55, y: bounds.height - side * 0.7, width: side, height: side)
        blobB.layer.cornerRadius = side / 2
    }
}

/// 顶部菜单栏
final class MenuBarView: UIView {

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let titleLabel = UILabel()
    private let clockLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        titleLabel.text = "PocketDeck"
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        clockLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        clockLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        clockLabel.textAlignment = .right
        addSubview(clockLabel)

        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        line.tag = 99
        addSubview(line)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setClock(_ text: String) { clockLabel.text = text }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = CGRect(x: 18, y: 0, width: 220, height: bounds.height)
        clockLabel.frame = CGRect(x: bounds.width - 200, y: 0, width: 182, height: bounds.height)
        viewWithTag(99)?.frame = CGRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5)
    }
}

/// 底部程序坞
final class DockView: UIView {

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private var items: [DockItemView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 0.8
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor

        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        items = DeckApp.allCases.map { DockItemView(app: $0) }
        items.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(with model: DeckModel) {
        let pad = model.dockPadding
        let size = model.dockItemSize
        let gap = model.dockGap
        let inner = CGRect(x: pad, y: pad, width: bounds.width - pad * 2, height: bounds.height - pad * 2)
        for (index, item) in items.enumerated() {
            item.frame = CGRect(x: inner.minX + CGFloat(index) * (size + gap),
                                y: inner.minY,
                                width: size,
                                height: size)
        }
    }
}

final class DockItemView: UIView {

    let app: DeckApp

    init(app: DeckApp) {
        self.app = app
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        let tile = UIView()
        tile.layer.cornerRadius = 15
        tile.layer.cornerCurve = .continuous
        tile.backgroundColor = app.tint
        tile.frame = CGRect(x: 6, y: 6, width: 54, height: 54)
        tile.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tile)

        let icon = UIImageView(image: UIImage(systemName: app.symbol))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 17, y: 17, width: 32, height: 32)
        icon.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        addSubview(icon)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds.insetBy(dx: 6, dy: 6)
        subviews.last?.frame = bounds.insetBy(dx: 17, dy: 17)
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
