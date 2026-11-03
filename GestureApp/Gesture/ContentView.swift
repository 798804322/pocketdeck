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
    @State private var hideWork: DispatchWorkItem?

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
            hideWork?.cancel()
            if value >= 0 {
                displayed = value
            } else {
                // 手短暂出画（放下、抖一下）不要立刻炸开，留 0.7 秒宽限
                let work = DispatchWorkItem { displayed = -1 }
                hideWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
            }
        }
    }
}
