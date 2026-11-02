import SwiftUI

@main
struct GestureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {

    @ObservedObject private var tracker = HandTracker.shared
    @State private var displayed = -1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraStage(tracker: tracker)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                numberArea
                Spacer().frame(height: 54)
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            tracker.start()
        }
        .onChange(of: tracker.fingerCount) { value in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                displayed = value
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(tracker.running ? Color(red: 0.3, green: 1.0, blue: 0.7) : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(tracker.running ? "本地识别 · 不联网" : "启动中…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var numberArea: some View {
        VStack(spacing: 6) {
            if tracker.denied {
                Text("没有相机权限")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Button {
                    openSettings()
                } label: {
                    Text("去设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.4, green: 1.0, blue: 0.8))
                        .cornerRadius(18)
                }
            } else if displayed < 0 {
                Text("把手伸进画面")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            } else {
                Text("\(displayed)")
                    .font(.system(size: 132, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.3, green: 1.0, blue: 0.7).opacity(0.85), radius: 26)
                    .scaleEffect(displayed == 0 ? 0.9 : 1.0)
                Text(label(for: displayed))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.45, green: 1.0, blue: 0.82).opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func label(for count: Int) -> String {
        switch count {
        case 0: return "拳头"
        case 1: return "一"
        case 2: return "二"
        case 3: return "三"
        case 4: return "四"
        case 5: return "五"
        default: return ""
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
