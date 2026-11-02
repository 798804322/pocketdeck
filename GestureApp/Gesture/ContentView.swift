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

    private let neon = Color(red: 0.45, green: 1.00, blue: 0.85)

    @ObservedObject private var tracker = HandTracker.shared
    @State private var displayed = -1
    @State private var scan: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ParticleNumber(digit: displayed)
                .ignoresSafeArea()

            gridCanvas
                .ignoresSafeArea()

            scanline
                .ignoresSafeArea()

            cornerFrame
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            tracker.start()
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: true)) {
                scan = 1
            }
        }
        .onChange(of: tracker.fingerCount) { value in
            displayed = value
        }
    }

    // MARK: - 背景

    private var gridCanvas: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 1.4, height: 1.4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }

    private var scanline: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, neon.opacity(0.16), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
                .frame(height: 130)
                .offset(y: scan * max(0, geo.size.height - 130))
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    private var cornerFrame: some View {
        Canvas { ctx, size in
            let inset: CGFloat = 20
            let length: CGFloat = 30
            var path = Path()

            path.move(to: CGPoint(x: inset, y: inset + length))
            path.addLine(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: inset + length, y: inset))

            path.move(to: CGPoint(x: size.width - inset - length, y: inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: inset + length))

            path.move(to: CGPoint(x: size.width - inset, y: size.height - inset - length))
            path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: size.width - inset - length, y: size.height - inset))

            path.move(to: CGPoint(x: inset + length, y: size.height - inset))
            path.addLine(to: CGPoint(x: inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: inset, y: size.height - inset - length))

            ctx.stroke(path, with: .color(neon.opacity(0.5)), lineWidth: 1.6)
        }
        .allowsHitTesting(false)
    }

    // MARK: - HUD

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(tracker.running ? neon : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
                Text(tracker.running ? "HAND POSE · ONLINE" : "STARTING…")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundColor(neon.opacity(0.75))
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if tracker.denied {
                Button {
                    openSettings()
                } label: {
                    Text("去设置开启相机")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(neon)
                        .cornerRadius(16)
                }
            } else if displayed < 0 {
                Text("把手伸进画面")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))
            } else {
                Text("DETECTED  \(displayed)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(neon.opacity(0.8))
            }

            HStack {
                Text(tracker.running ? "LOCAL ONLY · NO UPLOAD" : "—")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.22))
                Spacer()
                Text("v1.1")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.18))
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
