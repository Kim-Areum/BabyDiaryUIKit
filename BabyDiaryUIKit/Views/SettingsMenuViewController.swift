import UIKit
import CoreData

final class SettingsMenuViewController: UIViewController {

    private let cardView = UIView()
    private let iCloudSwitch = UISwitch()
    private var syncStatusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)

        let tap = UITapGestureRecognizer(target: self, action: #selector(bgTapped(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)

        setupCard()
    }

    // MARK: - Card

    private func setupCard() {
        cardView.backgroundColor = DS.bgBase
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 12
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),
        ])

        // iCloud 동기화 row
        let iCloudRow = makeRow()
        let cloudIcon = UIImageView(image: UIImage(systemName: "icloud")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        ))
        cloudIcon.tintColor = DS.fgNeutral
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        cloudIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let cloudLabel = UILabel()
        cloudLabel.text = "iCloud 동기화"
        cloudLabel.font = DS.font(14)
        cloudLabel.textColor = DS.fgStrong

        iCloudSwitch.isOn = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        iCloudSwitch.onTintColor = DS.accent
        iCloudSwitch.addTarget(self, action: #selector(iCloudToggled), for: .valueChanged)

        iCloudRow.addArrangedSubview(cloudIcon)
        iCloudRow.addArrangedSubview(cloudLabel)
        iCloudRow.addArrangedSubview(iCloudSwitch)
        stack.addArrangedSubview(iCloudRow)

        // 동기화 상태
        syncStatusLabel.font = DS.font(11)
        syncStatusLabel.textColor = DS.fgPale
        syncStatusLabel.text = iCloudSwitch.isOn ? "동기화 활성화됨" : "동기화 꺼짐"
        syncStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        let statusWrapper = UIView()
        statusWrapper.translatesAutoresizingMaskIntoConstraints = false
        statusWrapper.addSubview(syncStatusLabel)
        NSLayoutConstraint.activate([
            syncStatusLabel.topAnchor.constraint(equalTo: statusWrapper.topAnchor, constant: 6),
            syncStatusLabel.leadingAnchor.constraint(equalTo: statusWrapper.leadingAnchor, constant: 32),
            syncStatusLabel.bottomAnchor.constraint(equalTo: statusWrapper.bottomAnchor),
        ])
        stack.addArrangedSubview(statusWrapper)

        // 구분선
        stack.addArrangedSubview(makeSeparator())
        stack.setCustomSpacing(16, after: statusWrapper)

        // 앱 버전 row
        let versionRow = makeRow()
        let versionIcon = UIImageView(image: UIImage(systemName: "info.circle")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        ))
        versionIcon.tintColor = DS.fgNeutral
        versionIcon.translatesAutoresizingMaskIntoConstraints = false
        versionIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let versionLabel = UILabel()
        versionLabel.text = "앱 버전"
        versionLabel.font = DS.font(14)
        versionLabel.textColor = DS.fgStrong

        let versionValue = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionValue.text = "v\(version) (\(build))"
        versionValue.font = DS.font(13)
        versionValue.textColor = DS.fgPale

        versionRow.addArrangedSubview(versionIcon)
        versionRow.addArrangedSubview(versionLabel)
        versionRow.addArrangedSubview(versionValue)
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(versionRow)
    }

    // MARK: - Helpers

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        return row
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = DS.line
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }

    // MARK: - Actions

    @objc private func iCloudToggled() {
        let enabled = iCloudSwitch.isOn
        UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
        syncStatusLabel.text = enabled ? "앱 재시작 후 적용됩니다" : "동기화 꺼짐"
    }

    @objc private func bgTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !cardView.frame.contains(location) {
            dismiss(animated: true)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SettingsMenuViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
}
