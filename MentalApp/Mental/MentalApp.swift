//  MentalApp.swift
//  宇宙精神状态检测中心 —— WKWebView 外壳
//  网页资源以 index.html 形式打包进 App Bundle，纯本地运行，无需联网。

import SwiftUI
import WebKit

final class WebContainerView: UIView {
    override var safeAreaInsets: UIEdgeInsets { .zero }
}

struct WebContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = false
        config.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        let bg = UIColor(red: 0.031, green: 0.031, blue: 0.059, alpha: 1.0)
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // 彻底禁止上下滑动：滚动能力关闭，页面内容固定在一屏内
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false

        let bundle = Bundle.main
        let url = bundle.url(forResource: "index", withExtension: "html")
            ?? bundle.url(forResource: "index", withExtension: "html", subdirectory: "Web")

        if let url = url {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            let html = "<html><body style='background:#08080f;color:#b49bff;"
                + "font-family:-apple-system;display:flex;align-items:center;"
                + "justify-content:center;height:100vh;margin:0;font-size:15px'>"
                + "资源缺失：index.html 未打包进 Bundle</body></html>"
            webView.loadHTMLString(html, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@main
struct MentalApp: App {
    var body: some Scene {
        WindowGroup {
            WebContainer()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
