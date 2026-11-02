import Foundation
import AVFoundation
import Combine

/// 实时分析声音，拆成低频 / 中频 / 高频三路能量
/// 两种来源：麦克风（对着音响拍）、内部播放器（导入歌曲，最准）
final class AudioLevels: ObservableObject {
    static let shared = AudioLevels()

    enum Source {
        case mic
        case player
    }

    @Published var running = false
    @Published var denied = false
    @Published var source: Source = .mic
    @Published var trackName: String = ""
    @Published var playing = false

    // 渲染线程直接读（浮点竞争对视觉无影响）
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    var level: Float = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var playerAttached = false
    private var micReady = false

    private var lp80: Float = 0
    private var lp200: Float = 0
    private var lp2000: Float = 0
    private var lp4000: Float = 0

    /// 自动增益：让小声的歌也能把画面炸开
    private var agcPeak: Float = 0.02

    private init() {}

    // MARK: - 麦克风模式

    func startMic() {
        guard !micReady else { return }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.denied = true }
                return
            }
            DispatchQueue.main.async { self.beginMic() }
        }
    }

    private func beginMic() {
        stopPlayer()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.mixWithOthers, .defaultToSpeaker])
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
            micReady = true
            running = true
            if source != .player { source = .mic }
        } catch {
            running = false
        }
    }

    private func stopMic() {
        guard micReady else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        micReady = false
    }

    // MARK: - 播放器模式（导入歌曲，最准）

    func importAndPlay(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        let target = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(url.lastPathComponent)

        if target.path != url.path {
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: url, to: target)
        }
        if access { url.stopAccessingSecurityScopedResource() }

        let playURL = FileManager.default.fileExists(atPath: target.path) ? target : url
        playTrack(url: playURL)
    }

    private func playTrack(url: URL) {
        stopMic()
        stopPlayer()

        do {
            let audioFile = try AVAudioFile(forReading: url)

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])

            if !playerAttached {
                engine.attach(player)
                playerAttached = true
            }
            engine.connect(player, to: engine.mainMixerNode, format: audioFile.processingFormat)

            let mixer = engine.mainMixerNode
            mixer.removeTap(onBus: 0)
            mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
                self?.process(buffer)
            }

            engine.prepare()
            try engine.start()

            player.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async { self?.playing = false }
            }
            player.play()

            playing = true
            running = true
            source = .player
            trackName = url.deletingPathExtension().lastPathComponent
            denied = false
        } catch {
            playing = false
            running = false
        }
    }

    private func stopPlayer() {
        guard playerAttached else { return }
        player.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        engine.disconnectNodeOutput(player)
        playing = false
    }

    func togglePlay() {
        guard source == .player, playerAttached else { return }
        if playing {
            player.pause()
            playing = false
        } else {
            player.play()
            playing = true
        }
    }

    // MARK: - 音频分析

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

        // 自动增益：跟着最响的部分走，小声也能炸
        let peakNow = max(b, max(m, h))
        if peakNow > agcPeak {
            agcPeak = peakNow
        } else {
            agcPeak = max(0.004, agcPeak * 0.9994)
        }
        let gain = min(26.0, 0.50 / max(0.004, agcPeak))
        let gate: Float = l < 0.0028 ? 0.0 : 1.0

        bass = ease(bass, min(1.0, b * gain) * gate)
        mid = ease(mid, min(1.0, m * gain * 1.15) * gate)
        treble = ease(treble, min(1.0, h * gain * 1.6) * gate)
        level = ease(level, min(1.0, l * gain) * gate)
    }

    /// 起得快、落得慢，视觉上更有呼吸感
    private func ease(_ old: Float, _ new: Float) -> Float {
        let k: Float = new > old ? 0.60 : 0.085
        return old + (new - old) * k
    }
}
