import SwiftUI

@main
struct GestureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 只有粒子，别的什么都没有
struct ContentView: View {

    @ObservedObject private var tracker = HandTracker.shared
    @State private var displayed = -1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleNumber(digit: displayed)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            tracker.start()
        }
        .onChange(of: tracker.fingerCount) { value in
            displayed = value
        }
    }
}
