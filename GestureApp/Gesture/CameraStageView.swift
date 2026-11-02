import UIKit
import AVFoundation
import SwiftUI

/// 荧光骨架层
final class SkeletonLayerView: UIView {

    weak var preview: AVCaptureVideoPreviewLayer?
    private var points: [CGPoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ newPoints: [CGPoint]) {
        points = newPoints
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let preview, points.count == 21, let ctx = UIGraphicsGetCurrentContext() else { return }

        var mapped: [CGPoint] = []
        mapped.reserveCapacity(21)
        for point in points {
            if point.x < 0 || point.y < 0 {
                mapped.append(CGPoint(x: -1000, y: -1000))
                continue
            }
            let device = CGPoint(x: point.x, y: 1 - point.y)
            mapped.append(preview.layerPointConverted(fromCaptureDevicePoint: device))
        }

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.setStrokeColor(UIColor(red: 0.2, green: 1.0, blue: 0.7, alpha: 0.22).cgColor)
        ctx.setLineWidth(10)
        strokeBones(ctx, mapped)

        ctx.setStrokeColor(UIColor(red: 0.42, green: 1.0, blue: 0.82, alpha: 0.95).cgColor)
        ctx.setLineWidth(2.4)
        strokeBones(ctx, mapped)

        let tips = [4, 8, 12, 16, 20]
        for (index, point) in mapped.enumerated() {
            if point.x < -500 { continue }
            let isTip = tips.contains(index)
            let radius: CGFloat = isTip ? 5.6 : 3.0
            let frame = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)

            if isTip {
                ctx.setFillColor(UIColor.white.cgColor)
            } else {
                ctx.setFillColor(UIColor(red: 0.65, green: 1.0, blue: 0.88, alpha: 1).cgColor)
            }
            ctx.fillEllipse(in: frame)
        }
    }

    private func strokeBones(_ ctx: CGContext, _ points: [CGPoint]) {
        ctx.beginPath()
        for (a, b) in HandJoint.bones {
            let p1 = points[a]
            let p2 = points[b]
            if p1.x < -500 || p2.x < -500 { continue }
            ctx.move(to: p1)
            ctx.addLine(to: p2)
        }
        ctx.strokePath()
    }
}

/// 摄像头预览 + 骨架叠加
final class CameraStageView: UIView {

    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let skeleton = SkeletonLayerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        addSubview(skeleton)
        skeleton.preview = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(_ session: AVCaptureSession) {
        previewLayer.session = session
        applyPreviewOrientation()
    }

    func update(points: [CGPoint]) {
        skeleton.apply(points)
    }

    private func applyPreviewOrientation() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()

        skeleton.frame = bounds
        applyPreviewOrientation()
    }
}

struct CameraStage: UIViewRepresentable {

    let tracker: HandTracker

    func makeUIView(context: Context) -> CameraStageView {
        let view = CameraStageView()
        view.attach(tracker.session)
        tracker.onPoints = { [weak view] points in
            view?.update(points: points)
        }
        return view
    }

    func updateUIView(_ uiView: CameraStageView, context: Context) {}
}
