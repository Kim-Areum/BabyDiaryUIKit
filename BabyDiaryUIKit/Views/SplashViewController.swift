import UIKit

class SplashViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase

        let iconName: String
        switch DS.currentTheme {
        case .pink: iconName = "PinkAppIcon"
        case .yellow: iconName = "YellowAppIcon"
        case .blue: iconName = "AppIcon"
        }
        let imageView = UIImageView(image: UIImage(named: iconName))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
        ])

        imageView.alpha = 0
        UIView.animate(withDuration: 0.5) {
            imageView.alpha = 1
        }
    }
}
