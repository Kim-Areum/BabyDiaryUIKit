import UIKit

class BabySetupViewController: UIViewController {

    // MARK: - Properties

    private var photoData: Data?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let photoContainerView = UIView()
    private let photoImageView = UIImageView()
    private let photoPlaceholder = UIView()
    private let cameraButton = UIButton(type: .system)
    private let nameLabel = UILabel()
    private let nameField = UITextField()
    private let birthLabel = UILabel()
    private let birthButton = UIButton(type: .system)
    private let startButton = UIButton(type: .system)

    private var birthDate = Date()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupStartButton()
        setupScrollView()
        setupPhotoSection()
        setupNameSection()
        setupBirthDateSection()
        updateStartButton()
        updateBirthDateLabel()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = "아기 등록"
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])
    }

    // MARK: - Photo Section

    private func setupPhotoSection() {
        photoContainerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            photoContainerView.widthAnchor.constraint(equalToConstant: 100),
            photoContainerView.heightAnchor.constraint(equalToConstant: 100),
        ])

        // Photo image (hidden initially)
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 50
        photoImageView.layer.borderWidth = 1
        photoImageView.layer.borderColor = DS.line.cgColor
        photoImageView.isHidden = true
        photoImageView.isUserInteractionEnabled = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoContainerView.addSubview(photoImageView)

        let viewTap = UITapGestureRecognizer(target: self, action: #selector(photoViewTapped))
        photoImageView.addGestureRecognizer(viewTap)

        NSLayoutConstraint.activate([
            photoImageView.topAnchor.constraint(equalTo: photoContainerView.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoContainerView.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoContainerView.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoContainerView.bottomAnchor),
        ])

        // Placeholder
        photoPlaceholder.backgroundColor = DS.bgSubtle
        photoPlaceholder.layer.cornerRadius = 50
        photoPlaceholder.layer.borderWidth = 1
        photoPlaceholder.layer.borderColor = DS.line.cgColor
        photoPlaceholder.isUserInteractionEnabled = true
        photoPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        photoContainerView.addSubview(photoPlaceholder)

        let plusLabel = UILabel()
        plusLabel.text = "+"
        plusLabel.font = .systemFont(ofSize: 36)
        plusLabel.textColor = DS.fgPale
        plusLabel.translatesAutoresizingMaskIntoConstraints = false
        photoPlaceholder.addSubview(plusLabel)

        NSLayoutConstraint.activate([
            photoPlaceholder.topAnchor.constraint(equalTo: photoContainerView.topAnchor),
            photoPlaceholder.leadingAnchor.constraint(equalTo: photoContainerView.leadingAnchor),
            photoPlaceholder.trailingAnchor.constraint(equalTo: photoContainerView.trailingAnchor),
            photoPlaceholder.bottomAnchor.constraint(equalTo: photoContainerView.bottomAnchor),
            plusLabel.centerXAnchor.constraint(equalTo: photoPlaceholder.centerXAnchor),
            plusLabel.centerYAnchor.constraint(equalTo: photoPlaceholder.centerYAnchor),
        ])

        let placeholderTap = UITapGestureRecognizer(target: self, action: #selector(pickPhoto))
        photoPlaceholder.addGestureRecognizer(placeholderTap)

        // Camera overlay button
        let cameraConfig = UIImage.SymbolConfiguration(pointSize: 10)
        cameraButton.setImage(UIImage(systemName: "camera.fill", withConfiguration: cameraConfig), for: .normal)
        cameraButton.tintColor = DS.fgMuted
        cameraButton.backgroundColor = DS.bgBase
        cameraButton.layer.cornerRadius = 12
        cameraButton.layer.borderWidth = 0.5
        cameraButton.layer.borderColor = DS.line.cgColor
        cameraButton.isHidden = true
        cameraButton.addTarget(self, action: #selector(pickPhoto), for: .touchUpInside)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        photoContainerView.addSubview(cameraButton)

        NSLayoutConstraint.activate([
            cameraButton.widthAnchor.constraint(equalToConstant: 24),
            cameraButton.heightAnchor.constraint(equalToConstant: 24),
            cameraButton.trailingAnchor.constraint(equalTo: photoContainerView.trailingAnchor),
            cameraButton.bottomAnchor.constraint(equalTo: photoContainerView.bottomAnchor),
        ])

        let photoWrapper = UIView()
        photoWrapper.translatesAutoresizingMaskIntoConstraints = false
        photoWrapper.addSubview(photoContainerView)
        NSLayoutConstraint.activate([
            photoContainerView.centerXAnchor.constraint(equalTo: photoWrapper.centerXAnchor),
            photoContainerView.topAnchor.constraint(equalTo: photoWrapper.topAnchor),
            photoContainerView.bottomAnchor.constraint(equalTo: photoWrapper.bottomAnchor),
        ])
        contentStack.addArrangedSubview(photoWrapper)
    }

    // MARK: - Name Section

    private func setupNameSection() {
        let nameStack = UIStackView()
        nameStack.axis = .vertical
        nameStack.spacing = 6
        nameStack.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.text = "아기 이름"
        nameLabel.font = DS.font(13)
        nameLabel.textColor = DS.fgMuted
        nameStack.addArrangedSubview(nameLabel)

        nameField.font = DS.font(16)
        nameField.placeholder = "이름을 입력하세요"
        nameField.backgroundColor = DS.bgBase
        nameField.layer.cornerRadius = 12
        nameField.layer.borderWidth = 1
        nameField.layer.borderColor = DS.line.cgColor
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        nameField.leftViewMode = .always
        nameField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        nameField.rightViewMode = .always
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        nameStack.addArrangedSubview(nameField)

        contentStack.addArrangedSubview(nameStack)
    }

    // MARK: - Birth Date Section

    private func setupBirthDateSection() {
        let birthStack = UIStackView()
        birthStack.axis = .vertical
        birthStack.spacing = 6
        birthStack.translatesAutoresizingMaskIntoConstraints = false

        birthLabel.text = "생년월일"
        birthLabel.font = DS.font(13)
        birthLabel.textColor = DS.fgMuted
        birthStack.addArrangedSubview(birthLabel)

        birthButton.titleLabel?.font = DS.font(16)
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

        contentStack.addArrangedSubview(birthStack)
    }

    // MARK: - Start Button

    private func setupStartButton() {
        startButton.setTitle("시작하기", for: .normal)
        startButton.titleLabel?.font = DS.font(16)
        startButton.layer.cornerRadius = 22
        startButton.clipsToBounds = true
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            startButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func nameChanged() {
        updateStartButton()
    }

    @objc private func pickPhoto() {
        let picker = CustomPhotoPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func photoViewTapped() {
        guard let data = photoData, let image = UIImage(data: data) else { return }
        let cropVC = CoverCropViewController(image: image, aspectRatio: 1.0)
        cropVC.onSave = { [weak self] croppedImage in
            self?.photoData = croppedImage.jpegData(compressionQuality: 0.8)
            self?.updatePhotoUI()
        }
        present(cropVC, animated: true)
    }

    @objc private func showDatePicker() {
        let sheet = DatePickerSheetViewController(selectedDate: birthDate)
        sheet.delegate = self
        present(sheet, animated: true)
    }

    @objc private func startTapped() {
        view.endEditing(true)
        let trimmedName = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let _ = CoreDataStack.shared.createBaby(
            name: trimmedName,
            birthDate: birthDate,
            photoData: photoData
        )
        NotificationCenter.default.post(name: Notification.Name("babyCreated"), object: nil)
    }

    // MARK: - Helpers

    private func updateStartButton() {
        let trimmedName = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = !trimmedName.isEmpty
        startButton.isEnabled = enabled
        startButton.backgroundColor = enabled ? DS.pink : DS.bgNeutral
        startButton.setTitleColor(enabled ? DS.fgStrong : DS.fgPale, for: .normal)
    }

    private func updateBirthDateLabel() {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        birthButton.setTitle(formatter.string(from: birthDate), for: .normal)
    }

    private func updatePhotoUI() {
        if let data = photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            photoPlaceholder.isHidden = true
            cameraButton.isHidden = false
        } else {
            photoImageView.isHidden = true
            photoPlaceholder.isHidden = false
            cameraButton.isHidden = true
        }
    }
}

// MARK: - CustomPhotoPickerDelegate

extension BabySetupViewController: CustomPhotoPickerDelegate {
    func photoPicker(_ picker: CustomPhotoPickerViewController, didSelect image: UIImage) {
        photoData = image.jpegData(compressionQuality: 0.8)
        updatePhotoUI()
    }
}

// MARK: - DatePickerSheetDelegate

extension BabySetupViewController: DatePickerSheetDelegate {
    func datePickerSheet(_ sheet: DatePickerSheetViewController, didSelectDate date: Date) {
        birthDate = date
        updateBirthDateLabel()
    }
}
