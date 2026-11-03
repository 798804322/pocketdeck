import UIKit
import CoreText
import SwiftUI

/// 全屏粒子：平时散在整屏乱飘；识别到数字时汇聚成数字轮廓
final class ParticleNumberView: UIView {

    private struct Particle {
        var x: Float = 0
        var y: Float = 0
        var vx: Float = 0
        var vy: Float = 0
        /// 字形上的归一化偏移（-1~1）；真正目标 = 跟手的中心 + 偏移 × 字号
        var ox: Float = 0
        var oy: Float = 0
        /// 光球模式下每颗粒子在圆盘里的角度和半径比例
        var orbA: Float = 0
        var orbR: Float = 0
        var size: Float = 2
        var seed: Float = 0
        var looseness: Float = 0
        var attracted: Bool = false
    }

    private var particles: [Particle] = []
    private let particleCount = 2600

    private var digit: Int = -1
    private var cache: [Int: [CGPoint]] = [:]

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var time: Float = 0
    private var bitmap: CGContext?

    /// 字形中心（相对屏幕中心）。手一动，它就追过去
    private var anchorX: Float = 0
    private var anchorY: Float = 0
    private var targetX: Float = 0
    private var targetY: Float = 0
    private var anchored = false
    private var digitSide: Float = 0

    /// 握拳：粒子收成一团亮球
    private var orbMode = false
    private var orbRadius: Float = 0

    private let neon = UIColor(red: 0.45, green: 1.0, blue: 0.85, alpha: 1)

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
        link?.invalidate()
    }

    private var halfW: Float {
        Float(max(1, bounds.width)) * 0.5
    }

    private var halfH: Float {
        Float(max(1, bounds.height)) * 0.5
    }

    /// 数字字形的字号（沿用原来的取法）
    private var sideForBounds: Float {
        Float(min(bounds.height * 0.66, bounds.width * 1.24))
    }

    /// 亮球半径
    private var orbRadiusForBounds: Float {
        Float(min(bounds.width, bounds.height)) * 0.11
    }

    // MARK: - 初始化

    private func seed() {
        let hw = halfW
        let hh = halfH
        var list: [Particle] = []
        list.reserveCapacity(particleCount)

        for _ in 0..<particleCount {
            var p = Particle()
            p.x = Float.random(in: -hw...hw)
            p.y = Float.random(in: -hh...hh)
            p.vx = Float.random(in: -26...26)
            p.vy = Float.random(in: -26...26)
            p.size = Float.random(in: 0.9...2.4)
            p.seed = Float.random(in: 0...(2 * .pi))
            p.looseness = Float.random(in: 0...1)
            list.append(p)
        }
        particles = list
    }

    /// 屏幕尺寸变化时把越界的粒子拉回来
    private func reseedIfNeeded() {
        let hw = halfW
        let hh = halfH
        for i in particles.indices {
            if abs(particles[i].x) > hw { particles[i].x = Float.random(in: -hw...hw) }
            if abs(particles[i].y) > hh { particles[i].y = Float.random(in: -hh...hh) }
        }
    }

    // MARK: - 对外

    func setDigit(_ value: Int) {
        guard value != digit else { return }
        digit = value

        if value < 0 {
            for i in particles.indices {
                particles[i].attracted = false
            }
            return
        }

        let outline = outlinePoints(for: value)
        guard !outline.isEmpty else { return }

        digitSide = sideForBounds
        clampTarget()

        // 第一次拿到手的位置就直接落位，后面全靠弹簧自己追
        if !anchored {
            anchorX = targetX
            anchorY = targetY
            anchored = true
        }

        let shuffled = outline.shuffled()

        for i in particles.indices {
            let point = shuffled[i % shuffled.count]
            // 先向外炸一下，再收拢，重组感更强
            particles[i].vx += Float.random(in: -180...180)
            particles[i].vy += Float.random(in: -180...180)
            particles[i].ox = Float(point.x)
            particles[i].oy = -Float(point.y)
            particles[i].attracted = true
        }
    }

    /// 握拳：所有粒子吸到掌心缩成一个会呼吸的亮球。传 false 会让它们回到字形（或散开）
    func setOrb(_ on: Bool) {
        guard on != orbMode else { return }
        orbMode = on
        orbRadius = orbRadiusForBounds

        if on {
            for i in particles.indices {
                // 圆盘里均匀撒点：半径取平方根才是均匀分布，否则全挤在圆心
                particles[i].orbA = Float.random(in: 0...(2 * Float.pi))
                particles[i].orbR = Float.random(in: 0...1).squareRoot()
                particles[i].vx += Float.random(in: -140...140)
                particles[i].vy += Float.random(in: -140...140)
                particles[i].attracted = true
            }
        } else if digit < 0 {
            // 既没有数字也没有球：回到散开状态
            for i in particles.indices {
                particles[i].attracted = false
            }
        }
        // digit >= 0 时不用管：目标会自动切回字形，粒子自己飞回去
    }

    /// 手掌中心，Vision 归一化坐标（左下角原点）。传 nil 表示这一帧没看到手：保留上次位置，不炸开
    func setHandCenter(_ p: CGPoint?) {
        guard let p = p else { return }
        let w = Float(max(1, bounds.width))
        let h = Float(max(1, bounds.height))

        // 前置摄像头是"照镜子"的，x 翻一下才符合直觉：手往右移，数字往右移
        let sx = Float(1 - p.x)
        let sy = Float(1 - p.y)

        targetX = (sx - 0.5) * w
        targetY = (sy - 0.5) * h
        clampTarget()

        if !anchored {
            anchorX = targetX
            anchorY = targetY
            anchored = true
        }
    }

    /// 别让字形跑出屏幕：按字形半径留边
    private func clampTarget() {
        let w = Float(max(1, bounds.width))
        let h = Float(max(1, bounds.height))
        let margin = digitSide * 0.6 + 8
        let mx = max(0, w * 0.5 - margin)
        let my = max(0, h * 0.5 - margin)
        targetX = min(mx, max(-mx, targetX))
        targetY = min(my, max(-my, targetY))
    }

    /// 从 21 个关节点里取手掌中心（手腕 + 四个掌指关节的平均），比取指尖稳
    private func handleHand(_ points: [CGPoint]) {
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var n: CGFloat = 0

        for index in [0, 5, 9, 13, 17] where index < points.count {
            let p = points[index]
            if p.x < 0 || p.y < 0 { continue }
            sumX += p.x
            sumY += p.y
            n += 1
        }

        guard n > 0 else { return }
        setHandCenter(CGPoint(x: sumX / n, y: sumY / n))
    }

    // MARK: - 生命周期

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
            HandTracker.shared.onPoints = nil
            return
        }

        HandTracker.shared.onPoints = { [weak self] points in
            self?.handleHand(points)
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
        reseedIfNeeded()
        if digit >= 0 {
            digitSide = sideForBounds
            clampTarget()
        }
        orbRadius = orbRadiusForBounds
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
        let hw = halfW - 4
        let hh = halfH - 4
        let damping: Float = 6.2

        // 字形中心平滑追手：手抖不会直接传给粒子，但手一动它会跟过去
        let follow = min(1, dt * 9)
        anchorX += (targetX - anchorX) * follow
        anchorY += (targetY - anchorY) * follow

        let side = digitSide

        for i in particles.indices {
            var p = particles[i]

            if p.attracted {
                let tx: Float
                let ty: Float
                let pull: Float
                let jitter: Float
                let drag: Float

                if orbMode {
                    // 握拳：全部吸到掌心，缩成一个会转的球
                    let radius = orbRadius * (0.3 + p.orbR * 0.7)
                    let spin = p.orbA + time * 1.6
                    tx = anchorX + cos(spin) * radius
                    ty = anchorY + sin(spin) * radius
                    pull = 110
                    jitter = 6
                    drag = 12
                } else {
                    // 数字：松散的粒子不完全归位，形成"毛边"，看起来更乱更活
                    let wobble = p.looseness * 26
                    tx = anchorX + p.ox * side + sin(time * 1.7 + p.seed) * wobble
                    ty = anchorY + p.oy * side + cos(time * 1.4 + p.seed * 1.3) * wobble
                    pull = 26 - p.looseness * 14
                    jitter = 22
                    drag = damping
                }

                p.vx += (tx - p.x) * pull * dt
                p.vy += (ty - p.y) * pull * dt

                p.vx += sin(time * 3.1 + p.seed * 2) * jitter * dt * (0.4 + p.looseness)
                p.vy += cos(time * 2.7 + p.seed) * jitter * dt * (0.4 + p.looseness)

                p.vx *= (1 - drag * dt)
                p.vy *= (1 - drag * dt)
            } else {
                // 没识别到手：每颗粒子有自己的漂移方向 + 两层不同频率的湍流，越飘越散
                let driftX = sin(p.seed * 7.3)
                let driftY = cos(p.seed * 5.9)

                let f1 = sin(time * (0.8 + p.looseness * 0.9) + p.seed)
                let f2 = cos(time * (2.4 + p.looseness * 1.8) + p.seed * 2.1)
                let g1 = cos(time * (0.7 + p.looseness * 0.8) + p.seed * 1.7)
                let g2 = sin(time * (2.1 + p.looseness * 1.5) + p.seed * 3.1)

                p.vx += (f1 * 130 + f2 * 55 + driftX * 45) * dt
                p.vy += (g1 * 130 + g2 * 55 + driftY * 45) * dt

                // 阻尼从 0.9 降到 0.55：飘得更远、停不下来
                p.vx *= (1 - 0.55 * dt)
                p.vy *= (1 - 0.55 * dt)
            }

            p.x += p.vx * dt
            p.y += p.vy * dt

            if p.x < -hw { p.x = -hw; p.vx = abs(p.vx) * 0.6 }
            if p.x > hw { p.x = hw; p.vx = -abs(p.vx) * 0.6 }
            if p.y < -hh { p.y = -hh; p.vy = abs(p.vy) * 0.6 }
            if p.y > hh { p.y = hh; p.vy = -abs(p.vy) * 0.6 }

            particles[i] = p
        }
    }

    private func render() {
        guard let ctx = bitmap, bounds.width > 8 else { return }

        let w = bounds.width
        let h = bounds.height
        let cx = w * 0.5
        let cy = h * 0.5

        ctx.setBlendMode(.normal)
        ctx.setFillColor(UIColor(white: 0, alpha: 0.26).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        ctx.setBlendMode(.plusLighter)

        // 握拳时先铺一层会呼吸的光晕，粒子压上去才像"大亮点"
        if orbMode {
            let center = CGPoint(x: cx + CGFloat(anchorX), y: cy + CGFloat(anchorY))
            let pulse = CGFloat(1 + 0.08 * sin(time * 3.4))
            let radius = CGFloat(orbRadius) * 2.4 * pulse
            let colors = [neon.withAlphaComponent(0.5).cgColor,
                          neon.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: [0, 1]) {
                ctx.drawRadialGradient(gradient,
                                       startCenter: center,
                                       startRadius: 0,
                                       endCenter: center,
                                       endRadius: radius,
                                       options: [])
            }
        }

        for p in particles {
            let x = cx + CGFloat(p.x)
            let y = cy + CGFloat(p.y)
            let base = CGFloat(p.size)

            if p.attracted {
                let size = base * (orbMode ? CGFloat(1.3 + p.looseness * 0.9) : 1)
                ctx.setFillColor(neon.withAlphaComponent(orbMode ? 1 : 0.95).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size))
            } else {
                // 散开状态：大小差得更开、每颗自己闪，看起来更杂
                let size = base * CGFloat(0.55 + p.looseness * 1.35)
                let twinkle = abs(sin(time * (0.6 + p.looseness * 1.3) + p.seed))
                let alpha = CGFloat(0.12 + 0.40 * twinkle)

                ctx.setFillColor(UIColor(red: 0.28, green: 0.82, blue: 0.72, alpha: alpha).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size))
            }
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
        let steps = max(1, Int(length / 3.0))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            pts.append(CGPoint(x: a.x + (b.x - a.x) * t + offset.x,
                               y: a.y + (b.y - a.y) * t + offset.y))
        }
    }

    private func appendQuad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, offset: CGPoint, into pts: inout [CGPoint]) {
        let approx = hypot(b.x - a.x, b.y - a.y) + hypot(c.x - a.x, c.y - a.y)
        let steps = max(5, Int(approx / 3.0))
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
        let steps = max(6, Int(approx / 3.0))
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
    let orb: Bool

    func makeUIView(context: Context) -> ParticleNumberView {
        ParticleNumberView()
    }

    func updateUIView(_ uiView: ParticleNumberView, context: Context) {
        uiView.setOrb(orb)
        uiView.setDigit(digit)
    }
}
