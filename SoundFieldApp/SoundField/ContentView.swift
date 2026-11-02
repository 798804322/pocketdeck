import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ParticleCanvas: UIViewRepresentable {
    func makeUIView(context: Context) -> ParticleSceneView {
        ParticleSceneView(frame: .zero)
    }

    func updateUIView(_ uiView: ParticleSceneView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject private var audio = AudioLevels.shared
    @State private var showPicker = false
    @State private var showHint = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleCanvas()
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 26)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.audio],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                audio.importAndPlay(url: url)
                showHint = false
            }
        }
        .onAppear {
            // 不自动开麦克风：一开就会打断别的 App 的音乐
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showHint = false
                }
            }
        }
    }

    // MARK: - 顶部工具条

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                pill(icon: "music.note.list", text: "导入歌曲")
            }

            if audio.source == .player {
                Button {
                    audio.togglePlay()
                } label: {
                    Image(systemName: audio.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.13))
                        .clipShape(Circle())
                }

                Text(audio.trackName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            } else {
                Button {
                    audio.startMic()
                } label: {
                    pill(icon: "mic.fill", text: "麦克风")
                }
            }

            Spacer()
        }
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.13))
        .cornerRadius(14)
    }

    // MARK: - 底部提示

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if audio.denied {
                Text("需要麦克风权限：设置 → 声场 → 麦克风")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.3))
                Button {
                    openSettings()
                } label: {
                    Text("去设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.16))
                        .cornerRadius(18)
                }
            } else if !audio.running {
                Button {
                    audio.startMic()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                        Text("开始聆听")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.16))
                    .cornerRadius(22)
                }
                Text("点它才会听声音 —— 会暂停其他 App 的音乐，\n想让画面跟着自己的歌，用左上角「导入歌曲」")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            } else if showHint {
                Text(audio.source == .player ? "正在播放，屏幕会跟着节奏动" : "对着音响放歌，或者导入一首歌")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
