import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🟢 SceneDelegate scene 호출됨")
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .light
        window.backgroundColor = DS.bgBase

        // 스플래시 표시 후 라우팅
        let splashVC = SplashViewController()
        window.rootViewController = splashVC
        window.makeKeyAndVisible()
        self.window = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.routeToMain()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleBabyCreated), name: Notification.Name("babyCreated"), object: nil)
    }

    @objc private func handleBabyCreated() {
        guard let window = window else { return }
        let mainVC = MainTabBarController()
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = mainVC
        }
    }

    func routeToMain() {
        guard let window = window else { return }

        let rootVC: UIViewController
        if CoreDataStack.shared.fetchBaby() != nil {
            rootVC = MainTabBarController()
        } else {
            rootVC = BabySetupViewController()
        }

        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            window.rootViewController = rootVC
        }
    }
}
