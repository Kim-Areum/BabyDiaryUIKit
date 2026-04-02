import UIKit
import FoundationModels

// MARK: - DiaryEditorViewController

final class DiaryEditorViewController: UIViewController, CustomPhotoPickerDelegate {

    // MARK: - Properties

    private let date: Date
    private let baby: CDBaby
    private let speechManager = SpeechManager()
    var onDismiss: (() -> Void)?

    private var text = ""
    private var photoData: Data?
    private var audioFileNames: [String] = []
    private var audioTimestamps: [Date] = []
    private var isRecording = false
    private var isPlaying = false
    private var playingIndex: Int?
    private var isRefining = false

    private var cropScale: CGFloat = 1.0
    private var cropOffset: CGSize = .zero

    // MARK: - UI Elements

    private let navBar = NavBarView()
    private let mainScrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var contentTopConstraint: NSLayoutConstraint?

    // Card
    private let cardView = UIView()
    private let photoContainer = UIView()
    private let photoImageView = UIImageView()
    private let photoZoomScrollView = UIScrollView()
    private let photoPlaceholderButton = UIButton(type: .system)
    private let photoDeleteButton = UIButton(type: .system)
    private let photoPickerButton = UIButton(type: .system)

    // Card body
    private let cardBodyView = UIView()
    private let dateBadge = DateBadgeView(text: "")
    private let dayCountLabel = UILabel()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()

    // Bottom bar in card
    private let refineButton = UIButton(type: .system)
    private let refineSpinner = UIActivityIndicatorView(style: .medium)
    private let audioCountButton = UIButton(type: .system)

    // Voice record button
    private let recordButton = UIButton(type: .system)
    private let deleteEntryButton = UIButton(type: .system)

    // Overlay views (popups)
    private var dimView: UIView?

    // MARK: - Card sizing

    private let cardAspectRatio: CGFloat = 94.0 / 128.0

    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width * 0.85
    }

    // MARK: - Init

    init(date: Date, baby: CDBaby) {
        self.date = date
        self.baby = baby
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupScrollView()
        setupCard()
        setupRecordButton()
        loadEntry()
        updateUI()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        mainScrollView.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Setup NavBar

    private func setupNavBar() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        navBar.titleLabel.text = formattedDate(date)

        // Left: X button
        navBar.leftButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        navBar.leftButton.tintColor = DS.fgStrong
        navBar.leftButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // Right: 저장 button (custom styled)
        let saveLabel = UILabel()
        saveLabel.text = "저장"
        saveLabel.font = DS.font(15)
        saveLabel.textColor = DS.fgStrong

        let saveBg = UIView()
        saveBg.backgroundColor = DS.accent
        saveBg.layer.cornerRadius = 15
        saveBg.isUserInteractionEnabled = false

        saveBg.translatesAutoresizingMaskIntoConstraints = false
        saveLabel.translatesAutoresizingMaskIntoConstraints = false
        saveBg.addSubview(saveLabel)
        navBar.addSubview(saveBg)

        NSLayoutConstraint.activate([
            saveLabel.centerXAnchor.constraint(equalTo: saveBg.centerXAnchor),
            saveLabel.centerYAnchor.constraint(equalTo: saveBg.centerYAnchor),
            saveBg.widthAnchor.constraint(equalToConstant: 56),
            saveBg.heightAnchor.constraint(equalToConstant: 30),
            saveBg.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            saveBg.centerYAnchor.constraint(equalTo: navBar.titleLabel.centerYAnchor),
        ])

        // Hide default right button, use custom tap
        navBar.rightButton.isHidden = true
        let saveTap = UITapGestureRecognizer(target: self, action: #selector(saveTapped))
        saveBg.addGestureRecognizer(saveTap)
        saveBg.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Setup ScrollView

    private func setupScrollView() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.keyboardDismissMode = .interactive
        mainScrollView.showsVerticalScrollIndicator = false
        view.addSubview(mainScrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor, constant: -200),
            contentStack.centerXAnchor.constraint(equalTo: mainScrollView.centerXAnchor),
            contentStack.widthAnchor.constraint(equalToConstant: cardWidth),
        ])

        contentTopConstraint = contentStack.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor, constant: 60)
        contentTopConstraint?.isActive = true
    }

    // MARK: - Setup Card

    private func setupCard() {
        // Card container
        cardView.backgroundColor = DS.bgBase
        cardView.layer.cornerRadius = 8
        cardView.layer.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false

        // Card wrapper for shadow
        let cardWrapper = UIView()
        cardWrapper.translatesAutoresizingMaskIntoConstraints = false
        cardWrapper.backgroundColor = .clear
        cardWrapper.layer.shadowColor = UIColor.black.cgColor
        cardWrapper.layer.shadowOpacity = 0.08
        cardWrapper.layer.shadowRadius = 4
        cardWrapper.layer.shadowOffset = CGSize(width: 0, height: 2)

        cardWrapper.addSubview(cardView)
        contentStack.addArrangedSubview(cardWrapper)

        // Border overlay
        let borderOverlay = UIView()
        borderOverlay.translatesAutoresizingMaskIntoConstraints = false
        borderOverlay.isUserInteractionEnabled = false
        borderOverlay.layer.cornerRadius = 8
        borderOverlay.layer.borderWidth = 0.5
        borderOverlay.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        cardView.addSubview(borderOverlay)

        let cardHeight = cardWidth / cardAspectRatio

        NSLayoutConstraint.activate([
            cardWrapper.widthAnchor.constraint(equalToConstant: cardWidth),
            cardWrapper.heightAnchor.constraint(equalToConstant: cardHeight),

            cardView.topAnchor.constraint(equalTo: cardWrapper.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: cardWrapper.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: cardWrapper.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: cardWrapper.bottomAnchor),

            borderOverlay.topAnchor.constraint(equalTo: cardView.topAnchor),
            borderOverlay.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            borderOverlay.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            borderOverlay.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
        ])

        setupPhotoArea()
        setupCardBody()
    }

    // MARK: - Photo Area

    private func setupPhotoArea() {
        let photoHeight = cardWidth * 0.65

        photoContainer.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.clipsToBounds = true
        photoContainer.layer.cornerRadius = 8
        photoContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.addSubview(photoContainer)

        NSLayoutConstraint.activate([
            photoContainer.topAnchor.constraint(equalTo: cardView.topAnchor),
            photoContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            photoContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            photoContainer.heightAnchor.constraint(equalToConstant: photoHeight),
        ])

        // Zoom scroll view for pinch-to-zoom
        photoZoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        photoZoomScrollView.delegate = self
        photoZoomScrollView.minimumZoomScale = 1.0
        photoZoomScrollView.maximumZoomScale = 5.0
        photoZoomScrollView.showsHorizontalScrollIndicator = false
        photoZoomScrollView.showsVerticalScrollIndicator = false
        photoZoomScrollView.bouncesZoom = true
        photoZoomScrollView.isHidden = true
        photoContainer.addSubview(photoZoomScrollView)

        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoZoomScrollView.addSubview(photoImageView)

        NSLayoutConstraint.activate([
            photoZoomScrollView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoZoomScrollView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            photoZoomScrollView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            photoZoomScrollView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),

            photoImageView.widthAnchor.constraint(equalTo: photoZoomScrollView.widthAnchor),
            photoImageView.heightAnchor.constraint(equalTo: photoZoomScrollView.heightAnchor),
        ])

        // Placeholder button (no photo)
        photoPlaceholderButton.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.addSubview(photoPlaceholderButton)

        var placeholderConfig = UIButton.Configuration.plain()
        placeholderConfig.image = UIImage(systemName: "photo.badge.plus")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 28)
        )
        placeholderConfig.imagePlacement = .top
        placeholderConfig.imagePadding = 8
        placeholderConfig.baseForegroundColor = DS.fgPale
        var attrTitle = AttributedString("사진 추가")
        attrTitle.font = DS.font(13)
        attrTitle.foregroundColor = DS.fgPale
        placeholderConfig.attributedTitle = attrTitle
        photoPlaceholderButton.configuration = placeholderConfig
        photoPlaceholderButton.backgroundColor = DS.bgSubtle
        photoPlaceholderButton.layer.cornerRadius = 8
        photoPlaceholderButton.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        photoPlaceholderButton.clipsToBounds = true
        photoPlaceholderButton.addTarget(self, action: #selector(showPhotoPicker), for: .touchUpInside)

        NSLayoutConstraint.activate([
            photoPlaceholderButton.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoPlaceholderButton.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            photoPlaceholderButton.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            photoPlaceholderButton.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),
        ])

        // Delete and picker buttons overlay (when photo exists)
        let overlayStack = UIStackView()
        overlayStack.axis = .horizontal
        overlayStack.spacing = 10
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.addSubview(overlayStack)

        configureCircleButton(photoDeleteButton, systemName: "trash")
        photoDeleteButton.addTarget(self, action: #selector(deletePhotoTapped), for: .touchUpInside)

        configureCircleButton(photoPickerButton, systemName: "photo.on.rectangle")
        photoPickerButton.addTarget(self, action: #selector(showPhotoPicker), for: .touchUpInside)

        overlayStack.addArrangedSubview(photoDeleteButton)
        overlayStack.addArrangedSubview(photoPickerButton)

        NSLayoutConstraint.activate([
            overlayStack.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor, constant: -10),
            overlayStack.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: -8),
        ])
    }

    private func configureCircleButton(_ button: UIButton, systemName: String) {
        button.setImage(UIImage(systemName: systemName)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12)
        ), for: .normal)
        button.tintColor = DS.fgMuted
        button.backgroundColor = DS.bgBase.withAlphaComponent(0.8)
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 0.5
        button.layer.borderColor = DS.line.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    // MARK: - Card Body

    private func setupCardBody() {
        cardBodyView.translatesAutoresizingMaskIntoConstraints = false
        cardBodyView.isUserInteractionEnabled = true
        cardView.addSubview(cardBodyView)

        NSLayoutConstraint.activate([
            cardBodyView.topAnchor.constraint(equalTo: photoContainer.bottomAnchor),
            cardBodyView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardBodyView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardBodyView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
        ])

        // Date badge + D+ count row
        let dateRow = UIStackView()
        dateRow.axis = .horizontal
        dateRow.alignment = .center
        dateRow.translatesAutoresizingMaskIntoConstraints = false
        cardBodyView.addSubview(dateRow)

        dateBadge.update(text: formattedDate(date))
        dateBadge.translatesAutoresizingMaskIntoConstraints = false

        dayCountLabel.text = baby.dayAndMonthAt(date: date)
        dayCountLabel.font = DS.font(11)
        dayCountLabel.textColor = DS.fgPale
        dayCountLabel.translatesAutoresizingMaskIntoConstraints = false

        dateRow.addArrangedSubview(dateBadge)
        dateRow.addArrangedSubview(UIView()) // spacer
        dateRow.addArrangedSubview(dayCountLabel)

        NSLayoutConstraint.activate([
            dateRow.topAnchor.constraint(equalTo: cardBodyView.topAnchor, constant: 14),
            dateRow.leadingAnchor.constraint(equalTo: cardBodyView.leadingAnchor),
            dateRow.trailingAnchor.constraint(equalTo: cardBodyView.trailingAnchor),
        ])

        // Text view with placeholder
        let textContainer = UIView()
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        cardBodyView.addSubview(textContainer)

        placeholderLabel.text = "오늘 우리 아기와의 하루는 어땠나요?"
        placeholderLabel.font = DS.font(15)
        placeholderLabel.textColor = DS.fgPale
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.font = DS.font(15)
        textView.textColor = DS.fgStrong
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 1, bottom: 8, right: 1)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false

        textContainer.addSubview(placeholderLabel)
        textContainer.addSubview(textView)

        NSLayoutConstraint.activate([
            textContainer.topAnchor.constraint(equalTo: dateRow.bottomAnchor, constant: 8),
            textContainer.leadingAnchor.constraint(equalTo: cardBodyView.leadingAnchor),
            textContainer.trailingAnchor.constraint(equalTo: cardBodyView.trailingAnchor),
            textContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            placeholderLabel.topAnchor.constraint(equalTo: textContainer.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 5),

            textView.topAnchor.constraint(equalTo: textContainer.topAnchor),
            textView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),
        ])

        // Audio count button
        audioCountButton.translatesAutoresizingMaskIntoConstraints = false
        audioCountButton.addTarget(self, action: #selector(audioCountTapped), for: .touchUpInside)
        audioCountButton.contentEdgeInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        audioCountButton.backgroundColor = DS.bgSubtle
        audioCountButton.layer.cornerRadius = 12
        cardBodyView.addSubview(audioCountButton)

        NSLayoutConstraint.activate([
            audioCountButton.topAnchor.constraint(equalTo: textContainer.bottomAnchor, constant: 8),
            audioCountButton.trailingAnchor.constraint(equalTo: cardBodyView.trailingAnchor),
            audioCountButton.bottomAnchor.constraint(equalTo: cardBodyView.bottomAnchor, constant: -2),
        ])
    }

    // MARK: - Record Button

    private func setupRecordButton() {
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.layer.cornerRadius = 22
        recordButton.clipsToBounds = true
        recordButton.layer.shadowColor = UIColor.black.cgColor
        recordButton.layer.shadowOpacity = 0.06
        recordButton.layer.shadowRadius = 4
        recordButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(recordButton)

        NSLayoutConstraint.activate([
            recordButton.widthAnchor.constraint(equalToConstant: cardWidth),
            recordButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        updateRecordButton()

        // 삭제 버튼 (화면 하단 고정, 컨텐츠 있을 때만)
        setupDeleteButton()
    }

    private func setupDeleteButton() {
        let trashConfig = UIImage.SymbolConfiguration(pointSize: 13)
        deleteEntryButton.setImage(UIImage(systemName: "trash", withConfiguration: trashConfig), for: .normal)
        deleteEntryButton.tintColor = DS.fgPale
        deleteEntryButton.addTarget(self, action: #selector(deleteEntryTapped), for: .touchUpInside)
        deleteEntryButton.isHidden = true
        deleteEntryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deleteEntryButton)

        NSLayoutConstraint.activate([
            deleteEntryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deleteEntryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            deleteEntryButton.widthAnchor.constraint(equalToConstant: 32),
            deleteEntryButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        updateDeleteButtonVisibility()
    }

    private func updateDeleteButtonVisibility() {
        let entry = CoreDataStack.shared.fetchEntry(for: date)
        let hasContent = entry != nil && (!entry!.text.isEmpty || entry!.photoData != nil)
        deleteEntryButton.isHidden = !hasContent
    }

    // MARK: - UI Updates

    private func updateUI() {
        updatePhotoArea()
        updatePlaceholder()
        updateRefineButton()
        updateAudioCountButton()
        updateRecordButton()
    }

    private func updatePhotoArea() {
        let hasPhoto = photoData != nil
        photoZoomScrollView.isHidden = !hasPhoto
        photoPlaceholderButton.isHidden = hasPhoto
        photoDeleteButton.isHidden = !hasPhoto
        photoPickerButton.isHidden = !hasPhoto

        if let data = photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoZoomScrollView.zoomScale = 1.0
        }
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }

    private func updateRefineButton() {
        let hasText = !text.isEmpty

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = DS.bgSubtle
        config.baseForegroundColor = DS.fgMuted

        if isRefining {
            config.image = nil
            config.title = "문장 다듬기"
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attrs = incoming
                attrs.font = DS.font(11)
                return attrs
            }
            refineButton.configuration = config
            // Add spinner manually
            refineButton.addSubview(refineSpinner)
            refineSpinner.startAnimating()
            NSLayoutConstraint.activate([
                refineSpinner.leadingAnchor.constraint(equalTo: refineButton.leadingAnchor, constant: 8),
                refineSpinner.centerYAnchor.constraint(equalTo: refineButton.centerYAnchor),
            ])
        } else {
            refineSpinner.stopAnimating()
            refineSpinner.removeFromSuperview()

            config.image = UIImage(systemName: "wand.and.stars")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 13)
            )
            config.imagePadding = 4
            config.title = "문장 다듬기"
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attrs = incoming
                attrs.font = DS.font(11)
                return attrs
            }
            refineButton.configuration = config
        }

        refineButton.isHidden = !hasText
        refineButton.isEnabled = !isRefining
    }

    private func updateAudioCountButton() {
        let hasAudio = !audioFileNames.isEmpty
        audioCountButton.isHidden = !hasAudio

        if hasAudio {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.baseBackgroundColor = DS.bgSubtle
            config.baseForegroundColor = DS.fgMuted
            config.image = UIImage(systemName: "waveform")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 12)
            )
            config.imagePadding = 4
            config.title = "\(audioFileNames.count)"
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attrs = incoming
                attrs.font = DS.font(11)
                return attrs
            }
            audioCountButton.configuration = config
        }
    }

    private func updateRecordButton() {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule

        if isRecording {
            config.baseBackgroundColor = UIColor(hex: "E8A0A0")
            config.baseForegroundColor = .white
            config.image = UIImage(systemName: "stop.circle.fill")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16)
            )
            config.title = "녹음 중..."
        } else {
            config.baseBackgroundColor = DS.accent
            config.baseForegroundColor = DS.fgStrong
            config.image = UIImage(systemName: "mic.fill")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16)
            )
            config.title = "음성으로 기록"
        }
        config.imagePadding = 6
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(15)
            return attrs
        }
        recordButton.configuration = config
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func saveTapped() {
        save()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func deleteEntryTapped() {
        let overlay = UIView()
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.tag = 9300

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(popup)

        let titleLabel = UILabel()
        titleLabel.text = "이 기록을 삭제할까요?"
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("취소", for: .normal)
        cancelBtn.titleLabel?.font = DS.font(13)
        cancelBtn.setTitleColor(DS.fgMuted, for: .normal)
        cancelBtn.backgroundColor = DS.bgSubtle
        cancelBtn.layer.cornerRadius = 10
        cancelBtn.addTarget(self, action: #selector(dismissDeleteEntryPopup), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle("삭제", for: .normal)
        confirmBtn.titleLabel?.font = DS.font(13)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.backgroundColor = UIColor(hex: "E8A0A0")
        confirmBtn.layer.cornerRadius = 10
        confirmBtn.addTarget(self, action: #selector(confirmDeleteEntry), for: .touchUpInside)
        confirmBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = UIStackView(arrangedSubviews: [cancelBtn, confirmBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        popup.addSubview(titleLabel)
        popup.addSubview(btnStack)

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            popup.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.75),

            titleLabel.topAnchor.constraint(equalTo: popup.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -24),

            btnStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            btnStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 24),
            btnStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -24),
            btnStack.heightAnchor.constraint(equalToConstant: 40),
            btnStack.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -24),
        ])

        view.addSubview(overlay)
    }

    @objc private func dismissDeleteEntryPopup() {
        view.viewWithTag(9300)?.removeFromSuperview()
    }

    @objc private func confirmDeleteEntry() {
        view.viewWithTag(9300)?.removeFromSuperview()
        if let entry = CoreDataStack.shared.fetchEntry(for: date) {
            for fileName in entry.audioFileNamesArray {
                let url = SpeechManager.recordingsDirectory().appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: url)
            }
            CoreDataStack.shared.deleteEntry(entry)
        }
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func showPhotoPicker() {
        let picker = CustomPhotoPickerViewController(date: date)
        picker.delegate = self
        picker.cropAspectRatio = 1.0 / 0.65
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }

    func photoPicker(_ picker: CustomPhotoPickerViewController, didSelect image: UIImage) {
        photoData = image.jpegData(compressionQuality: 0.8)
        cropScale = 1.0
        cropOffset = .zero
        updatePhotoArea()
        updateDeleteButtonVisibility()
    }

    @objc private func deletePhotoTapped() {
        showDeletePhotoPopup()
    }

    @objc private func refineTapped() {
        refineEditorText()
    }

    @objc private func audioCountTapped() {
        showPlaybackPopup()
    }

    @objc private func recordTapped() {
        toggleRecording()
    }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let keyboardHeight = frame.height

        mainScrollView.contentInset.bottom = keyboardHeight
        mainScrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight

        // 카드 위로 + 음성 버튼이 키보드 바로 위에 보이도록 스크롤
        contentTopConstraint?.constant = 20
        self.view.layoutIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            let recordFrameInScroll = self.recordButton.convert(self.recordButton.bounds, to: self.mainScrollView)
            let visibleHeight = self.mainScrollView.bounds.height - keyboardHeight
            let targetOffset = max(0, recordFrameInScroll.maxY - visibleHeight + 10)
            UIView.animate(withDuration: duration) {
                self.mainScrollView.contentOffset.y = targetOffset
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        // 카드 원래 위치로
        contentTopConstraint?.constant = 60
        UIView.animate(withDuration: duration) {
            self.mainScrollView.contentInset.bottom = 0
            self.mainScrollView.verticalScrollIndicatorInsets.bottom = 0
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Voice Recording

    private func toggleRecording() {
        if isRecording {
            speechManager.stopRecording { [weak self] text, fileName in
                guard let self else { return }
                if let text, !text.isEmpty {
                    self.appendVoiceResult(text)
                } else {
                    self.showAlert(title: "음성이 인식되지 않았어요", message: "조금 더 가까이에서 말해보세요.")
                }
                if let fileName {
                    self.audioFileNames.append(fileName)
                    self.audioTimestamps.append(Date())
                }
                self.updateAudioCountButton()
            }
            isRecording = false
        } else {
            speechManager.startRecording()
            isRecording = true
        }
        updateRecordButton()
    }

    private func appendVoiceResult(_ voiceText: String) {
        guard !voiceText.isEmpty else { return }
        let newEntry = voiceText
        text = text.isEmpty ? newEntry : text + "\n\(newEntry)"
        textView.text = text
        updatePlaceholder()
        updateRefineButton()
    }

    // MARK: - Refine Text (FoundationModels)

    private func refineEditorText() {
        guard !text.isEmpty else { return }
        isRefining = true
        updateRefineButton()

        if #available(iOS 26.0, *) {
            Task { @MainActor in
                do {
                    let session = LanguageModelSession()
                    let prompt = "다음 한국어 일기 문장의 어색한 표현만 자연스럽게 다듬어줘. 의미는 바꾸지 마. 다듬어진 문장만 출력해:\n\n\(text)"
                    let response = try await session.respond(to: prompt)
                    text = response.content
                    textView.text = text
                } catch {
                    showAlert(title: "이 기기에서는 지원되지 않아요", message: "Apple Intelligence를 지원하는 기기가 필요해요.")
                }
                isRefining = false
                updateRefineButton()
            }
        } else {
            isRefining = false
            updateRefineButton()
            showAlert(title: "이 기기에서는 지원되지 않아요", message: "Apple Intelligence를 지원하는 기기가 필요해요.")
        }
    }

    // MARK: - Data

    private func loadEntry() {
        if let entry = CoreDataStack.shared.fetchEntry(for: date) {
            text = entry.text
            photoData = entry.photoData
            audioFileNames = entry.audioFileNamesArray
            audioTimestamps = entry.audioTimestampsArray
            textView.text = text
        }
    }

    private func save() {
        if let entry = CoreDataStack.shared.fetchEntry(for: date) {
            entry.text = text
            entry.photoData = photoData
            entry.audioFileNamesArray = audioFileNames
            entry.audioTimestampsArray = audioTimestamps
            CoreDataStack.shared.save()
        } else {
            _ = CoreDataStack.shared.createEntry(
                date: date,
                text: text,
                photoData: photoData,
                audioFileNames: audioFileNames,
                audioTimestamps: audioTimestamps
            )
        }
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        return f.string(from: date)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // MARK: - Custom Alert (non-system)

    private func showAlert(title: String, message: String) {
        let dim = createDimView()
        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = DS.font(13)
        messageLabel.textColor = DS.fgMuted
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let okButton = UIButton(type: .system)
        var okConfig = UIButton.Configuration.filled()
        okConfig.baseBackgroundColor = DS.bgSubtle
        okConfig.baseForegroundColor = DS.fgMuted
        okConfig.cornerStyle = .medium
        okConfig.title = "확인"
        okConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        okButton.configuration = okConfig
        okButton.addAction(UIAction { [weak self] _ in
            self?.removeDimView()
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, okButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        popup.addSubview(stack)
        dim.addSubview(popup)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: popup.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -24),

            okButton.heightAnchor.constraint(equalToConstant: 40),

            popup.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 0.75),
        ])
    }

    // MARK: - Delete Photo Popup

    private func showDeletePhotoPopup() {
        let dim = createDimView()
        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "사진을 삭제할까요?"
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center

        let cancelButton = UIButton(type: .system)
        var cancelConfig = UIButton.Configuration.filled()
        cancelConfig.baseBackgroundColor = DS.bgSubtle
        cancelConfig.baseForegroundColor = DS.fgMuted
        cancelConfig.cornerStyle = .medium
        cancelConfig.title = "취소"
        cancelConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        cancelButton.configuration = cancelConfig
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.removeDimView()
        }, for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        var deleteConfig = UIButton.Configuration.filled()
        deleteConfig.baseBackgroundColor = UIColor(hex: "E8A0A0")
        deleteConfig.baseForegroundColor = .white
        deleteConfig.cornerStyle = .medium
        deleteConfig.title = "삭제"
        deleteConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        deleteButton.configuration = deleteConfig
        deleteButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.photoData = nil
            self.cropScale = 1.0
            self.cropOffset = .zero
            self.updatePhotoArea()
            self.removeDimView()
        }, for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, deleteButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, buttonRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        popup.addSubview(stack)
        dim.addSubview(popup)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: popup.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -24),

            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            deleteButton.heightAnchor.constraint(equalToConstant: 40),

            popup.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 0.75),
        ])
    }

    // MARK: - Playback Popup

    private func showPlaybackPopup() {
        let dim = createDimView()

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.tag = 9999

        dim.addSubview(popup)

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 0.85),
        ])

        buildPlaybackContent(in: popup)
    }

    private func buildPlaybackContent(in popup: UIView) {
        // Remove existing subviews
        popup.subviews.forEach { $0.removeFromSuperview() }

        // Header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "녹음 파일"
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong

        let countLabel = UILabel()
        countLabel.text = "\(audioFileNames.count)개"
        countLabel.font = DS.font(11)
        countLabel.textColor = DS.fgMuted

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = DS.fgStrong
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismissPlayback()
        }, for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(countLabel)
        headerStack.addArrangedSubview(closeButton)
        headerStack.spacing = 8

        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Separator
        let topSep = UIView()
        topSep.backgroundColor = DS.line
        topSep.translatesAutoresizingMaskIntoConstraints = false

        // Audio list in scroll view
        let listScroll = UIScrollView()
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        listScroll.showsVerticalScrollIndicator = true

        let listStack = UIStackView()
        listStack.axis = .vertical
        listStack.translatesAutoresizingMaskIntoConstraints = false
        listScroll.addSubview(listStack)

        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: listScroll.contentLayoutGuide.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: listScroll.contentLayoutGuide.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: listScroll.contentLayoutGuide.trailingAnchor),
            listStack.bottomAnchor.constraint(equalTo: listScroll.contentLayoutGuide.bottomAnchor),
            listStack.widthAnchor.constraint(equalTo: listScroll.frameLayoutGuide.widthAnchor),
        ])

        for (index, _) in audioFileNames.enumerated() {
            let row = createAudioRow(index: index, popup: popup)
            listStack.addArrangedSubview(row)

            if index < audioFileNames.count - 1 {
                let sep = UIView()
                sep.backgroundColor = DS.line
                sep.translatesAutoresizingMaskIntoConstraints = false
                listStack.addArrangedSubview(sep)
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            }
        }

        // Bottom separator
        let bottomSep = UIView()
        bottomSep.backgroundColor = DS.line
        bottomSep.translatesAutoresizingMaskIntoConstraints = false

        // Play all button
        let playAllButton = UIButton(type: .system)
        var playAllConfig = UIButton.Configuration.plain()
        playAllConfig.baseForegroundColor = DS.fgStrong
        playAllConfig.image = UIImage(systemName: isPlaying ? "stop.fill" : "play.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12)
        )
        playAllConfig.imagePadding = 6
        playAllConfig.title = isPlaying ? "전체 중지" : "전체 재생"
        playAllConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        playAllButton.configuration = playAllConfig
        playAllButton.addAction(UIAction { [weak self] _ in
            self?.togglePlayAll(popup: popup)
        }, for: .touchUpInside)

        // Layout
        popup.addSubview(headerStack)
        popup.addSubview(topSep)
        popup.addSubview(listScroll)
        popup.addSubview(bottomSep)
        popup.addSubview(playAllButton)

        playAllButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: popup.topAnchor, constant: 18),
            headerStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),

            topSep.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            topSep.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 0.5),

            listScroll.topAnchor.constraint(equalTo: topSep.bottomAnchor),
            listScroll.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            listScroll.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            listScroll.heightAnchor.constraint(equalToConstant: min(CGFloat(audioFileNames.count) * 52 + CGFloat(max(0, audioFileNames.count - 1)) * 0.5, 300)),

            bottomSep.topAnchor.constraint(equalTo: listScroll.bottomAnchor),
            bottomSep.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            bottomSep.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            bottomSep.heightAnchor.constraint(equalToConstant: 0.5),

            playAllButton.topAnchor.constraint(equalTo: bottomSep.bottomAnchor, constant: 10),
            playAllButton.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            playAllButton.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),
            playAllButton.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -10),
            playAllButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func createAudioRow(index: Int, popup: UIView) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let playIcon = UIImageView()
        let isCurrentPlaying = playingIndex == index
        playIcon.image = UIImage(systemName: isCurrentPlaying ? "pause.circle.fill" : "play.circle.fill")
        playIcon.tintColor = isCurrentPlaying ? UIColor(hex: "D05050") : DS.accent
        playIcon.contentMode = .scaleAspectFit
        playIcon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "녹음 \(index + 1)"
        nameLabel.font = DS.font(13)
        nameLabel.textColor = DS.fgStrong

        let timeLabel = UILabel()
        if index < audioTimestamps.count {
            timeLabel.text = formatTimestamp(audioTimestamps[index])
        }
        timeLabel.font = DS.font(11)
        timeLabel.textColor = DS.fgPale

        let textStack = UIStackView(arrangedSubviews: [nameLabel, timeLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let trashButton = UIButton(type: .system)
        trashButton.setImage(UIImage(systemName: "trash")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 13)
        ), for: .normal)
        trashButton.tintColor = DS.fgPale
        trashButton.translatesAutoresizingMaskIntoConstraints = false
        trashButton.tag = index
        trashButton.addAction(UIAction { [weak self] action in
            guard let self, let sender = action.sender as? UIButton else { return }
            self.showDeleteAudioPopup(index: sender.tag, parentPopup: popup)
        }, for: .touchUpInside)

        row.addSubview(playIcon)
        row.addSubview(textStack)
        row.addSubview(trashButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 52),

            playIcon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            playIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 22),
            playIcon.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: playIcon.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            trashButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            trashButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            trashButton.widthAnchor.constraint(equalToConstant: 28),
            trashButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Tap to toggle single play
        let tap = UITapGestureRecognizer(target: self, action: #selector(audioRowTapped(_:)))
        row.addGestureRecognizer(tap)
        row.tag = 10000 + index
        row.isUserInteractionEnabled = true

        return row
    }

    @objc private func audioRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view else { return }
        let index = row.tag - 10000
        toggleSinglePlay(index: index)
    }

    private func toggleSinglePlay(index: Int) {
        if playingIndex == index {
            speechManager.stopPlayback()
            isPlaying = false
            playingIndex = nil
        } else {
            speechManager.stopPlayback()
            playingIndex = index
            isPlaying = true
            speechManager.playAll(fileNames: [audioFileNames[index]]) { [weak self] in
                self?.playingIndex = nil
                self?.isPlaying = false
                self?.refreshPlaybackPopupIfVisible()
            }
        }
        refreshPlaybackPopupIfVisible()
    }

    private func togglePlayAll(popup: UIView) {
        if isPlaying {
            speechManager.stopPlayback()
            isPlaying = false
            playingIndex = nil
        } else {
            isPlaying = true
            playingIndex = 0
            speechManager.playAll(fileNames: audioFileNames) { [weak self] in
                self?.isPlaying = false
                self?.playingIndex = nil
                self?.refreshPlaybackPopupIfVisible()
            }
        }
        buildPlaybackContent(in: popup)
    }

    private func refreshPlaybackPopupIfVisible() {
        guard let dim = dimView, let popup = dim.viewWithTag(9999) else { return }
        buildPlaybackContent(in: popup)
    }

    private func dismissPlayback() {
        if isPlaying {
            speechManager.stopPlayback()
            isPlaying = false
            playingIndex = nil
        }
        removeDimView()
    }

    // MARK: - Delete Audio Popup

    private func showDeleteAudioPopup(index: Int, parentPopup: UIView) {
        // Overlay on top of parentPopup
        let overlay = UIView()
        overlay.backgroundColor = DS.bgBase
        overlay.layer.cornerRadius = 20
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.tag = 8888
        parentPopup.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: parentPopup.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: parentPopup.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: parentPopup.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: parentPopup.bottomAnchor),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "녹음 \(index + 1)을 삭제할까요?"
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center

        let cancelButton = UIButton(type: .system)
        var cancelConfig = UIButton.Configuration.filled()
        cancelConfig.baseBackgroundColor = DS.bgSubtle
        cancelConfig.baseForegroundColor = DS.fgMuted
        cancelConfig.cornerStyle = .medium
        cancelConfig.title = "취소"
        cancelConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        cancelButton.configuration = cancelConfig
        cancelButton.addAction(UIAction { _ in
            overlay.removeFromSuperview()
        }, for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        var deleteConfig = UIButton.Configuration.filled()
        deleteConfig.baseBackgroundColor = UIColor(hex: "E8A0A0")
        deleteConfig.baseForegroundColor = .white
        deleteConfig.cornerStyle = .medium
        deleteConfig.title = "삭제"
        deleteConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = DS.font(13)
            return attrs
        }
        deleteButton.configuration = deleteConfig
        deleteButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.deleteAudio(at: index, parentPopup: parentPopup)
            overlay.removeFromSuperview()
        }, for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, deleteButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, buttonRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),

            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            deleteButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func deleteAudio(at index: Int, parentPopup: UIView) {
        if playingIndex == index {
            speechManager.stopPlayback()
            isPlaying = false
            playingIndex = nil
        }

        let fileName = audioFileNames[index]
        let url = SpeechManager.recordingsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        audioFileNames.remove(at: index)
        if index < audioTimestamps.count {
            audioTimestamps.remove(at: index)
        }

        if audioFileNames.isEmpty {
            removeDimView()
            updateAudioCountButton()
        } else {
            buildPlaybackContent(in: parentPopup)
            updateAudioCountButton()
        }
    }

    // MARK: - Dim View Helpers

    @discardableResult
    private func createDimView() -> UIView {
        removeDimView()

        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dim.translatesAutoresizingMaskIntoConstraints = false
        dim.alpha = 0
        view.addSubview(dim)

        NSLayoutConstraint.activate([
            dim.topAnchor.constraint(equalTo: view.topAnchor),
            dim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dimTapped(_:)))
        dim.addGestureRecognizer(dismissTap)

        dimView = dim

        UIView.animate(withDuration: 0.2) {
            dim.alpha = 1
        }

        return dim
    }

    @objc private func dimTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: dimView)
        // Only dismiss if tapping outside popup content
        for subview in dimView?.subviews ?? [] {
            if subview.frame.contains(location) {
                return
            }
        }
        // If playback popup is showing, stop playback
        if dimView?.viewWithTag(9999) != nil {
            dismissPlayback()
        } else {
            removeDimView()
        }
    }

    private func removeDimView() {
        guard let dim = dimView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            dim.alpha = 0
        }, completion: { _ in
            dim.removeFromSuperview()
        })
        dimView = nil
    }
}

// MARK: - UIScrollViewDelegate (Photo Zoom)

extension DiaryEditorViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView == photoZoomScrollView {
            return photoImageView
        }
        return nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView == photoZoomScrollView {
            cropScale = scrollView.zoomScale
            let offsetX = scrollView.contentOffset.x
            let offsetY = scrollView.contentOffset.y
            cropOffset = CGSize(width: offsetX, height: offsetY)
        }
    }
}

// MARK: - UITextViewDelegate

extension DiaryEditorViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        text = textView.text ?? ""
        updatePlaceholder()
        updateRefineButton()
    }
}
