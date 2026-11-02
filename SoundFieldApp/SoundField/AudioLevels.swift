import Foundation
import AVFoundation
import Combine

/// 实时分析麦克风，拆成低频 / 中频 / 高频三路能量
final class AudioLevels: ObservableObject {
    static let shared = AudioLevels()

    @Published var running = false
    @Published var denied = false

    // 渲染线程直接读这几个值（浮点读写竞争对视觉无影响）
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    var level: Float = 0

    private let engine = AVAudioEngine()
    private var started = false

    // 单极滤波器的状态
    private var lp80: Float = 0
    private var lp200: Float = 0
    private var lp2000: Float = 0
    private var lp4000: Float = 0

    private init() {}

    func start() {
        if started { return }
        let session = AVAudioSession.sharedInstance()

        session.requestRecordPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.denied = true }
                return
            }
            DispatchQueue.main.async {
                self.begin()
            }
        }
    }

    private func begin() {
        guard !started else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true, options: [])
        } catch {
            return
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            started = true
            running = true
        } catch {
            running = false
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        let rate = Float(buffer.format.sampleRate)
        guard rate > 1000 else { return }

        let a80 = 1 - exp(-2.0 * Float.pi * 80.0 / rate)
        let a200 = 1 - exp(-2.0 * Float.pi * 200.0 / rate)
        let a2000 = 1 - exp(-2.0 * Float.pi * 2000.0 / rate)
        let a4000 = 1 - exp(-2.0 * Float.pi * 4000.0 / rate)

        var sumBass: Float = 0
        var sumMid: Float = 0
        var sumHigh: Float = 0
        var sumAll: Float = 0

        for i in 0..<frames {
            let x = data[0][i]
            lp80 += a80 * (x - lp80)
            lp200 += a200 * (x - lp200)
            lp2000 += a2000 * (x - lp2000)
            lp4000 += a4000 * (x - lp4000)

            let bassBand = lp80
            let midBand = lp2000 - lp80
            let highBand = x - lp4000

            sumBass += bassBand * bassBand
            sumMid += midBand * midBand
            sumHigh += highBand * highBand
            sumAll += x * x
        }

        let norm = 1.0 / Float(frames)
        let b = sqrt(sumBass * norm)
        let m = sqrt(sumMid * norm)
        let h = sqrt(sumHigh * norm)
        let l = sqrt(sumAll * norm)

        bass = ease(bass, min(1.0, b * 16.0))
        mid = ease(mid, min(1.0, m * 24.0))
        treble = ease(treble, min(1.0, h * 34.0))
        level = ease(level, min(1.0, l * 12.0))
    }

    /// 起得快、落得慢，视觉上更有"呼吸感"
    private func ease(_ old: Float, _ new: Float) -> Float {
        let k: Float = new > old ? 0.62 : 0.09
        return old + (new - old) * k
    }
}
