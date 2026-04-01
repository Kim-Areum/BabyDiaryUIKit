import UIKit
import CoreData

class TodayViewController: UIViewController {

    // MARK: - Properties

    private let selectedDate = Date()
    private var baby: CDBaby? { CoreDataStack.shared.fetchBaby() }
    private var selectedEntry: CDDiaryEntry? { CoreDataStack.shared.fetchEntry(for: selectedDate) }

    private var hideElephant: Bool {
        UserDefaults.standard.bool(forKey: "hideElephant")
    }

    // MARK: - Elephant Animation

    private let elephantView = UIImageView()
    private var displayLink: CADisplayLink?
    private let elephantSize: CGFloat = 30
    private let cycleDuration: TimeInterval = 20
    private var elephantStartTime: CFTimeInterval = 0
    private let elephantFrameNames = ["Elephant2", "Elephant3"]
    private let elephantFrameInterval: TimeInterval = 0.3

    // MARK: - UI Elements

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Elephant container
    private let elephantContainer = UIView()

    // Grass overlay
    private let grassContainer = UIView()

    // Card
    private let cardButton = UIButton(type: .custom)
    private let cardView = UIView()
    private let photoImageView = UIImageView()
    private let photoPlaceholder = UIView()
    private let dateBadge = DateBadgeView(text: "")
    private let dayCountLabel = UILabel()
    private let diaryTextLabel = UILabel()
    private let audioCountButton = UIButton(type: .system)

    // Voice record button
    private let voiceButton = UIButton(type: .custom)
    private var isRecording = false

    // Card dimensions
    private var cardWidth: CGFloat {
        UIScreen.main.bounds.width * 0.85
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupLayout()
        setupCard()
        setupGrassOverlay()
        setupVoiceButton()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        startElephantAnimation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopElephantAnimation()
    }

    // MARK: - Layout

    private func setupLayout() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Content stack
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Top spacer
        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(topSpacer)
        topSpacer.heightAnchor.constraint(equalToConstant: 50).isActive = true

        // Elephant container
        setupElephantContainer()

        // Card wrapper (card + grass overlay)
        let cardWrapper = UIView()
        cardWrapper.translatesAutoresizingMaskIntoConstraints = false
        cardWrapper.clipsToBounds = false
        contentStack.addArrangedSubview(cardWrapper)

        // Card view inside wrapper
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = DS.bgBase
        cardView.layer.cornerRadius = 8
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.15
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.clipsToBounds = false
        cardWrapper.addSubview(cardView)

        // Card button overlay for taps
        cardButton.translatesAutoresizingMaskIntoConstraints = false
        cardButton.addTarget(self, action: #selector(cardTapped), for: .touchUpInside)
        cardWrapper.addSubview(cardButton)

        // Grass overlay on top of card
        grassContainer.translatesAutoresizingMaskIntoConstraints = false
        grassContainer.isUserInteractionEnabled = false
        cardWrapper.addSubview(grassContainer)

        let cw = cardWidth
        let cardHeight = cw * (128.0 / 94.0)

        NSLayoutConstraint.activate([
            cardWrapper.widthAnchor.constraint(equalToConstant: cw),
            cardWrapper.heightAnchor.constraint(equalToConstant: cardHeight),

            cardView.topAnchor.constraint(equalTo: cardWrapper.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: cardWrapper.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: cardWrapper.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: cardWrapper.bottomAnchor),

            cardButton.topAnchor.constraint(equalTo: cardWrapper.topAnchor),
            cardButton.leadingAnchor.constraint(equalTo: cardWrapper.leadingAnchor),
            cardButton.trailingAnchor.constraint(equalTo: cardWrapper.trailingAnchor),
            cardButton.bottomAnchor.constraint(equalTo: cardWrapper.bottomAnchor),

            grassContainer.topAnchor.constraint(equalTo: cardWrapper.topAnchor, constant: -20),
            grassContainer.leadingAnchor.constraint(equalTo: cardWrapper.leadingAnchor),
            grassContainer.trailingAnchor.constraint(equalTo: cardWrapper.trailingAnchor),
            grassContainer.heightAnchor.constraint(equalToConstant: 40),
        ])

        // Bottom spacing
        let bottomSpacer1 = UIView()
        bottomSpacer1.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(bottomSpacer1)
        bottomSpacer1.heightAnchor.constraint(equalToConstant: 20).isActive = true

        // Voice button
        contentStack.addArrangedSubview(voiceButton)

        // Bottom spacer
        let bottomSpacer2 = UIView()
        bottomSpacer2.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(bottomSpacer2)
        bottomSpacer2.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    }

    // MARK: - Elephant

    private func setupElephantContainer() {
        elephantContainer.translatesAutoresizingMaskIntoConstraints = false
        elephantContainer.clipsToBounds = false
        contentStack.addArrangedSubview(elephantContainer)

        NSLayoutConstraint.activate([
            elephantContainer.widthAnchor.constraint(equalToConstant: cardWidth),
            elephantContainer.heightAnchor.constraint(equalToConstant: hideElephant ? 12 : 30),
        ])

        // Negative spacing effect: overlap elephant with card below
        if !hideElephant {
            contentStack.setCustomSpacing(-10, after: elephantContainer)
        }

        elephantView.contentMode = .scaleAspectFit
        elephantView.image = UIImage(named: "Elephant2")
        elephantView.translatesAutoresizingMaskIntoConstraints = false
        elephantContainer.addSubview(elephantView)

        NSLayoutConstraint.activate([
            elephantView.widthAnchor.constraint(equalToConstant: elephantSize),
            elephantView.heightAnchor.constraint(equalToConstant: elephantSize),
            elephantView.bottomAnchor.constraint(equalTo: elephantContainer.bottomAnchor, constant: -2),
        ])

        elephantView.isHidden = hideElephant
    }

    private func startElephantAnimation() {
        guard !hideElephant else {
            elephantView.isHidden = true
            grassContainer.isHidden = true
            return
        }
        elephantView.isHidden = false
        grassContainer.isHidden = false

        elephantStartTime = CACurrentMediaTime()
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(elephantTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopElephantAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func elephantTick() {
        let elapsed = CACurrentMediaTime() - elephantStartTime
        let walkRange = cardWidth - elephantSize
        let fullCycle = cycleDuration * 2
        let phase = elapsed.truncatingRemainder(dividingBy: fullCycle)
        let goingLeft = phase < cycleDuration
        let t = goingLeft
            ? phase / cycleDuration
            : (phase - cycleDuration) / cycleDuration
        let xPos = goingLeft
            ? walkRange * (1 - t)
            : walkRange * t

        elephantView.frame.origin.x = xPos

        // Flip direction
        elephantView.transform = goingLeft ? .identity : CGAffineTransform(scaleX: -1, y: 1)

        // Frame animation (alternate images every 0.3s)
        let frameIndex = Int(elapsed / elephantFrameInterval) % 2
        let frameName = elephantFrameNames[frameIndex]
        elephantView.image = UIImage(named: frameName)
    }

    // MARK: - Grass Overlay

    private func setupGrassOverlay() {
        grassContainer.isHidden = hideElephant
        grassContainer.clipsToBounds = true

        let grassStack = UIStackView()
        grassStack.axis = .horizontal
        grassStack.spacing = -48
        grassStack.distribution = .fillEqually
        grassStack.translatesAutoresizingMaskIntoConstraints = false
        grassContainer.addSubview(grassStack)

        NSLayoutConstraint.activate([
            grassStack.topAnchor.constraint(equalTo: grassContainer.topAnchor),
            grassStack.leadingAnchor.constraint(equalTo: grassContainer.leadingAnchor),
            grassStack.trailingAnchor.constraint(equalTo: grassContainer.trailingAnchor),
            grassStack.bottomAnchor.constraint(equalTo: grassContainer.bottomAnchor),
        ])

        for _ in 0..<7 {
            let grassImageView = UIImageView(image: UIImage(named: "Grass"))
            grassImageView.contentMode = .scaleAspectFit
            grassImageView.translatesAutoresizingMaskIntoConstraints = false
            grassStack.addArrangedSubview(grassImageView)
        }

        // Apply edge fade mask to the entire grass container
        let maskLayer = CAGradientLayer()
        maskLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor,
        ]
        maskLayer.locations = [0.0, 0.01, 0.99, 1.0]
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        grassContainer.layer.mask = maskLayer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update grass mask frame
        grassContainer.layer.mask?.frame = grassContainer.bounds
    }

    // MARK: - Card Setup

    private func setupCard() {
        let innerClip = UIView()
        innerClip.translatesAutoresizingMaskIntoConstraints = false
        innerClip.clipsToBounds = true
        innerClip.layer.cornerRadius = 8
        cardView.addSubview(innerClip)

        NSLayoutConstraint.activate([
            innerClip.topAnchor.constraint(equalTo: cardView.topAnchor),
            innerClip.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            innerClip.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            innerClip.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
        ])

        // Photo area
        let cw = cardWidth
        let photoHeight = cw * 0.65

        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false

        photoPlaceholder.backgroundColor = DS.bgSubtle
        photoPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        innerClip.addSubview(photoPlaceholder)
        innerClip.addSubview(photoImageView)

        NSLayoutConstraint.activate([
            photoPlaceholder.topAnchor.constraint(equalTo: innerClip.topAnchor),
            photoPlaceholder.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor),
            photoPlaceholder.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor),
            photoPlaceholder.heightAnchor.constraint(equalToConstant: photoHeight),

            photoImageView.topAnchor.constraint(equalTo: innerClip.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor),
            photoImageView.heightAnchor.constraint(equalToConstant: photoHeight),
        ])

        // Body area
        let bodyView = UIView()
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        innerClip.addSubview(bodyView)

        NSLayoutConstraint.activate([
            bodyView.topAnchor.constraint(equalTo: photoImageView.bottomAnchor),
            bodyView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor, constant: 14),
            bodyView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor, constant: -14),
            bodyView.bottomAnchor.constraint(equalTo: innerClip.bottomAnchor, constant: -14),
        ])

        // Top row: date badge + D+ count
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(topRow)

        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        topRow.addArrangedSubview(dateBadge)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topRow.addArrangedSubview(spacer)

        dayCountLabel.font = DS.font(11)
        dayCountLabel.textColor = DS.fgPale
        dayCountLabel.translatesAutoresizingMaskIntoConstraints = false
        topRow.addArrangedSubview(dayCountLabel)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: bodyView.topAnchor, constant: 14),
            topRow.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
        ])

        // Diary text
        diaryTextLabel.font = DS.font(15)
        diaryTextLabel.textColor = DS.fgStrong
        diaryTextLabel.numberOfLines = 0
        diaryTextLabel.translatesAutoresizingMaskIntoConstraints = false

        let textScroll = UIScrollView()
        textScroll.translatesAutoresizingMaskIntoConstraints = false
        textScroll.showsVerticalScrollIndicator = false
        textScroll.isUserInteractionEnabled = false
        bodyView.addSubview(textScroll)
        textScroll.addSubview(diaryTextLabel)

        NSLayoutConstraint.activate([
            textScroll.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            textScroll.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            textScroll.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
            textScroll.heightAnchor.constraint(equalToConstant: 120),

            diaryTextLabel.topAnchor.constraint(equalTo: textScroll.topAnchor),
            diaryTextLabel.leadingAnchor.constraint(equalTo: textScroll.leadingAnchor),
            diaryTextLabel.trailingAnchor.constraint(equalTo: textScroll.trailingAnchor),
            diaryTextLabel.bottomAnchor.constraint(equalTo: textScroll.bottomAnchor),
            diaryTextLabel.widthAnchor.constraint(equalTo: textScroll.widthAnchor),
        ])

        // Audio count button
        audioCountButton.translatesAutoresizingMaskIntoConstraints = false
        audioCountButton.titleLabel?.font = DS.font(11)
        audioCountButton.setTitleColor(DS.fgMuted, for: .normal)
        audioCountButton.tintColor = DS.fgMuted
        audioCountButton.backgroundColor = DS.bgSubtle
        audioCountButton.layer.cornerRadius = 12
        audioCountButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        audioCountButton.isHidden = true
        bodyView.addSubview(audioCountButton)

        NSLayoutConstraint.activate([
            audioCountButton.topAnchor.constraint(equalTo: textScroll.bottomAnchor, constant: 4),
            audioCountButton.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
        ])
    }

    // MARK: - Voice Button

    private func setupVoiceButton() {
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.layer.cornerRadius = 22
        voiceButton.layer.shadowColor = UIColor.black.cgColor
        voiceButton.layer.shadowOpacity = 0.06
        voiceButton.layer.shadowRadius = 4
        voiceButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        voiceButton.addTarget(self, action: #selector(voiceButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            voiceButton.widthAnchor.constraint(equalToConstant: cardWidth),
            voiceButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        updateVoiceButtonAppearance()
    }

    private func updateVoiceButtonAppearance() {
        let iconName = isRecording ? "stop.circle.fill" : "mic.fill"
        let title = isRecording ? "녹음 중..." : "음성으로 기록"
        let bgColor = isRecording ? UIColor(hex: "E8A0A0") : DS.blue
        let iconColor = isRecording ? UIColor.white : DS.fgStrong

        let config = UIImage.SymbolConfiguration(pointSize: 16)
        let icon = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)

        var attString = NSMutableAttributedString()
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = icon
        attString.append(NSAttributedString(attachment: iconAttachment))
        attString.append(NSAttributedString(
            string: "  \(title)",
            attributes: [
                .font: DS.font(14),
                .foregroundColor: DS.fgStrong,
            ]
        ))
        voiceButton.setAttributedTitle(attString, for: .normal)
        voiceButton.backgroundColor = bgColor
    }

    // MARK: - Data

    func reloadData() {
        let entry = selectedEntry
        let babyObj = baby

        // Date badge
        let dateText = formattedDate(selectedDate)
        dateBadge.update(text: dateText)

        // D+ count
        if let b = babyObj {
            dayCountLabel.text = "D+\(b.dayCountAt(date: selectedDate))"
        } else {
            dayCountLabel.text = ""
        }

        // Photo
        if let data = entry?.photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            photoPlaceholder.isHidden = true
        } else {
            photoImageView.isHidden = true
            photoPlaceholder.isHidden = false
        }

        // Diary text
        if let entry = entry, !entry.text.isEmpty {
            diaryTextLabel.text = entry.text
            diaryTextLabel.textColor = DS.fgStrong

            // Apply line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            let attrText = NSAttributedString(
                string: entry.text,
                attributes: [
                    .font: DS.font(15),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            diaryTextLabel.attributedText = attrText
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            let attrText = NSAttributedString(
                string: "오늘 우리 아기와의 하루는 어땠나요?",
                attributes: [
                    .font: DS.font(15),
                    .foregroundColor: DS.fgPale,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            diaryTextLabel.attributedText = attrText
        }

        // Audio count
        let audioNames = entry?.audioFileNamesArray ?? []
        if !audioNames.isEmpty {
            audioCountButton.isHidden = false
            let config = UIImage.SymbolConfiguration(pointSize: 12)
            let waveIcon = UIImage(systemName: "waveform", withConfiguration: config)?
                .withTintColor(DS.fgMuted, renderingMode: .alwaysOriginal)
            audioCountButton.setImage(waveIcon, for: .normal)
            audioCountButton.setTitle(" \(audioNames.count)", for: .normal)
        } else {
            audioCountButton.isHidden = true
        }

        // Elephant visibility
        let shouldHide = hideElephant
        elephantView.isHidden = shouldHide
        grassContainer.isHidden = shouldHide
        if shouldHide {
            stopElephantAnimation()
        } else if displayLink == nil {
            startElephantAnimation()
        }
    }

    // MARK: - Actions

    @objc private func cardTapped() {
        if let entry = selectedEntry {
            presentDetail(entry: entry)
        } else {
            presentEditor()
        }
    }

    @objc private func voiceButtonTapped() {
        // Voice recording toggle - notify parent or handle via delegate
        // For now, post a notification that can be handled by a SpeechManager coordinator
        NotificationCenter.default.post(
            name: NSNotification.Name("TodayVoiceRecordToggle"),
            object: nil,
            userInfo: ["date": selectedDate]
        )
    }

    private func presentDetail(entry: CDDiaryEntry) {
        // Present DiaryDetailViewController
        if let detailVC = createViewController(named: "DiaryDetailViewController") {
            detailVC.modalPresentationStyle = .fullScreen
            present(detailVC, animated: true)
        }
    }

    private func presentEditor() {
        // Present DiaryEditorViewController
        if let editorVC = createViewController(named: "DiaryEditorViewController") {
            editorVC.modalPresentationStyle = .fullScreen
            present(editorVC, animated: true)
        }
    }

    /// Attempts to instantiate a view controller by class name.
    /// Returns nil if the class does not exist yet (allows incremental migration).
    private func createViewController(named className: String) -> UIViewController? {
        let fullName = "BabyDiaryUIKit.\(className)"
        guard let vcClass = NSClassFromString(fullName) as? UIViewController.Type else {
            print("[TodayVC] \(className) not found yet")
            return nil
        }
        return vcClass.init()
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        return f.string(from: date)
    }

    deinit {
        stopElephantAnimation()
    }
}
