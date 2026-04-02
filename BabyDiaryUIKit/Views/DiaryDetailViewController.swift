import UIKit
import AVFoundation

class DiaryDetailViewController: UIViewController {

    // MARK: - Properties

    var entry: CDDiaryEntry!
    var baby: CDBaby!
    var onDismiss: (() -> Void)?
    var onEdit: ((CDDiaryEntry) -> Void)?

    convenience init(entry: CDDiaryEntry, baby: CDBaby) {
        self.init(nibName: nil, bundle: nil)
        self.entry = entry
        self.baby = baby
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let photoImageView = UIImageView()
    private let dateBadge = DateBadgeView(text: "")
    private let dayCountLabel = UILabel()
    private let textLabel = UILabel()
    private let refineButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)

    private var refinedText: String?
    private var isRefining = false

    // Menu overlay
    private var menuOverlay: UIView?
    private var deleteOverlay: UIView?

    // Audio
    private var audioPlayer: AVAudioPlayer?
    private var playbackOverlay: UIView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupScrollView()
        setupContent()
        loadEntryData()
        setupSwipeGesture()
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = entry.formattedDate

        let backConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        navBar.leftButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: backConfig), for: .normal)
        navBar.leftButton.tintColor = DS.fgStrong
        navBar.leftButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        let menuConfig = UIImage.SymbolConfiguration(pointSize: 16)
        navBar.rightButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: menuConfig), for: .normal)
        navBar.rightButton.tintColor = DS.fgStrong
        navBar.rightButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)

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
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Content

    private func setupContent() {
        // Photo
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(photoImageView)
        let photoHeight = UIScreen.main.bounds.width * 0.65
        photoImageView.heightAnchor.constraint(equalToConstant: photoHeight).isActive = true

        // Text container
        let textContainer = UIView()
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(textContainer)

        // Date badge + day count row
        let dateRow = UIView()
        dateRow.translatesAutoresizingMaskIntoConstraints = false
        textContainer.addSubview(dateRow)

        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        dateRow.addSubview(dateBadge)

        dayCountLabel.font = DS.font(11)
        dayCountLabel.textColor = DS.fgPale
        dayCountLabel.translatesAutoresizingMaskIntoConstraints = false
        dateRow.addSubview(dayCountLabel)

        NSLayoutConstraint.activate([
            dateRow.topAnchor.constraint(equalTo: textContainer.topAnchor, constant: 20),
            dateRow.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 20),
            dateRow.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -20),

            dateBadge.leadingAnchor.constraint(equalTo: dateRow.leadingAnchor),
            dateBadge.centerYAnchor.constraint(equalTo: dateRow.centerYAnchor),
            dateBadge.topAnchor.constraint(equalTo: dateRow.topAnchor),
            dateBadge.bottomAnchor.constraint(equalTo: dateRow.bottomAnchor),

            dayCountLabel.trailingAnchor.constraint(equalTo: dateRow.trailingAnchor),
            dayCountLabel.centerYAnchor.constraint(equalTo: dateRow.centerYAnchor),
        ])

        // Text label
        textLabel.font = DS.font(15)
        textLabel.textColor = DS.fgStrong
        textLabel.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textContainer.addSubview(textLabel)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: dateRow.bottomAnchor, constant: 12),
            textLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 20),
            textLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -20),
        ])

        // Action buttons row
        let actionRow = UIView()
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        textContainer.addSubview(actionRow)

        // Audio button
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        actionRow.addSubview(audioButton)

        NSLayoutConstraint.activate([
            actionRow.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 12),
            actionRow.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor, constant: 20),
            actionRow.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor, constant: -20),
            actionRow.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor, constant: -20),
            actionRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            audioButton.trailingAnchor.constraint(equalTo: actionRow.trailingAnchor),
            audioButton.centerYAnchor.constraint(equalTo: actionRow.centerYAnchor),
        ])
    }

    // MARK: - Load Data

    private func loadEntryData() {
        // Photo
        if let data = entry.photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
        } else {
            photoImageView.isHidden = true
            photoImageView.constraints.first(where: { $0.firstAttribute == .height })?.constant = 0
        }

        // Date badge & day count
        dateBadge.update(text: entry.formattedDate)
        dayCountLabel.text = baby.dayAndMonthAt(date: entry.date)

        // Text
        updateTextDisplay()

        // Refine button
        configureRefineButton()

        // Audio button
        configureAudioButton()
    }

    private func updateTextDisplay() {
        let displayText = refinedText ?? entry.text
        if !displayText.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            textLabel.attributedText = NSAttributedString(
                string: displayText,
                attributes: [
                    .font: DS.font(15),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            textLabel.isHidden = false
        } else {
            textLabel.isHidden = true
        }
    }

    private func configureRefineButton() {
        guard !entry.text.isEmpty else {
            refineButton.isHidden = true
            return
        }
        refineButton.isHidden = false

        let title = refinedText != nil ? "다시 다듬기" : "문장 다듬기"
        let iconName = "wand.and.stars"

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: iconName)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 11))
        config.title = title
        config.baseForegroundColor = DS.fgMuted
        config.baseBackgroundColor = DS.bgSubtle
        config.cornerStyle = .capsule
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DS.font(11)
            return outgoing
        }
        refineButton.configuration = config
        refineButton.removeTarget(nil, action: nil, for: .touchUpInside)
        refineButton.addTarget(self, action: #selector(refineTapped), for: .touchUpInside)
    }

    private func configureAudioButton() {
        let audioFiles = entry.audioFileNamesArray
        guard !audioFiles.isEmpty else {
            audioButton.isHidden = true
            return
        }
        audioButton.isHidden = false

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "waveform")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 12))
        config.title = "\(audioFiles.count)"
        config.baseForegroundColor = DS.fgMuted
        config.baseBackgroundColor = DS.bgSubtle
        config.cornerStyle = .capsule
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DS.font(11)
            return outgoing
        }
        audioButton.configuration = config
        audioButton.removeTarget(nil, action: nil, for: .touchUpInside)
        audioButton.addTarget(self, action: #selector(audioTapped), for: .touchUpInside)
    }

    // MARK: - Swipe Gesture

    private func setupSwipeGesture() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(backTapped))
        swipe.direction = .right
        view.addGestureRecognizer(swipe)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func menuTapped() {
        showMoreMenu()
    }

    @objc private func refineTapped() {
        // Placeholder: on-device AI refine not available in UIKit migration
        // Show unsupported alert
        let alert = UIAlertController(
            title: "이 기기에서는 지원되지 않아요",
            message: "Apple Intelligence를 지원하는 기기가 필요해요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc private func audioTapped() {
        showPlaybackPopup()
    }

    // MARK: - More Menu

    private func showMoreMenu() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.addSubview(overlay)
        menuOverlay = overlay

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        overlay.addGestureRecognizer(dismissTap)

        let menuView = UIView()
        menuView.backgroundColor = DS.bgBase
        menuView.layer.cornerRadius = 16
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOpacity = 0.15
        menuView.layer.shadowRadius = 12
        menuView.layer.shadowOffset = CGSize(width: 0, height: 4)
        menuView.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(menuView)

        let menuStack = UIStackView()
        menuStack.axis = .vertical
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuView.addSubview(menuStack)

        // Edit button
        let editButton = makeMenuButton(
            icon: "pencil",
            title: "수정",
            color: DS.fgStrong,
            action: #selector(editMenuTapped)
        )
        menuStack.addArrangedSubview(editButton)

        let sep = UIView()
        sep.backgroundColor = DS.line
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        menuStack.addArrangedSubview(sep)

        // Delete button
        let deleteButton = makeMenuButton(
            icon: "trash",
            title: "삭제",
            color: UIColor(hex: "D05050"),
            action: #selector(deleteMenuTapped)
        )
        menuStack.addArrangedSubview(deleteButton)

        let menuWidth = UIScreen.main.bounds.width * 0.75
        NSLayoutConstraint.activate([
            menuView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            menuView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            menuView.widthAnchor.constraint(equalToConstant: menuWidth),

            menuStack.topAnchor.constraint(equalTo: menuView.topAnchor),
            menuStack.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
            menuStack.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
            menuStack.bottomAnchor.constraint(equalTo: menuView.bottomAnchor),
        ])
    }

    private func makeMenuButton(icon: String, title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)

        let iconView = UIImageView(image: UIImage(systemName: icon)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 14)))
        iconView.tintColor = color
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = DS.font(13)
        label.textColor = color

        let hStack = UIStackView(arrangedSubviews: [iconView, label])
        hStack.axis = .horizontal
        hStack.spacing = 10
        hStack.isUserInteractionEnabled = false
        hStack.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 20),
            hStack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 48),
        ])

        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func dismissMenu() {
        menuOverlay?.removeFromSuperview()
        menuOverlay = nil
    }

    @objc private func editMenuTapped() {
        dismissMenu()
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onEdit?(self.entry)
        }
    }

    @objc private func deleteMenuTapped() {
        dismissMenu()
        showDeleteConfirmation()
    }

    // MARK: - Delete Confirmation

    private func showDeleteConfirmation() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.addSubview(overlay)
        deleteOverlay = overlay

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissDelete))
        overlay.addGestureRecognizer(dismissTap)

        let container = UIView()
        container.backgroundColor = DS.bgBase
        container.layer.cornerRadius = 20
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.15
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(container)

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 16
        vStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vStack)

        let messageLabel = UILabel()
        messageLabel.text = "이 기록을 삭제할까요?"
        messageLabel.font = DS.font(14)
        messageLabel.textColor = DS.fgStrong
        messageLabel.textAlignment = .center
        vStack.addArrangedSubview(messageLabel)

        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("취소", for: .normal)
        cancelBtn.titleLabel?.font = DS.font(13)
        cancelBtn.setTitleColor(DS.fgMuted, for: .normal)
        cancelBtn.backgroundColor = DS.bgSubtle
        cancelBtn.layer.cornerRadius = 10
        cancelBtn.addTarget(self, action: #selector(dismissDelete), for: .touchUpInside)
        cancelBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        buttonStack.addArrangedSubview(cancelBtn)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setTitle("삭제", for: .normal)
        deleteBtn.titleLabel?.font = DS.font(13)
        deleteBtn.setTitleColor(.white, for: .normal)
        deleteBtn.backgroundColor = UIColor(hex: "E8A0A0")
        deleteBtn.layer.cornerRadius = 10
        deleteBtn.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
        deleteBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        buttonStack.addArrangedSubview(deleteBtn)

        vStack.addArrangedSubview(buttonStack)

        let containerWidth = UIScreen.main.bounds.width * 0.75
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: containerWidth),

            vStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            vStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            vStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            vStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
        ])
    }

    @objc private func dismissDelete() {
        deleteOverlay?.removeFromSuperview()
        deleteOverlay = nil
    }

    @objc private func confirmDelete() {
        // Delete audio files
        for fileName in entry.audioFileNamesArray {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Recordings")
            let url = dir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }

        CoreDataStack.shared.deleteEntry(entry)
        deleteOverlay?.removeFromSuperview()
        deleteOverlay = nil

        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    // MARK: - Playback Popup

    private func showPlaybackPopup() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.clear
        view.addSubview(overlay)
        playbackOverlay = overlay

        let bgTap = UITapGestureRecognizer(target: self, action: #selector(dismissPlayback))
        overlay.addGestureRecognizer(bgTap)

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.tag = 999
        popup.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(popup)

        let popupWidth = UIScreen.main.bounds.width * 0.85
        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: popupWidth),
        ])

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: popup.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: popup.bottomAnchor),
        ])

        // Header
        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let headerTitle = UILabel()
        headerTitle.text = "녹음 파일"
        headerTitle.font = DS.font(14)
        headerTitle.textColor = DS.fgStrong
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(headerTitle)

        let countLabel = UILabel()
        countLabel.text = "\(entry.audioFileNamesArray.count)개"
        countLabel.font = DS.font(11)
        countLabel.textColor = DS.fgMuted
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(countLabel)

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = DS.fgStrong
        closeBtn.addTarget(self, action: #selector(dismissPlayback), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            headerTitle.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor, constant: 20),
            headerTitle.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor, constant: -20),
            closeBtn.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24),
            countLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
        ])
        vStack.addArrangedSubview(headerRow)

        let sep = UIView()
        sep.backgroundColor = DS.line
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        vStack.addArrangedSubview(sep)

        // Audio file list
        let audioFiles = entry.audioFileNamesArray
        let timestamps = entry.audioTimestampsArray

        for (index, _) in audioFiles.enumerated() {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 48).isActive = true

            let playIcon = UIImageView(image: UIImage(systemName: "play.circle.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 22)))
            playIcon.tintColor = DS.accent
            playIcon.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(playIcon)

            let nameLabel = UILabel()
            nameLabel.text = "녹음 \(index + 1)"
            nameLabel.font = DS.font(13)
            nameLabel.textColor = DS.fgStrong
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(nameLabel)

            NSLayoutConstraint.activate([
                playIcon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
                playIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                nameLabel.leadingAnchor.constraint(equalTo: playIcon.trailingAnchor, constant: 10),
                nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])

            if index < timestamps.count {
                let timeLabel = UILabel()
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.dateFormat = "a h:mm"
                timeLabel.text = formatter.string(from: timestamps[index])
                timeLabel.font = DS.font(11)
                timeLabel.textColor = DS.fgPale
                timeLabel.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(timeLabel)
                NSLayoutConstraint.activate([
                    timeLabel.leadingAnchor.constraint(equalTo: playIcon.trailingAnchor, constant: 10),
                    timeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
                ])
                row.heightAnchor.constraint(equalToConstant: 56).isActive = true
            }

            vStack.addArrangedSubview(row)

            if index < audioFiles.count - 1 {
                let divider = UIView()
                divider.backgroundColor = DS.line
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                vStack.addArrangedSubview(divider)
            }
        }

        let bottomSep = UIView()
        bottomSep.backgroundColor = DS.line
        bottomSep.translatesAutoresizingMaskIntoConstraints = false
        bottomSep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        vStack.addArrangedSubview(bottomSep)

        // Play all button
        let playAllBtn = UIButton(type: .system)
        var playAllConfig = UIButton.Configuration.plain()
        playAllConfig.image = UIImage(systemName: "play.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 12))
        playAllConfig.title = "전체 재생"
        playAllConfig.baseForegroundColor = DS.fgStrong
        playAllConfig.imagePadding = 6
        playAllConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DS.font(13)
            return outgoing
        }
        playAllBtn.configuration = playAllConfig
        playAllBtn.translatesAutoresizingMaskIntoConstraints = false
        playAllBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        vStack.addArrangedSubview(playAllBtn)
    }

    @objc private func dismissPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackOverlay?.removeFromSuperview()
        playbackOverlay = nil
    }
}
