import UIKit

final class PhoneSceneDelegate: NSObject, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: windowScene)
        w.backgroundColor = .black
        w.rootViewController = PhoneViewController()
        w.makeKeyAndVisible()
        window = w
    }
}
