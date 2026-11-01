import UIKit

/// 外接显示器上的那个场景
final class DesktopSceneDelegate: NSObject, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        DeckModel.shared.markExternalScene()
        let w = UIWindow(windowScene: windowScene)
        w.backgroundColor = .black
        w.rootViewController = DesktopViewController()
        w.makeKeyAndVisible()
        window = w
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        DeckModel.shared.reportDisconnect()
    }
}
