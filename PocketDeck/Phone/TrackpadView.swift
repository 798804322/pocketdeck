import UIKit

/// 手机触控板：单指移动光标 / 双指滚动 / 轻点单击 / 按住拖动窗口 / 绝对点触
final class TrackpadView: UIView {

    var onBegin: ((CGPoint) -> Void)?
    var onMove: ((CGPoint, CGPoint) -> Void)?
    var onEnd: ((CGPoint) -> Void)?
    var onTap: ((CGPoint) -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var last: CGPoint = .zero
    private var start: CGPoint = .zero
    private var active = false
    private var moved = false
    private var multi = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.045)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        isMultipleTouchEnabled = true

        let hint = UILabel()
        hint.text = "滑动移光标 · 轻点单击 · 双指滚动"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = UIColor.white.withAlphaComponent(0.26)
        hint.textAlignment = .center
        hint.isUserInteractionEnabled = false
        hint.tag = 77
        addSubview(hint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        viewWithTag(77)?.frame = CGRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
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
        if !multi { onBegin?(point) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let fingers = event?.allTouches?.count ?? 1

        if fingers >= 2 || multi {
            multi = true
            onScroll?(last.y - point.y)
            last = point
            return
        }

        let delta = CGPoint(x: point.x - last.x, y: point.y - last.y)
        last = point
        if hypot(point.x - start.x, point.y - start.y) > 5 { moved = true }
        onMove?(point, delta)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { finish() ; return }
        let point = touch.location(in: self)
        let tapped = active && !moved && !multi
        finish()
        onEnd?(point)
        if tapped { onTap?(point) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish()
    }

    private func finish() {
        active = false
    }
}
