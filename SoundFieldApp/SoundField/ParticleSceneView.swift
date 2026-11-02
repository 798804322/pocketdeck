import UIKit

/// 粒子星云：随声音呼吸、旋转、炸开
final class ParticleSceneView: UIView {

    private struct Particle {
        var angle: Float
        var radius: Float
        var baseRadius: Float
        var speed: Float
        var size: Float
        var hue: Float
    }

    private var particles: [Particle] = []
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var bitmap: CGContext?

    private let particleCount = 900

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        seed()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - 初始化粒子

    private func seed() {
        var list: [Particle] = []
        list.reserveCapacity(particleCount)

        for i in 0..<particleCount {
            let base = Float.random(in: 0.05...0.50)
            let speed = Float.random(in: 0.04...0.30) * (i % 2 == 0 ? 1 : -1)
            let hue = Float.random(in: 0.50...0.76)
            list.append(Particle(angle: Float.random(in: 0...(2 * .pi)),
                                 radius: base,
                                 baseRadius: base,
                                 speed: speed,
                                 size: Float.random(in: 1.1...3.2),
                                 hue: hue))
        }
        particles = list
    }

    // MARK: - 生命周期

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFramesPerSecond = 60
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTime = 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        makeBitmap()
    }

    private func makeBitmap() {
        let w = Int(bounds.width)
        let h = Int(bounds.height)
        guard w > 8, h > 8 else { return }

        guard let ctx = CGContext(data: nil,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return
        }

        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        bitmap = ctx
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt: Float
        if lastTime == 0 {
            dt = 0.016
        } else {
            dt = Float(min(0.05, link.timestamp - lastTime))
        }
        lastTime = link.timestamp
        step(dt)
        render()
    }

    // MARK: - 物理

    private func step(_ dt: Float) {
        let audio = AudioLevels.shared
        let bass = audio.bass
        let mid = audio.mid
        let treble = audio.treble

        for i in 0..<particles.count {
            var p = particles[i]

            p.angle += (p.speed + mid * 1.8) * dt
            p.radius += (p.baseRadius - p.radius) * min(1, 2.4 * dt)
            p.radius += bass * 0.62 * dt * (0.35 + p.baseRadius)

            if treble > 0.08 {
                p.radius += Float.random(in: -0.012...0.012) * treble
            }

            if p.radius < 0.02 { p.radius = 0.02 }
            if p.radius > 1.7 { p.radius = 1.7 }

            p.hue += treble * 0.02 - 0.003 * dt
            if p.hue > 0.78 { p.hue = 0.50 }
            if p.hue < 0.50 { p.hue = 0.78 }

            particles[i] = p
        }
    }

    // MARK: - 绘制

    private func render() {
        guard let ctx = bitmap, bounds.width > 8 else { return }

        let w = bounds.width
        let h = bounds.height
        let audio = AudioLevels.shared
        let treble = CGFloat(audio.treble)
        let level = CGFloat(audio.level)

        // 拖尾：每帧盖一层半透明黑
        ctx.setBlendMode(.normal)
        ctx.setFillColor(UIColor(white: 0, alpha: 0.16).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        ctx.setBlendMode(.plusLighter)

        let cx = w * 0.5
        let cy = h * 0.5
        let maxR = min(w, h) * 0.52

        for p in particles {
            let r = CGFloat(p.radius) * maxR * (1 + level * 0.22)
            let x = cx + cos(CGFloat(p.angle)) * r
            let y = cy + sin(CGFloat(p.angle)) * r
            let s = CGFloat(p.size) * (1 + treble * 1.3)
            let alpha = 0.20 + treble * 0.55

            let color = UIColor(hue: CGFloat(p.hue),
                                saturation: 0.72,
                                brightness: 1.0,
                                alpha: min(0.9, alpha))
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: x - s * 0.5, y: y - s * 0.5, width: s, height: s))
        }

        // 中心光核
        let coreR = min(w, h) * (0.04 + level * 0.07)
        let coreColors = [UIColor.white.withAlphaComponent(0.28).cgColor,
                          UIColor.clear.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: coreColors,
                                     locations: [0, 1]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: cx, y: cy),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: cx, y: cy),
                                   endRadius: max(10, coreR * 3.2))
        }

        ctx.setBlendMode(.normal)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let image = bitmap?.makeImage() else { return }
        ctx.draw(image, in: bounds)
    }
}
