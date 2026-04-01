import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let homeVC = HomeViewController()
        homeVC.tabBarItem = UITabBarItem(title: "기록", image: UIImage(systemName: "pencil.and.scribble"), tag: 0)

        let minibookVC = MinibookViewController()
        minibookVC.tabBarItem = UITabBarItem(title: "미니북", image: UIImage(systemName: "book.closed"), tag: 1)

        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape"), tag: 2)

        viewControllers = [homeVC, minibookVC, settingsVC]

        configureTabBarAppearance()
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = DS.bgBase

        let font = DS.font(10)
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: DS.fgPale]
        let selectedColor = UIColor(hex: "7A9ABF")
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: selectedColor]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = DS.fgPale
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
