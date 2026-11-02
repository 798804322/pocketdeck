import UIKit

/// 贪吃蛇：跑在大屏窗口里，手机当手柄
final class SnakeContentView: BaseContentView {

    private enum State {
        case ready
        case running
        case paused
        case over
    }

    private let cols = 26
    private let rows = 17

    private var snake: [CGPoint] = []
    private var direction = CGPoint(x: 1, y: 0)
    private var nextDirection = CGPoint(x: 1, y: 0)
    private var food = CGPoint(x: 18, y: 8)
    private var state: State = .ready
    private var score = 0
    private var best = 0

    private var link: CADisplayLink?
    private var accumulator: TimeInterval = 0
    private var pulse: CGFloat = 0
    private var tickInterval: TimeInterval = 0.16

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 1)
        isOpaque = true
        best = UserDefaults.standard.integer(forKey: "pocketdeck.snake.best")
        resetGame()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        link?.invalidate()
    }

    override func activate() {
        DeckModel.shared.gameSink = { [weak self] command in
            self?.handle(command)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
            return
        }
        if link == nil {
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            display.preferredFramesPerSecond = 30
            display.add(to: .main, forMode: .common)
            link = display
        }

        DeckModel.shared.gameSink = { [weak self] command in
            self?.handle(command)
        }
    }

    /// 用光标点窗口也能开始 / 暂停
    override func handleTap(at point: CGPoint) {
        primaryAction()
    }

    // MARK: - 主循环

    @objc private func tick(_ display: CADisplayLink) {
        let dt = max(0.001, display.targetTimestamp - display.timestamp)
        pulse += CGFloat(dt)

        if state == .running {
            accumulator += dt
            if accumulator >= tickInterval {
                accumulator = 0
                stepGame()
            }
        }

        setNeedsDisplay()
    }

    // MARK: - 游戏逻辑

    private func resetGame() {
        let cx = cols / 2
        let cy = rows / 2
        snake = [CGPoint(x: cx, y: cy),
                 CGPoint(x: cx - 1, y: cy),
                 CGPoint(x: cx - 2, y: cy)]
        direction = CGPoint(x: 1, y: 0)
        nextDirection = direction
        score = 0
        tickInterval = 0.16
        accumulator = 0
        placeFood()
    }

    private func placeFood() {
        var attempts = 0
        repeat {
            food = CGPoint(x: CGFloat(Int.random(in: 0..<cols)),
                           y: CGFloat(Int.random(in: 0..<rows)))
            attempts += 1
        } while snake.contains(food) && attempts < 200
    }

    private func stepGame() {
        direction = nextDirection
        guard let head = snake.first else { return }

        let newHead = CGPoint(x: head.x + direction.x, y: head.y + direction.y)

        if newHead.x < 0 || newHead.y < 0 || newHead.x >= CGFloat(cols) || newHead.y >= CGFloat(rows) {
            state = .over
            return
        }
        if snake.contains(newHead) {
            state = .over
            return
        }

        snake.insert(newHead, at: 0)

        if newHead == food {
            score += 1
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: "pocketdeck.snake.best")
            }
            tickInterval = max(0.07, 0.16 - Double(score) * 0.004)
            placeFood()
        } else {
            snake.removeLast()
        }
    }

    // MARK: - 手柄输入

    private func handle(_ command: GameCommand) {
        switch command {
        case .up:     turn(0, -1)
        case .down:   turn(0, 1)
        case .left:   turn(-1, 0)
        case .right:  turn(1, 0)
        case .action: primaryAction()
        }
    }

    private func turn(_ dx: CGFloat, _ dy: CGFloat) {
        if state == .ready { state = .running }
        guard state == .running else { return }
        if dx == -direction.x && dy == -direction.y { return }
        nextDirection = CGPoint(x: dx, y: dy)
    }

    private func primaryAction() {
        switch state {
        case .ready:
            state = .running
        case .running:
            state = .paused
        case .paused:
            state = .running
        case .over:
            resetGame()
            state = .running
        }
    }

    // MARK: - 绘制

    private func cellSize() -> CGFloat {
        let w = bounds.width
        let h = bounds.height
        guard w > 20, h > 20 else { return 10 }
        return floor(min(w / CGFloat(cols + 1), h / CGFloat(rows + 2)))
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setFillColor(UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 1).cgColor)
        ctx.fill(bounds)

        let cell = cellSize()
        let boardW = cell * CGFloat(cols)
        let boardH = cell * CGFloat(rows)
        let ox = (bounds.width - boardW) / 2
        let oy = (bounds.height - boardH) / 2

        // 网格
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.045).cgColor)
        ctx.setLineWidth(1)
        for c in 0...cols {
            let x = ox + CGFloat(c) * cell
            ctx.move(to: CGPoint(x: x, y: oy))
            ctx.addLine(to: CGPoint(x: x, y: oy + boardH))
        }
        for r in 0...rows {
            let y = oy + CGFloat(r) * cell
            ctx.move(to: CGPoint(x: ox, y: y))
            ctx.addLine(to: CGPoint(x: ox + boardW, y: y))
        }
        ctx.strokePath()

        // 边框
        ctx.setStrokeColor(UIColor(red: 0.30, green: 0.88, blue: 0.60, alpha: 0.28).cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: ox, y: oy, width: boardW, height: boardH))

        // 食物
        let glow = 0.5 + 0.5 * sin(pulse * 4)
        let foodRect = CGRect(x: ox + food.x * cell + cell * 0.20,
                              y: oy + food.y * cell + cell * 0.20,
                              width: cell * 0.60,
                              height: cell * 0.60)
        ctx.setFillColor(UIColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.18 + 0.22 * glow).cgColor)
        ctx.fillEllipse(in: foodRect.insetBy(dx: -cell * 0.20, dy: -cell * 0.20))
        ctx.setFillColor(UIColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: foodRect)

        // 蛇身
        for (index, point) in snake.enumerated() {
            let inset = index == 0 ? cell * 0.06 : cell * 0.13
            let frame = CGRect(x: ox + point.x * cell + inset,
                               y: oy + point.y * cell + inset,
                               width: max(1, cell - inset * 2),
                               height: max(1, cell - inset * 2))

            if index == 0 {
                ctx.setFillColor(UIColor(red: 0.62, green: 1.0, blue: 0.80, alpha: 1.0).cgColor)
            } else {
                let fade = 0.95 - 0.55 * (CGFloat(index) / CGFloat(max(1, snake.count)))
                ctx.setFillColor(UIColor(red: 0.30, green: 0.88, blue: 0.60, alpha: max(0.30, fade)).cgColor)
            }

            let path = UIBezierPath(roundedRect: frame, cornerRadius: cell * 0.28)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }

        drawHUD(boardTop: oy)

        switch state {
        case .ready:
            drawOverlay(title: "贪吃蛇", subtitle: "按手柄方向键开始 · A 暂停")
        case .paused:
            drawOverlay(title: "已暂停", subtitle: "按 A 继续")
        case .over:
            drawOverlay(title: "游戏结束", subtitle: "得分 \(score) · 最高 \(best) · 按 A 重开")
        case .running:
            break
        }
    }

    private func drawHUD(boardTop: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75)
        ]
        let y = max(6, boardTop - 26)
        ("得分 \(score)" as NSString).draw(at: CGPoint(x: 18, y: y), withAttributes: attributes)

        let bestText = "最高 \(best)" as NSString
        let size = bestText.size(withAttributes: attributes)
        bestText.draw(at: CGPoint(x: bounds.width - size.width - 18, y: y), withAttributes: attributes)
    }

    private func drawOverlay(title: String, subtitle: String) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(bounds)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.72)
        ]

        let titleText = title as NSString
        let subText = subtitle as NSString
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let subSize = subText.size(withAttributes: subAttributes)

        titleText.draw(at: CGPoint(x: (bounds.width - titleSize.width) / 2,
                                   y: bounds.height / 2 - titleSize.height - 4),
                       withAttributes: titleAttributes)
        subText.draw(at: CGPoint(x: (bounds.width - subSize.width) / 2,
                                 y: bounds.height / 2 + 8),
                     withAttributes: subAttributes)
    }
}
