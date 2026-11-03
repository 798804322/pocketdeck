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
    @State private var orb = false
    @State private var hideWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ParticleNumber(digit: displayed, orb: orb)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            tracker.start()
        }
        .onChange(of: tracker.fingerCount) { value in
            hideWork?.cancel()

            if value > 0 {
                // 1~5 根手指：粒子聚成对应的数字
                orb = false
                displayed = value
            } else if value == 0 {
                // 握拳：粒子吸成一团亮球，跟着拳头走
                orb = true
            } else {
                // 手短暂出画（放下、抖一下、离太远）不要立刻炸开，留 0.7 秒宽限
                let work = DispatchWorkItem {
                    orb = false
                    displayed = -1
                }
                hideWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
            }
        }
    }
}
