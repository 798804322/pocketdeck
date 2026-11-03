import Foundation
import AVFoundation
import Vision
import Combine
import UIKit

/// 手部 21 个关节，顺序固定（和绘制时的连线表对应）
enum HandJoint: Int, CaseIterable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip

    var vnName: VNHumanHandPoseObservation.JointName {
        switch self {
        case .wrist:      return .wrist
        case .thumbCMC:   return .thumbCMC
        case .thumbMP:    return .thumbMP
        case .thumbIP:    return .thumbIP
        case .thumbTip:   return .thumbTip
        case .indexMCP:   return .indexMCP
        case .indexPIP:   return .indexPIP
        case .indexDIP:   return .indexDIP
        case .indexTip:   return .indexTip
        case .middleMCP:  return .middleMCP
        case .middlePIP:  return .middlePIP
        case .middleDIP:  return .middleDIP
        case .middleTip:  return .middleTip
        case .ringMCP:    return .ringMCP
        case .ringPIP:    return .ringPIP
        case .ringDIP:    return .ringDIP
        case .ringTip:    return .ringTip
        case .littleMCP:  return .littleMCP
        case .littlePIP:  return .littlePIP
        case .littleDIP:  return .littleDIP
        case .littleTip:  return .littleTip
        }
    }

    /// 骨架连线（索引对）
    static let bones: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (0, 9), (9, 10), (10, 11), (11, 12),
        (0, 13), (13, 14), (14, 15), (15, 16),
        (0, 17), (17, 18), (18, 19), (19, 20),
        (5, 9), (9, 13), (13, 17)
    ]
}

final class HandTracker: NSObject, ObservableObject {

    static let shared = HandTracker()

    @Published var fingerCount: Int = -1
    @Published var denied = false
    @Published var running = false

    let session = AVCaptureSession()

    /// 归一化关节坐标（Vision 坐标：左下角原点），在识别线程里产生
    var onPoints: (([CGPoint]) -> Void)?

    private let queue = DispatchQueue(label: "pocketdeck.hand")
    private var configured = false
    private var lastStable = -1
    private var stableCounter = 0

    /// 手在画面里小于这个尺寸（离得太远）就当作没看到，避免瞎猜
    private let minHandScale: CGFloat = 0.06

    private override init() {
        super.init()
    }

    func start() {
        guard !configured else {
            if !session.isRunning {
                queue.async { self.session.startRunning() }
            }
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.denied = true }
                return
            }
            DispatchQueue.main.async { self.configure() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        // 只让数据流保持"不镜像"，预览层单独镜像，坐标换算才不会翻两次
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()

        let sessionRef = session
        queue.async {
            sessionRef.startRunning()
        }
        configured = true
        running = true
    }
}

extension HandTracker: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            publish(points: nil, count: -1)
            return
        }

        guard let observation = request.results?.first else {
            publish(points: nil, count: -1)
            return
        }

        guard let recognized = try? observation.recognizedPoints(.all) else {
            publish(points: nil, count: -1)
            return
        }

        var points: [CGPoint] = []
        points.reserveCapacity(21)
        for joint in HandJoint.allCases {
            if let point = recognized[joint.vnName], point.confidence > 0.25 {
                points.append(CGPoint(x: point.location.x, y: point.location.y))
            } else {
                points.append(CGPoint(x: -1, y: -1))
            }
        }

        // 手太小（离得太远）时关节噪声比手指还大，直接不认，比猜错干净
        let palm = palmScale(points)
        if palm > 0 && palm < minHandScale {
            publish(points: nil, count: -1)
            return
        }

        let count = countFingers(recognized)
        publish(points: points, count: count)
    }

    /// 腕到中指掌指关节的距离，当"手有多大"的尺子
    private func palmScale(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 9 else { return 0 }
        let wrist = points[0]
        let mcp = points[9]
        guard wrist.x >= 0, wrist.y >= 0, mcp.x >= 0, mcp.y >= 0 else { return 0 }
        let dx = wrist.x - mcp.x
        let dy = wrist.y - mcp.y
        return sqrt(dx * dx + dy * dy)
    }

    private func publish(points: [CGPoint]?, count: Int) {
        // 防抖：连续 4 帧结果一致才更新
        if count == lastStable {
            stableCounter += 1
        } else {
            lastStable = count
            stableCounter = 1
        }

        let stable = stableCounter >= 4 ? count : nil

        DispatchQueue.main.async {
            if let points {
                self.onPoints?(points)
            } else {
                self.onPoints?([])
            }
            if let stable, stable != self.fingerCount {
                self.fingerCount = stable
            }
        }
    }

    private func countFingers(_ points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]) -> Int {
        func location(_ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let point = points[name], point.confidence > 0.28 else { return nil }
            return point.location
        }

        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = a.x - b.x
            let dy = a.y - b.y
            return sqrt(dx * dx + dy * dy)
        }

        /// 三点夹角，顶点是 b，返回 0~180
        func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            let v1x = Double(a.x - b.x), v1y = Double(a.y - b.y)
            let v2x = Double(c.x - b.x), v2y = Double(c.y - b.y)
            let l1 = (v1x * v1x + v1y * v1y).squareRoot()
            let l2 = (v2x * v2x + v2y * v2y).squareRoot()
            guard l1 > 0.0001, l2 > 0.0001 else { return 0 }
            let cosv = max(-1.0, min(1.0, (v1x * v2x + v1y * v2y) / (l1 * l2)))
            return CGFloat(acos(cosv) * 180 / Double.pi)
        }

        guard let wrist = location(.wrist) else { return -1 }

        // 手掌尺寸：腕到掌指关节的距离。所有阈值都按它归一化，
        // 手离得远、手变小时不会被关节噪声放大
        guard let scaleRef = location(.middleMCP) ?? location(.indexMCP) ?? location(.ringMCP) else { return -1 }
        let scale = distance(wrist, scaleRef)
        guard scale > 0.01 else { return -1 }

        // 手越小（离得越远）噪声占比越高，阈值收紧一点
        let strictness: CGFloat = scale < 0.15 ? 0.02 : 0

        var count = 0

        let fingers: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName,
                       VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexMCP, .indexPIP, .indexDIP, .indexTip),
            (.middleMCP, .middlePIP, .middleDIP, .middleTip),
            (.ringMCP, .ringPIP, .ringDIP, .ringTip),
            (.littleMCP, .littlePIP, .littleDIP, .littleTip)
        ]

        for (mcpName, pipName, dipName, tipName) in fingers {
            guard let mcp = location(mcpName), let pip = location(pipName),
                  let tip = location(tipName) else { continue }

            // DIP 缺失时退回三点判定，别因为少一个关节就把整根手指丢掉
            let chain: CGFloat
            let jointAngle: CGFloat
            if let dip = location(dipName) {
                chain = distance(mcp, pip) + distance(pip, dip) + distance(dip, tip)
                jointAngle = angle(mcp, pip, dip)
            } else {
                chain = distance(mcp, pip) + distance(pip, tip)
                jointAngle = angle(mcp, pip, tip)
            }
            guard chain > 0.001 else { continue }

            // 伸直度：直线距离 / 折线长度。伸直≈1，弯着≈0.6~0.8
            let straightness = distance(mcp, tip) / chain

            // 老条件保留、和新条件取交集：宁可少算，不要多算
            let fartherOut = distance(wrist, tip) > distance(wrist, pip) * 1.22
            let isStraight = straightness > (0.90 + strictness) && jointAngle > 145

            if fartherOut && isStraight { count += 1 }
        }

        // 拇指单独判：剪刀手时它最容易被误算成第三根
        if let cmc = location(.thumbCMC), let mp = location(.thumbMP),
           let ip = location(.thumbIP), let tip = location(.thumbTip) {
            let chain = distance(cmc, mp) + distance(mp, ip) + distance(ip, tip)
            if chain > 0.001 {
                let straightness = distance(cmc, tip) / chain
                let jointAngle = angle(mp, ip, tip)
                // 还要真的伸到手掌外面，握拳/放松时不算
                let outward = distance(wrist, tip) > distance(wrist, scaleRef) * 1.10

                if straightness > (0.93 + strictness) && jointAngle > 150 && outward {
                    count += 1
                }
            }
        }

        return count
    }
}
