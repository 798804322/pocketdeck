import UIKit

/// 可以一键打开的网页应用
struct WebApp: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let tint: UIColor
    let initials: String
    /// true = 竖屏窗口（像手机），false = 横屏窗口
    let portrait: Bool
}

enum WebAppCatalog {

    static let all: [WebApp] = [
        WebApp(name: "抖音", url: "https://www.douyin.com",
               tint: UIColor(white: 0.12, alpha: 1), initials: "抖", portrait: false),
        WebApp(name: "B站", url: "https://www.bilibili.com",
               tint: UIColor(red: 0.98, green: 0.44, blue: 0.62, alpha: 1), initials: "B", portrait: false),
        WebApp(name: "YouTube", url: "https://www.youtube.com",
               tint: UIColor(red: 0.90, green: 0.18, blue: 0.14, alpha: 1), initials: "YT", portrait: false),
        WebApp(name: "金山文档", url: "https://www.kdocs.cn",
               tint: UIColor(red: 0.16, green: 0.62, blue: 0.42, alpha: 1), initials: "WPS", portrait: false),
        WebApp(name: "腾讯文档", url: "https://docs.qq.com",
               tint: UIColor(red: 0.15, green: 0.46, blue: 0.94, alpha: 1), initials: "文档", portrait: false),
        WebApp(name: "飞书", url: "https://www.feishu.cn",
               tint: UIColor(red: 0.20, green: 0.36, blue: 0.90, alpha: 1), initials: "飞", portrait: false),
        WebApp(name: "GitHub", url: "https://github.com",
               tint: UIColor(white: 0.22, alpha: 1), initials: "GH", portrait: false)
    ]
}
