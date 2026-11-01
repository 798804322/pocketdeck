import UIKit

/// 手机触控板：中间那块深色区域 = 大屏的等比缩略图
final class TrackpadView: UIView {

    var onBegin: ((CGPoint) -> Void)?
    var onMove: ((CGPoint, CGPoint) -> Void)?
    var onEnd: ((CGPoint) -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onScroll: ((CGFloat) -> Void)?
    /// 双指轻点（不滑动）
    var onTwoFingerTap: (() -> Void)?
    /// 按住不动（用来启动拖窗口）
    var onHold: (() -> Void)?

    /// 大屏区域（触控板坐标系里那个等比矩形）
    private(set) var screenFrame: CGRect = .zero

    var screenAspect: CGFloat = 16.0 / 9.0 {
        didSet { setNeedsLayout() }
    }

    private let screenView = UIView()
    private let screenHint = UILabel()
    private var last: CGPoint = .zero
    private var start: CGPoint = .zero
    private var active = false
    private var moved = false
    private var multi = false
    private var holdWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        isMultipleTouchEnabled = true

        screenView.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        screenView.layer.cornerRadius = 12
        screenView.layer.cornerCurve = .continuous
        screenView.layer.borderWidth = 1
        screenView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        screenView.isUserInteractionEnabled = false
        addSubview(screenView)

        screenHint.text = "大屏"
        screenHint.font = .systemFont(ofSize: 10.5)
        screenHint.textColor = UIColor.white.withAlphaComponent(0.30)
        screenHint.textAlignment = .center
        screenHint.isUserInteractionEnabled = false
        addSubview(screenHint)

        screenView.isHidden = true
        screenHint.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setAbsoluteMode(_ on: Bool) {
        // 只有「点触」模式才显示那块大屏框；普通模式恢复成整块触控板
        screenView.isHidden = !on
        screenHint.isHidden = !on
        screenView.layer.borderColor = on
            ? UIColor.systemBlue.withAlphaComponent(0.9).cgColor
            : UIColor.white.withAlphaComponent(0.12).cgColor
        screenView.layer.borderWidth = on ? 2 : 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 8
        let available = bounds.insetBy(dx: inset, dy: inset)
        var width = available.width
        var height = width / max(screenAspect, 0.1)
        if height > available.height {
            height = available.height
            width = height * screenAspect
        }
        screenFrame = CGRect(x: available.midX - width / 2,
                             y: available.midY - height / 2,
                             width: width, height: height)
        screenView.frame = screenFrame
        screenHint.frame = CGRect(x: screenFrame.minX + 8, y: screenFrame.minY + 6,
                                  width: screenFrame.width - 16, height: 14)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        if active { return }
        active = true
        moved = false
        last = point
        start = point
        multi = (event?.allTouches?.count ?? 1) >= 2
        if !multi {
            onBegin?(point)
            // 按住不动 0.22 秒 → 开始拖窗口（避免普通滑动误拖）
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.active, !self.moved, !self.multi else { return }
                self.onHold?()
            }
            holdWork?.cancel()
            holdWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let fingers = event?.allTouches?.count ?? 1

        if fingers >= 2 || multi {
            multi = true
            holdWork?.cancel()
            onScroll?(point.y - last.y)
            last = point
            return
        }

        let delta = CGPoint(x: point.x - last.x, y: point.y - last.y)
        last = point
        if hypot(point.x - start.x, point.y - start.y) > 5 {
            moved = true
            holdWork?.cancel()
        }
        onMove?(point, delta)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            holdWork?.cancel()
            onEnd?(.zero)
            finish()
            return
        }
        let point = touch.location(in: self)
        let tapped = active && !moved && !multi
        let twoFingerTap = active && !moved && multi
        holdWork?.cancel()
        finish()
        onEnd?(point)
        if tapped { onTap?(point) }
        if twoFingerTap { onTwoFingerTap?() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdWork?.cancel()
        onEnd?(.zero)
        finish()
    }

    private func finish() {
        active = false
    }
}
