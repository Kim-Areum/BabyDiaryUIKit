import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🟢 AppDelegate didFinishLaunching")
        _ = CoreDataStack.shared.persistentContainer
        CloudSyncObserver.shared.start()
        // 위젯용 사진 내보내기 (기존 데이터 대응)
        CoreDataStack.shared.exportWidgetPhoto()
        // 로컬 녹음 파일을 iCloud Drive로 마이그레이션
        DispatchQueue.global(qos: .utility).async {
            SpeechManager.migrateLocalToiCloud()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
