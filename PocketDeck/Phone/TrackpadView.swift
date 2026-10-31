import UIKit

/// 手机上的触控板
final class TrackpadView: UIView {

    var onMove: ((CGPoint) -> Void)?
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.045)
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        isMultipleTouchEnabled = false

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let hint = UILabel()
        hint.text = "滑动移动光标 · 轻点单击"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = UIColor.white.withAlphaComponent(0.28)
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

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        onMove?(translation)
    }

    @objc private func handleTap() {
        onTap?()
    }
}
