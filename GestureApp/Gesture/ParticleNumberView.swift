import UIKit
import CoreText
import SwiftUI

/// 粒子数字：平时散开飘动，识别到手指数时汇聚成数字轮廓
final class ParticleNumberView: UIView {

    private struct Particle {
        var x: Float = 0
        var y: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        var targetX: Float = 0
        var targetY: Float = 0
        var size: Float = 2
        var seed: Float = 0
        var attracted: Bool = false
    }

    private var particles: [Particle] = []
    private let particleCount = 1400

    private var digit: Int = -1
    private var targets: [CGPoint] = []
    private var cache: [Int: [CGPoint]] = [:]

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var time: Float = 0
    private var bitmap: CGContext?

    private let neon = UIColor(red: 0.45, green: 1.0, blue: 0.85, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        seed()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        link?.invalidate()
    }

    // MARK: - 初始化

    private func seed() {
        var list: [Particle] = []
        list.reserveCapacity(particleCount)
        for _ in 0..<particleCount {
            var p = Particle()
            p.x = Float.random(in: -0.55...0.55)
            p.y = Float.random(in: -0.55...0.55)
            p.vx = Float.random(in: -0.05...0.05)
            p.vy = Float.random(in: -0.05...0.05)
            p.size = Float.random(in: 1.1...2.6)
            p.seed = Float.random(in: 0...(2 * .pi))
            list.append(p)
        }
        particles = list
    }

    // MARK: - 对外

    func setDigit(_ value: Int) {
        guard value != digit else { return }
        digit = value

        if value < 0 {
            disperse()
            return
        }

        let points = outlinePoints(for: value)
        guard !points.isEmpty else { return }
        targets = points

        // 先向外炸一下，再汇聚，看起来更有"重组"的感觉
        for i in particles.indices {
            particles[i].vx += Float.random(in: -1.4...1.4)
            particles[i].vy += Float.random(in: -1.4...1.4)
            let index = Int.random(in: 0..<targets.count)
            let jitter = Float(0.004)
            particles[i].targetX = Float(targets[index].x) + Float.random(in: -jitter...jitter)
            particles[i].targetY = Float(targets[index].y) + Float.random(in: -jitter...jitter)
            particles[i].attracted = true
        }
    }

    private func disperse() {
        for i in particles.indices {
            particles[i].attracted = false
            particles[i].vx += Float.random(in: -0.6...0.6)
            particles[i].vy += Float.random(in: -0.6...0.6)
        }
    }

    // MARK: - 生命周期

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
            return
        }
        guard link == nil else { return }
        let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
        display.preferredFramesPerSecond = 60
        display.add(to: .main, forMode: .common)
        link = display
        lastTime = 0
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
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        bitmap = ctx
    }

    @objc private func tick(_ display: CADisplayLink) {
        let dt: Float
        if lastTime == 0 {
            dt = 0.016
        } else {
            dt = Float(min(0.05, display.timestamp - lastTime))
        }
        lastTime = display.timestamp

        time += dt
        step(dt)
        render()
    }

    // MARK: - 物理

    private func step(_ dt: Float) {
        let damping: Float = 5.6
        let pull: Float = 26.0

        for i in particles.indices {
            var p = particles[i]

            if p.attracted {
                let ax = (p.targetX - p.x) * pull
                let ay = (p.targetY - p.y) * pull
                p.vx += ax * dt
                p.vy += ay * dt
                p.vx *= (1 - damping * dt)
                p.vy *= (1 - damping * dt)
                // 轻微呼吸抖动，别像死图
                p.vx += sin(time * 2 + p.seed) * 0.006
                p.vy += cos(time * 1.7 + p.seed) * 0.006
            } else {
                p.vx += sin(time * 0.6 + p.seed) * 0.03
                p.vy += cos(time * 0.5 + p.seed * 1.3) * 0.03
                p.vx *= (1 - 0.6 * dt)
                p.vy *= (1 - 0.6 * dt)
            }

            p.x += p.vx * dt
            p.y += p.vy * dt

            if p.x < -0.75 { p.x = -0.75; p.vx = abs(p.vx) }
            if p.x > 0.75 { p.x = 0.75; p.vx = -abs(p.vx) }
            if p.y < -0.75 { p.y = -0.75; p.vy = abs(p.vy) }
            if p.y > 0.75 { p.y = 0.75; p.vy = -abs(p.vy) }

            particles[i] = p
        }
    }

    private func render() {
        guard let ctx = bitmap, bounds.width > 8 else { return }

        let w = bounds.width
        let h = bounds.height
        let side = min(w, h) * 0.78
        let cx = w * 0.5
        let cy = h * 0.5

        ctx.setBlendMode(.normal)
        ctx.setFillColor(UIColor(white: 0, alpha: 0.22).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        ctx.setBlendMode(.plusLighter)

        for p in particles {
            let x = cx + CGFloat(p.x) * side
            let y = cy - CGFloat(p.y) * side
            let s = CGFloat(p.size)
            let alpha: CGFloat = p.attracted ? 0.95 : 0.55

            if p.attracted {
                ctx.setFillColor(neon.withAlphaComponent(alpha).cgColor)
            } else {
                ctx.setFillColor(UIColor(red: 0.30, green: 0.85, blue: 0.75, alpha: alpha).cgColor)
            }
            ctx.fillEllipse(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
        }

        ctx.setBlendMode(.normal)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let image = bitmap?.makeImage() else { return }
        ctx.draw(image, in: bounds)
    }

    // MARK: - 字形轮廓采样

    private func outlinePoints(for value: Int) -> [CGPoint] {
        if let cached = cache[value], !cached.isEmpty {
            return cached
        }

        let font = UIFont.systemFont(ofSize: 220, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributed = NSAttributedString(string: "\(value)", attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)

        var raw: [CGPoint] = []

        let runs = CTLineGetGlyphRuns(line) as NSArray

        for case let run as CTRun in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }

            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)

            let runAttributes = CTRunGetAttributes(run) as NSDictionary
            guard runAttributes[kCTFontAttributeName] != nil else { continue }
            let runFont = runAttributes[kCTFontAttributeName] as! CTFont

            for i in 0..<count {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }

                let offset = positions[i]
                var current = CGPoint.zero

                glyphPath.applyWithBlock { element in
                    let e = element.pointee
                    switch e.type {
                    case .moveToPoint:
                        current = e.points[0]
                    case .addLineToPoint:
                        let p = e.points[0]
                        appendLine(current, p, offset: offset, into: &raw)
                        current = p
                    case .addQuadCurveToPoint:
                        let c = e.points[0]
                        let p = e.points[1]
                        appendQuad(current, c, p, offset: offset, into: &raw)
                        current = p
                    case .addCurveToPoint:
                        let c1 = e.points[0]
                        let c2 = e.points[1]
                        let p = e.points[2]
                        appendCubic(current, c1, c2, p, offset: offset, into: &raw)
                        current = p
                    default:
                        break
                    }
                }
            }
        }

        guard !raw.isEmpty else { return [] }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for p in raw {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }

        let width = max(1, maxX - minX)
        let height = max(1, maxY - minY)
        let scale = 1.0 / max(width, height)

        let centerX = (minX + maxX) * 0.5
        let centerY = (minY + maxY) * 0.5

        let normalized = raw.map { p -> CGPoint in
            CGPoint(x: (p.x - centerX) * scale, y: (p.y - centerY) * scale)
        }

        cache[value] = normalized
        return normalized
    }

    private func appendLine(_ a: CGPoint, _ b: CGPoint, offset: CGPoint, into pts: inout [CGPoint]) {
        let length = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int(length / 2.4))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            pts.append(CGPoint(x: a.x + (b.x - a.x) * t + offset.x,
                               y: a.y + (b.y - a.y) * t + offset.y))
        }
    }

    private func appendQuad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, offset: CGPoint, into pts: inout [CGPoint]) {
        let approx = hypot(b.x - a.x, b.y - a.y) + hypot(c.x - a.x, c.y - a.y)
        let steps = max(6, Int(approx / 2.4))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * a.x + 2 * mt * t * c.x + t * t * b.x
            let y = mt * mt * a.y + 2 * mt * t * c.y + t * t * b.y
            pts.append(CGPoint(x: x + offset.x, y: y + offset.y))
        }
    }

    private func appendCubic(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, offset: CGPoint, into pts: inout [CGPoint]) {
        let approx = hypot(b.x - a.x, b.y - a.y) + hypot(c1.x - a.x, c1.y - a.y) + hypot(c2.x - b.x, c2.y - b.y)
        let steps = max(8, Int(approx / 2.4))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * mt * a.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * b.x
            let y = mt * mt * mt * a.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * b.y
            pts.append(CGPoint(x: x + offset.x, y: y + offset.y))
        }
    }
}

struct ParticleNumber: UIViewRepresentable {
    let digit: Int

    func makeUIView(context: Context) -> ParticleNumberView {
        ParticleNumberView()
    }

    func updateUIView(_ uiView: ParticleNumberView, context: Context) {
        uiView.setDigit(digit)
    }
}
