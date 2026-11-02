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

        let count = countFingers(recognized)
        publish(points: points, count: count)
    }

    private func publish(points: [CGPoint]?, count: Int) {
        // 防抖：连续 3 帧结果一致才更新
        if count == lastStable {
            stableCounter += 1
        } else {
            lastStable = count
            stableCounter = 1
        }

        let stable = stableCounter >= 3 ? count : nil

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
            guard let point = points[name], point.confidence > 0.25 else { return nil }
            return point.location
        }

        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = a.x - b.x
            let dy = a.y - b.y
            return sqrt(dx * dx + dy * dy)
        }

        guard let wrist = location(.wrist) else { return -1 }

        var count = 0

        let fingers: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexPIP),
            (.middleTip, .middlePIP),
            (.ringTip, .ringPIP),
            (.littleTip, .littlePIP)
        ]

        for (tip, pip) in fingers {
            guard let t = location(tip), let m = location(pip) else { continue }
            if distance(wrist, t) > distance(wrist, m) * 1.22 {
                count += 1
            }
        }

        if let thumbTip = location(.thumbTip), let thumbIP = location(.thumbIP) {
            if distance(wrist, thumbTip) > distance(wrist, thumbIP) * 1.18 {
                count += 1
            }
        }

        return count
    }
}
