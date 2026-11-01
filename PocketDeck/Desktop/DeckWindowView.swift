import UIKit

/// Windows 风格的窗口
final class DeckWindowView: UIView {

    let windowID: UUID
    let app: DeckApp
    private(set) var content: DeckAppContent?

    private let card = UIView()
    private let titleBar = UIView()
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let minButton = UIButton(type: .system)
    private let maxButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let contentHolder = UIView()
    private let grip = ResizeGrip()

    init(deckWindow: DeckWindow) {
        windowID = deckWindow.id
        app = deckWindow.app
        super.init(frame: deckWindow.frame)

        card.frame = bounds
        card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.layer.cornerRadius = 10
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 0.97)
        card.layer.borderWidth = 0.8
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.13).cgColor
        addSubview(card)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 10).cgPath

        titleBar.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        card.addSubview(titleBar)

        iconView.image = UIImage(systemName: app.symbol)
        iconView.tintColor = app.tint
        iconView.contentMode = .scaleAspectFit
        titleBar.addSubview(iconView)

        titleLabel.text = DeckModel.shared.title(for: deckWindow)
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        titleBar.addSubview(titleLabel)

        styleWindowButton(minButton, symbol: "minus")
        styleWindowButton(maxButton, symbol: "square")
        styleWindowButton(closeButton, symbol: "xmark")
        closeButton.backgroundColor = UIColor(red: 0.72, green: 0.14, blue: 0.10, alpha: 0.75)
        [minButton, maxButton, closeButton].forEach { titleBar.addSubview($0) }


        card.addSubview(contentHolder)
        card.addSubview(grip)

        let built = DeckAppFactory.make(for: deckWindow)
        content = built
        contentHolder.addSubview(built.view)
        built.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func styleWindowButton(_ button: UIButton, symbol: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        button.setPreferredSymbolConfiguration(configuration, forImageIn: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.9)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.045)
        // 点击统一由 DeckModel 的命中测试处理，避免和真触屏双触发
        button.isUserInteractionEnabled = false
    }

    @objc private func tapMinimize() { DeckModel.shared.minimize(windowID) }
    @objc private func tapMaximize() { DeckModel.shared.toggleMaximize(windowID) }
    @objc private func tapClose() { DeckModel.shared.close(windowID) }

    func applyTitle(_ text: String) {
        titleLabel.text = text
    }

    func refresh() {
        (content as? NotesContentView)?.reload()
        (content as? FilesContentView)?.reload()
    }

    /// 手机光标在窗口内的点击
    func handleTap(at point: CGPoint) {
        let local = CGPoint(x: point.x, y: point.y - DeckModel.shared.titleBarHeight)
        content?.handleTap(at: local)
    }

    func handleScroll(_ dy: CGFloat) {
        content?.handleScroll(dy)
    }

    func handleDrag(at point: CGPoint, phase: DragPhase) {
        let local = CGPoint(x: point.x, y: point.y - DeckModel.shared.titleBarHeight)
        content?.handleDrag(at: local, phase: phase)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        card.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 10).cgPath

        let bar = DeckModel.shared.titleBarHeight
        titleBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bar)
        iconView.frame = CGRect(x: 12, y: (bar - 14) / 2, width: 14, height: 14)
        titleLabel.frame = CGRect(x: 34, y: 0, width: max(0, bounds.width - 34 - 150), height: bar)

        let buttonWidth: CGFloat = 46
        closeButton.frame = CGRect(x: bounds.width - buttonWidth, y: 0, width: buttonWidth, height: bar)
        maxButton.frame = CGRect(x: bounds.width - buttonWidth * 2, y: 0, width: buttonWidth, height: bar)
        minButton.frame = CGRect(x: bounds.width - buttonWidth * 3, y: 0, width: buttonWidth, height: bar)

        contentHolder.frame = CGRect(x: 0, y: bar, width: bounds.width, height: max(0, bounds.height - bar))
        content?.view.frame = contentHolder.bounds
        grip.frame = CGRect(x: bounds.width - 18, y: bounds.height - 18, width: 16, height: 16)
    }
}

/// 右下角的缩放提示（真正的缩放由 DeckModel 的命中测试处理）
final class ResizeGrip: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(1)
        for index in 0..<3 {
            let offset = CGFloat(index) * 4 + 2
            context.move(to: CGPoint(x: bounds.width - offset, y: bounds.height - 2))
            context.addLine(to: CGPoint(x: bounds.width - 2, y: bounds.height - offset))
        }
        context.strokePath()
    }
}
