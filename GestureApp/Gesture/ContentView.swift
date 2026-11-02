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

    private let neon = Color(red: 0.40, green: 1.00, blue: 0.80)

    @ObservedObject private var tracker = HandTracker.shared
    @State private var displayed = -1
    @State private var pulse: CGFloat = 0.55
    @State private var pulseOpacity: Double = 0
    @State private var scan: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            gridCanvas
                .ignoresSafeArea()

            CameraStage(tracker: tracker)
                .ignoresSafeArea()

            scanline
                .ignoresSafeArea()

            cornerFrame
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                center
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                displayed = value
            }
            pulse = 0.55
            pulseOpacity = 0.9
            withAnimation(.easeOut(duration: 0.75)) {
                pulse = 1.55
                pulseOpacity = 0
            }
        }
    }

    // MARK: - 背景网格

    private var gridCanvas: some View {
        Canvas { context, size in
            let step: CGFloat = 26
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.055)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 扫描线

    private var scanline: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, neon.opacity(0.30), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
                .frame(height: 120)
                .offset(y: scan * max(0, geo.size.height - 120))
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 四角框

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

            ctx.stroke(path, with: .color(neon.opacity(0.55)), lineWidth: 1.6)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 顶部

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

    // MARK: - 中间

    private var center: some View {
        ZStack {
            Circle()
                .stroke(neon.opacity(0.55), lineWidth: 1.6)
                .frame(width: 236, height: 236)
                .scaleEffect(pulse)
                .opacity(pulseOpacity)

            Circle()
                .stroke(neon.opacity(0.14), lineWidth: 1)
                .frame(width: 236, height: 236)

            Circle()
                .stroke(neon.opacity(0.08), lineWidth: 1)
                .frame(width: 300, height: 300)

            if tracker.denied {
                deniedView
            } else if displayed < 0 {
                waitingView
            } else {
                numberView
            }
        }
        .frame(height: 320)
    }

    private var numberView: some View {
        VStack(spacing: 0) {
            Text("FINGERS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundColor(neon.opacity(0.6))

            Text("\(displayed)")
                .font(.system(size: 148, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: neon.opacity(0.9), radius: 28)

            Text(chinese(displayed))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundColor(neon.opacity(0.85))
                .padding(.top, 2)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(neon.opacity(0.55))
            Text("把手伸进画面")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Text("CAMERA OFF")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundColor(.orange)
            Button {
                openSettings()
            } label: {
                Text("去设置开启")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(neon)
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - 底部

    private var bottomBar: some View {
        HStack {
            Text(tracker.running ? "JOINTS 21 · 100% LOCAL" : "—")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.28))
            Spacer()
            Text("v1.0")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
        }
    }

    private func chinese(_ count: Int) -> String {
        switch count {
        case 0: return "FIST"
        case 1: return "ONE"
        case 2: return "TWO"
        case 3: return "THREE"
        case 4: return "FOUR"
        case 5: return "FIVE"
        default: return ""
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
