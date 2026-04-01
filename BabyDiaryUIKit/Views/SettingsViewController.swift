import UIKit
import UIKit

class SettingsViewController: UIViewController {

    // MARK: - Properties

    private var baby: CDBaby? {
        CoreDataStack.shared.fetchBaby()
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Profile section
    private let profileContainer = UIView()
    private let profileImageView = UIImageView()
    private let profilePlaceholder = UIView()
    private let cameraOverlayButton = UIButton(type: .system)
    private let nameDisplayLabel = UILabel()
    private let badgesStack = UIStackView()

    // Edit fields
    private let nameLabel = UILabel()
    private let nameField = UITextField()
    private let birthLabel = UILabel()
    private let birthButton = UIButton(type: .system)

    // Elephant toggle
    private let elephantToggle = UISwitch()

    private var birthDate = Date()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupScrollView()
        setupProfileSection()
        setupEditFields()
        setupElephantToggle()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    // MARK: - Setup

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = "설정"
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupScrollView() {
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])
    }

    // MARK: - Profile Section

    private func setupProfileSection() {
        let profileStack = UIStackView()
        profileStack.axis = .vertical
        profileStack.spacing = 12
        profileStack.alignment = .center

        // Photo container
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profileContainer.widthAnchor.constraint(equalToConstant: 80),
            profileContainer.heightAnchor.constraint(equalToConstant: 80),
        ])

        // Photo image
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 40
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = DS.line.cgColor
        profileImageView.isUserInteractionEnabled = true
        profileImageView.isHidden = true
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.addSubview(profileImageView)

        let viewTap = UITapGestureRecognizer(target: self, action: #selector(viewProfilePhoto))
        profileImageView.addGestureRecognizer(viewTap)

        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            profileImageView.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileImageView.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profileImageView.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
        ])

        // Placeholder
        profilePlaceholder.backgroundColor = DS.bgSubtle
        profilePlaceholder.layer.cornerRadius = 40
        profilePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.addSubview(profilePlaceholder)

        let cameraEmoji = UILabel()
        cameraEmoji.text = "\u{1F4F7}"
        cameraEmoji.font = .systemFont(ofSize: 24)
        cameraEmoji.translatesAutoresizingMaskIntoConstraints = false
        profilePlaceholder.addSubview(cameraEmoji)

        NSLayoutConstraint.activate([
            profilePlaceholder.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            profilePlaceholder.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profilePlaceholder.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profilePlaceholder.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            cameraEmoji.centerXAnchor.constraint(equalTo: profilePlaceholder.centerXAnchor),
            cameraEmoji.centerYAnchor.constraint(equalTo: profilePlaceholder.centerYAnchor),
        ])

        // Camera overlay
        let camConfig = UIImage.SymbolConfiguration(pointSize: 10)
        cameraOverlayButton.setImage(UIImage(systemName: "camera.fill", withConfiguration: camConfig), for: .normal)
        cameraOverlayButton.tintColor = DS.fgMuted
        cameraOverlayButton.backgroundColor = DS.bgBase
        cameraOverlayButton.layer.cornerRadius = 12
        cameraOverlayButton.layer.borderWidth = 0.5
        cameraOverlayButton.layer.borderColor = DS.line.cgColor
        cameraOverlayButton.addTarget(self, action: #selector(pickPhoto), for: .touchUpInside)
        cameraOverlayButton.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.addSubview(cameraOverlayButton)

        NSLayoutConstraint.activate([
            cameraOverlayButton.widthAnchor.constraint(equalToConstant: 24),
            cameraOverlayButton.heightAnchor.constraint(equalToConstant: 24),
            cameraOverlayButton.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            cameraOverlayButton.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
        ])

        profileStack.addArrangedSubview(profileContainer)

        // Name display
        nameDisplayLabel.font = DS.font(20)
        nameDisplayLabel.textColor = DS.fgStrong
        profileStack.addArrangedSubview(nameDisplayLabel)

        // Age badges
        badgesStack.axis = .horizontal
        badgesStack.spacing = 8
        profileStack.addArrangedSubview(badgesStack)

        profileStack.translatesAutoresizingMaskIntoConstraints = false
        let profileWrapper = UIView()
        profileWrapper.addSubview(profileStack)
        profileStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profileStack.centerXAnchor.constraint(equalTo: profileWrapper.centerXAnchor),
            profileStack.topAnchor.constraint(equalTo: profileWrapper.topAnchor),
            profileStack.bottomAnchor.constraint(equalTo: profileWrapper.bottomAnchor),
        ])
        contentStack.addArrangedSubview(profileWrapper)
        contentStack.setCustomSpacing(8, after: profileWrapper)
    }

    // MARK: - Edit Fields

    private func setupEditFields() {
        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 16
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false

        // Name field
        let nameStack = UIStackView()
        nameStack.axis = .vertical
        nameStack.spacing = 6

        nameLabel.text = "아기 이름"
        nameLabel.font = DS.font(14)
        nameLabel.textColor = DS.fgMuted
        nameStack.addArrangedSubview(nameLabel)

        nameField.font = DS.font(14)
        nameField.placeholder = "이름"
        nameField.backgroundColor = DS.bgBase
        nameField.layer.cornerRadius = 12
        nameField.layer.borderWidth = 1
        nameField.layer.borderColor = DS.line.cgColor
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        nameField.leftViewMode = .always
        nameField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        nameField.rightViewMode = .always
        nameField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        nameStack.addArrangedSubview(nameField)
        fieldsStack.addArrangedSubview(nameStack)

        // Birth date field
        let birthStack = UIStackView()
        birthStack.axis = .vertical
        birthStack.spacing = 6

        birthLabel.text = "생년월일"
        birthLabel.font = DS.font(14)
        birthLabel.textColor = DS.fgMuted
        birthStack.addArrangedSubview(birthLabel)

        birthButton.titleLabel?.font = DS.font(14)
        birthButton.setTitleColor(DS.fgStrong, for: .normal)
        birthButton.contentHorizontalAlignment = .left
        birthButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        birthButton.backgroundColor = DS.bgBase
        birthButton.layer.cornerRadius = 12
        birthButton.layer.borderWidth = 1
        birthButton.layer.borderColor = DS.line.cgColor
        birthButton.addTarget(self, action: #selector(showDatePicker), for: .touchUpInside)
        birthButton.translatesAutoresizingMaskIntoConstraints = false
        birthButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        birthStack.addArrangedSubview(birthButton)
        fieldsStack.addArrangedSubview(birthStack)

        contentStack.addArrangedSubview(fieldsStack)
    }

    // MARK: - Elephant Toggle

    private func setupElephantToggle() {
        let toggleContainer = UIView()
        toggleContainer.translatesAutoresizingMaskIntoConstraints = false

        let elephantImage = UIImageView(image: UIImage(named: "Elephant2"))
        elephantImage.contentMode = .scaleAspectFit
        elephantImage.transform = CGAffineTransform(scaleX: -1, y: 1)
        elephantImage.translatesAutoresizingMaskIntoConstraints = false
        toggleContainer.addSubview(elephantImage)

        elephantToggle.isOn = !UserDefaults.standard.bool(forKey: "hideElephant")
        elephantToggle.onTintColor = DS.blue
        elephantToggle.addTarget(self, action: #selector(elephantToggleChanged), for: .valueChanged)
        elephantToggle.translatesAutoresizingMaskIntoConstraints = false
        toggleContainer.addSubview(elephantToggle)

        NSLayoutConstraint.activate([
            elephantImage.leadingAnchor.constraint(equalTo: toggleContainer.leadingAnchor),
            elephantImage.centerYAnchor.constraint(equalTo: toggleContainer.centerYAnchor),
            elephantImage.heightAnchor.constraint(equalToConstant: 30),
            elephantImage.widthAnchor.constraint(equalToConstant: 60),

            elephantToggle.trailingAnchor.constraint(equalTo: toggleContainer.trailingAnchor),
            elephantToggle.centerYAnchor.constraint(equalTo: toggleContainer.centerYAnchor),

            toggleContainer.heightAnchor.constraint(equalToConstant: 44),
        ])

        contentStack.addArrangedSubview(toggleContainer)
        contentStack.setCustomSpacing(8, after: toggleContainer)
    }

    // MARK: - Data Loading

    private func reloadData() {
        guard let baby = baby else { return }
        nameField.text = baby.name
        birthDate = baby.birthDate
        nameDisplayLabel.text = baby.name
        updateBirthDateLabel()
        updateProfilePhoto()
        updateBadges()
        elephantToggle.isOn = !UserDefaults.standard.bool(forKey: "hideElephant")
    }

    private func updateProfilePhoto() {
        guard let baby = baby else { return }
        if let data = baby.photoData, let image = UIImage(data: data) {
            profileImageView.image = image
            profileImageView.isHidden = false
            profilePlaceholder.isHidden = true
        } else {
            profileImageView.isHidden = true
            profilePlaceholder.isHidden = false
        }
    }

    private func updateBadges() {
        guard let baby = baby else { return }
        badgesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let dBadge = makeAgeBadge(text: "D+\(baby.dayCount)", color: DS.yellow)
        let mBadge = makeAgeBadge(text: baby.monthAndDays, color: DS.green)
        let yBadge = makeAgeBadge(text: "만 \(baby.ageYears)세", color: DS.blue)
        badgesStack.addArrangedSubview(dBadge)
        badgesStack.addArrangedSubview(mBadge)
        badgesStack.addArrangedSubview(yBadge)
    }

    private func makeAgeBadge(text: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = DS.font(11)
        label.textColor = DS.fgNeutral
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = color
        container.layer.cornerRadius = 10
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
        ])
        return container
    }

    private func updateBirthDateLabel() {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        birthButton.setTitle(formatter.string(from: birthDate), for: .normal)
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func nameFieldChanged() {
        guard let baby = baby else { return }
        let newName = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        baby.name = newName
        nameDisplayLabel.text = newName
        CoreDataStack.shared.save()
    }

    @objc private func showDatePicker() {
        let sheet = DatePickerSheetViewController(selectedDate: birthDate)
        sheet.delegate = self
        present(sheet, animated: true)
    }

    @objc private func pickPhoto() {
        let picker = CustomPhotoPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func viewProfilePhoto() {
        guard let baby = baby, let data = baby.photoData, let image = UIImage(data: data) else { return }
        let viewer = FullScreenImageViewController(image: image)
        present(viewer, animated: true)
    }

    @objc private func elephantToggleChanged() {
        UserDefaults.standard.set(!elephantToggle.isOn, forKey: "hideElephant")
    }
}

// MARK: - DatePickerSheetDelegate

extension SettingsViewController: DatePickerSheetDelegate {
    func datePickerSheet(_ sheet: DatePickerSheetViewController, didSelectDate date: Date) {
        guard let baby = baby else { return }
        birthDate = date
        baby.birthDate = date
        CoreDataStack.shared.save()
        updateBirthDateLabel()
        updateBadges()
    }
}

// MARK: - CustomPhotoPickerDelegate

extension SettingsViewController: CustomPhotoPickerDelegate {
    func photoPicker(_ picker: CustomPhotoPickerViewController, didSelect image: UIImage) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            // 프로필 1:1 비율 크롭 에디터
            let cropVC = CoverCropViewController(image: image, aspectRatio: 1.0)
            cropVC.onSave = { [weak self] croppedImage in
                guard let self = self else { return }
                self.baby?.photoData = croppedImage.jpegData(compressionQuality: 0.8)
                CoreDataStack.shared.save()
                self.updateProfilePhoto()
            }
            self.present(cropVC, animated: true)
        }
    }
}
