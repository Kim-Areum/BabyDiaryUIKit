import UIKit
import CoreData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var syncObservation: Any?
    private var syncTimeout: DispatchWorkItem?
    private var didRoute = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🟢 SceneDelegate scene 호출됨")
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .light
        window.backgroundColor = DS.bgBase

        // 스플래시 표시
        let splashVC = SplashViewController()
        window.rootViewController = splashVC
        window.makeKeyAndVisible()
        self.window = window

        NotificationCenter.default.addObserver(self, selector: #selector(handleBabyCreated), name: Notification.Name("babyCreated"), object: nil)

        // iCloud 켜져 있고 로컬에 데이터 없으면 동기화 기다리기
        let iCloudEnabled = !(UserDefaults.standard.object(forKey: "iCloudSyncDisabled") as? Bool ?? false)
        let hasBaby = CoreDataStack.shared.fetchBaby() != nil

        if iCloudEnabled && !hasBaby {
            waitForSync()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.routeToMain()
            }
        }
    }

    /// iCloud 동기화 완료를 기다림 (최대 15초)
    private func waitForSync() {
        // viewContext에 데이터가 머지되는 것을 감지
        syncObservation = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: CoreDataStack.shared.viewContext,
            queue: .main
        ) { [weak self] _ in
            if CoreDataStack.shared.fetchBaby() != nil {
                self?.finishWaiting()
            }
        }

        // 타임아웃 15초
        let timeout = DispatchWorkItem { [weak self] in
            self?.finishWaiting()
        }
        syncTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    private func finishWaiting() {
        guard !didRoute else { return }
        didRoute = true
        syncTimeout?.cancel()
        if let obs = syncObservation {
            NotificationCenter.default.removeObserver(obs)
            syncObservation = nil
        }
        routeToMain()

        // 아기 등록 화면으로 갔어도 동기화 완료되면 자동 전환
        if CoreDataStack.shared.fetchBaby() == nil {
            startLateSync()
        }
    }

    /// 아기 등록 화면에서도 iCloud 데이터 도착 시 자동 전환
    private var lateSyncObservation: Any?

    private func startLateSync() {
        lateSyncObservation = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: CoreDataStack.shared.viewContext,
            queue: .main
        ) { [weak self] _ in
            if CoreDataStack.shared.fetchBaby() != nil {
                self?.stopLateSync()
                self?.handleBabyCreated()
            }
        }
    }

    private func stopLateSync() {
        if let obs = lateSyncObservation {
            NotificationCenter.default.removeObserver(obs)
            lateSyncObservation = nil
        }
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
