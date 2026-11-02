import SwiftUI
import UIKit

struct ParticleCanvas: UIViewRepresentable {
    func makeUIView(context: Context) -> ParticleSceneView {
        ParticleSceneView(frame: .zero)
    }

    func updateUIView(_ uiView: ParticleSceneView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject private var audio = AudioLevels.shared
    @State private var showHint = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleCanvas()
                .ignoresSafeArea()

            VStack {
                Spacer()
                bottomBar
            }
            .padding(.bottom, 26)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            audio.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showHint = false
                }
            }
        }
    }

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
            } else if showHint {
                Text("对着音响放歌，效果最好")
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
