import UIKit

/// 手机里装的原生 App（从桌面点开会切出去，外接屏随之变成镜像）
struct NativeApp: Identifiable {
    let id = UUID()
    let name: String
    let scheme: String
}

enum NativeAppCatalog {
    static let all: [NativeApp] = [
        NativeApp(name: "抖音", scheme: "snssdk1128://"),
        NativeApp(name: "微信", scheme: "weixin://"),
        NativeApp(name: "B站", scheme: "bilibili://"),
        NativeApp(name: "小红书", scheme: "xhsdiscover://"),
        NativeApp(name: "微博", scheme: "sinaweibo://"),
        NativeApp(name: "知乎", scheme: "zhihu://"),
        NativeApp(name: "YouTube", scheme: "youtube://"),
        NativeApp(name: "设置", scheme: "app-settings:")
    ]
}

enum NativeAppLauncher {

    static func open(_ item: NativeApp, completion: @escaping (Bool) -> Void) {
        if item.scheme == "app-settings:" {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                completion(false)
                return
            }
            UIApplication.shared.open(url, options: [:]) { ok in
                DispatchQueue.main.async { completion(ok) }
            }
            return
        }
        guard let url = URL(string: item.scheme) else {
            completion(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
