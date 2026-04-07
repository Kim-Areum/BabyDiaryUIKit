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
    private let elephantSize: CGFloat = 38
    private let cycleDuration: TimeInterval = 20
    private var elephantStartTime: CFTimeInterval = 0
    private var elephantFrameNames: [String] {
        switch DS.currentTheme {
        case .pink: return ["PinkElephant2", "PinkElephant3"]
        case .yellow: return ["YellowElephant2", "YellowElephant3"]
        case .blue: return ["Elephant2", "Elephant3"]
        }
    }
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
    private let moreButton = UIButton(type: .system)

    // Video play icon overlay
    private let videoPlayIcon = UIImageView()
    private var playerView: PlayerView?
    private let videoMuteButton = UIButton(type: .system)

    // Voice record button
    private let voiceButton = UIButton(type: .custom)
    private var isRecording = false
    private let speechManager = SpeechManager()

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

        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .themeColorChanged, object: nil)
    }

    @objc private func themeChanged() {
        updateVoiceButtonAppearance()
        elephantView.image = UIImage(named: elephantFrameNames[0])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        startElephantAnimation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopElephantAnimation()
        playerView?.cleanup()
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
        topSpacer.heightAnchor.constraint(equalToConstant: 55).isActive = true

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

        // Card tap gesture (below subviews so audioCountButton gets priority)
        cardView.isUserInteractionEnabled = true
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        cardView.addGestureRecognizer(cardTap)

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
        elephantView.image = UIImage(named: elephantFrameNames[0])
        elephantView.translatesAutoresizingMaskIntoConstraints = false
        elephantContainer.addSubview(elephantView)

        NSLayoutConstraint.activate([
            elephantView.widthAnchor.constraint(equalToConstant: elephantSize),
            elephantView.heightAnchor.constraint(equalToConstant: elephantSize),
            elephantView.bottomAnchor.constraint(equalTo: elephantContainer.bottomAnchor, constant: -2),
        ])

        elephantView.isHidden = hideElephant

        // 코끼리가 잔디 앞에 보이도록
        elephantContainer.layer.zPosition = 10
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

        for i in 0..<7 {
            let wrapper = UIView()
            wrapper.clipsToBounds = true
            wrapper.translatesAutoresizingMaskIntoConstraints = false

            let grassImageView = UIImageView(image: UIImage(named: "Grass"))
            grassImageView.contentMode = .scaleAspectFit
            grassImageView.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(grassImageView)

            NSLayoutConstraint.activate([
                grassImageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
                grassImageView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                grassImageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                grassImageView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            ])

            // 개별 잔디 경계 블렌딩 마스크 (첫번째/마지막 가장자리 제외)
            let isFirst = i == 0
            let isLast = i == 6
            let itemMask = CAGradientLayer()
            itemMask.startPoint = CGPoint(x: 0, y: 0.5)
            itemMask.endPoint = CGPoint(x: 1, y: 0.5)

            if isFirst {
                itemMask.colors = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
                itemMask.locations = [0.0, 0.85, 1.0]
            } else if isLast {
                itemMask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor]
                itemMask.locations = [0.0, 0.15, 1.0]
            } else {
                itemMask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
                itemMask.locations = [0.0, 0.15, 0.85, 1.0]
            }
            wrapper.layer.mask = itemMask

            grassStack.addArrangedSubview(wrapper)
        }

        // 양끝 살짝 페이드
        let edgeMask = CAGradientLayer()
        edgeMask.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor,
        ]
        edgeMask.locations = [0.0, 0.01, 0.99, 1.0]
        edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
        grassContainer.layer.mask = edgeMask
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update grass mask frames
        grassContainer.layer.mask?.frame = grassContainer.bounds
        for subview in grassContainer.subviews {
            if let stack = subview as? UIStackView {
                for wrapper in stack.arrangedSubviews {
                    wrapper.layer.mask?.frame = wrapper.bounds
                }
            }
        }
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
            bodyView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor, constant: 16),
            bodyView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor, constant: -16),
            bodyView.bottomAnchor.constraint(equalTo: innerClip.bottomAnchor, constant: -16),
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
            topRow.topAnchor.constraint(equalTo: bodyView.topAnchor, constant: 16),
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
        textScroll.showsVerticalScrollIndicator = true
        textScroll.isUserInteractionEnabled = true
        bodyView.addSubview(textScroll)
        textScroll.addSubview(diaryTextLabel)

        NSLayoutConstraint.activate([
            textScroll.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            textScroll.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            textScroll.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),

            diaryTextLabel.topAnchor.constraint(equalTo: textScroll.topAnchor),
            diaryTextLabel.leadingAnchor.constraint(equalTo: textScroll.leadingAnchor),
            diaryTextLabel.trailingAnchor.constraint(equalTo: textScroll.trailingAnchor),
            diaryTextLabel.bottomAnchor.constraint(equalTo: textScroll.bottomAnchor),
            diaryTextLabel.widthAnchor.constraint(equalTo: textScroll.widthAnchor),
        ])

        // Audio count button
        audioCountButton.translatesAutoresizingMaskIntoConstraints = false
        var audioBtnConfig = UIButton.Configuration.plain()
        audioBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
        audioBtnConfig.baseForegroundColor = DS.fgMuted
        audioCountButton.configuration = audioBtnConfig
        audioCountButton.tintColor = DS.fgMuted
        audioCountButton.backgroundColor = DS.bgSubtle
        audioCountButton.layer.cornerRadius = 12
        audioCountButton.isHidden = true
        audioCountButton.addTarget(self, action: #selector(audioCountTapped), for: .touchUpInside)
        bodyView.addSubview(audioCountButton)

        NSLayoutConstraint.activate([
            audioCountButton.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
            audioCountButton.bottomAnchor.constraint(equalTo: bodyView.bottomAnchor),
            textScroll.bottomAnchor.constraint(equalTo: audioCountButton.topAnchor, constant: -8),
        ])

        // Video play icon overlay
        let playConfig = UIImage.SymbolConfiguration(pointSize: 40)
        videoPlayIcon.image = UIImage(systemName: "play.circle.fill", withConfiguration: playConfig)
        videoPlayIcon.tintColor = .white
        videoPlayIcon.alpha = 0.7
        videoPlayIcon.isHidden = true
        videoPlayIcon.translatesAutoresizingMaskIntoConstraints = false
        innerClip.addSubview(videoPlayIcon)

        NSLayoutConstraint.activate([
            videoPlayIcon.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
            videoPlayIcon.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
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
        let bgColor = isRecording ? UIColor(hex: "E8A0A0") : DS.accent
        let iconColor = isRecording ? UIColor.white : DS.fgStrong

        let config = UIImage.SymbolConfiguration(pointSize: 16)
        let icon = UIImage(systemName: iconName, withConfiguration: config)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)

        let attString = NSMutableAttributedString()
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = icon
        attString.append(NSAttributedString(attachment: iconAttachment))
        attString.append(NSAttributedString(
            string: "  \(title)",
            attributes: [
                .font: DS.font(15),
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
            dayCountLabel.text = b.dayAndMonthAt(date: selectedDate)
        } else {
            dayCountLabel.text = ""
        }

        // Photo / Video thumbnail
        if let data = entry?.photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            photoPlaceholder.isHidden = true
        } else if let data = entry?.videoThumbnailData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            photoPlaceholder.isHidden = true
        } else {
            photoImageView.isHidden = true
            photoPlaceholder.isHidden = false
        }

        // Video autoplay
        if let videoData = entry?.videoData {
            if playerView == nil, let container = photoImageView.superview {
                let pv = PlayerView()
                pv.translatesAutoresizingMaskIntoConstraints = false
                container.insertSubview(pv, aboveSubview: photoImageView)
                NSLayoutConstraint.activate([
                    pv.topAnchor.constraint(equalTo: photoImageView.topAnchor),
                    pv.leadingAnchor.constraint(equalTo: photoImageView.leadingAnchor),
                    pv.trailingAnchor.constraint(equalTo: photoImageView.trailingAnchor),
                    pv.bottomAnchor.constraint(equalTo: photoImageView.bottomAnchor),
                ])
                playerView = pv

                // 음소거 버튼 (20% 축소, 우하단)
                let muteIcon = UIImage(systemName: "speaker.slash.fill")?.withConfiguration(
                    UIImage.SymbolConfiguration(pointSize: 12)
                )
                videoMuteButton.setImage(muteIcon, for: .normal)
                videoMuteButton.tintColor = DS.fgMuted
                videoMuteButton.backgroundColor = DS.bgBase.withAlphaComponent(0.8)
                videoMuteButton.layer.cornerRadius = 14
                videoMuteButton.layer.borderWidth = 0.5
                videoMuteButton.layer.borderColor = DS.line.cgColor
                videoMuteButton.translatesAutoresizingMaskIntoConstraints = false
                videoMuteButton.addTarget(self, action: #selector(toggleTodayVideoMute), for: .touchUpInside)
                container.addSubview(videoMuteButton)
                NSLayoutConstraint.activate([
                    videoMuteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
                    videoMuteButton.bottomAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: -8),
                    videoMuteButton.widthAnchor.constraint(equalToConstant: 28),
                    videoMuteButton.heightAnchor.constraint(equalToConstant: 28),
                ])
            }
            playerView?.isHidden = false
            playerView?.isMuted = true
            playerView?.play(data: videoData)
            videoPlayIcon.isHidden = true
            videoMuteButton.isHidden = false
            videoMuteButton.setImage(UIImage(systemName: "speaker.slash.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12)), for: .normal)
        } else {
            playerView?.cleanup()
            playerView?.isHidden = true
            videoPlayIcon.isHidden = true
            videoMuteButton.isHidden = true
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
                    .font: DS.font(13),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            diaryTextLabel.attributedText = attrText
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            let attrText = NSAttributedString(
                string: "\(babyObj?.name ?? "아기")에게 오늘 하루가 어땠는지 들려주세요",
                attributes: [
                    .font: DS.font(13),
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
            var countTitle = AttributedString(" \(audioNames.count)")
            countTitle.font = DS.font(11)
            audioCountButton.configuration?.attributedTitle = countTitle
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
        presentEditor()
    }

    @objc private func toggleTodayVideoMute() {
        guard let pv = playerView else { return }
        pv.isMuted.toggle()
        let iconName = pv.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let icon = UIImage(systemName: iconName)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12)
        )
        videoMuteButton.setImage(icon, for: .normal)
    }

    @objc private func moreTapped() {
        guard selectedEntry != nil else { return }

        let overlay = UIView()
        overlay.frame = view.window?.bounds ?? view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.tag = 9100

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissMoreMenu))
        overlay.addGestureRecognizer(dismissTap)

        let menu = UIView()
        menu.backgroundColor = DS.bgBase
        menu.layer.cornerRadius = 16
        menu.layer.shadowColor = UIColor.black.cgColor
        menu.layer.shadowOpacity = 0.15
        menu.layer.shadowRadius = 12
        menu.layer.shadowOffset = CGSize(width: 0, height: 4)
        menu.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(menu)

        let editBtn = UIButton(type: .system)
        editBtn.setTitle("  수정", for: .normal)
        editBtn.setImage(UIImage(systemName: "pencil"), for: .normal)
        editBtn.titleLabel?.font = DS.font(13)
        editBtn.tintColor = DS.fgStrong
        editBtn.setTitleColor(DS.fgStrong, for: .normal)
        editBtn.contentHorizontalAlignment = .left
        editBtn.addTarget(self, action: #selector(editFromMenu), for: .touchUpInside)
        editBtn.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = DS.line
        divider.translatesAutoresizingMaskIntoConstraints = false

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setTitle("  삭제", for: .normal)
        deleteBtn.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteBtn.titleLabel?.font = DS.font(13)
        deleteBtn.tintColor = UIColor(hex: "D05050")
        deleteBtn.setTitleColor(UIColor(hex: "D05050"), for: .normal)
        deleteBtn.contentHorizontalAlignment = .left
        deleteBtn.addTarget(self, action: #selector(deleteFromMenu), for: .touchUpInside)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false

        menu.addSubview(editBtn)
        menu.addSubview(divider)
        menu.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            menu.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            menu.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            menu.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.75),

            editBtn.topAnchor.constraint(equalTo: menu.topAnchor),
            editBtn.leadingAnchor.constraint(equalTo: menu.leadingAnchor, constant: 20),
            editBtn.trailingAnchor.constraint(equalTo: menu.trailingAnchor, constant: -20),
            editBtn.heightAnchor.constraint(equalToConstant: 48),

            divider.topAnchor.constraint(equalTo: editBtn.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: menu.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: menu.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            deleteBtn.topAnchor.constraint(equalTo: divider.bottomAnchor),
            deleteBtn.leadingAnchor.constraint(equalTo: menu.leadingAnchor, constant: 20),
            deleteBtn.trailingAnchor.constraint(equalTo: menu.trailingAnchor, constant: -20),
            deleteBtn.heightAnchor.constraint(equalToConstant: 48),
            deleteBtn.bottomAnchor.constraint(equalTo: menu.bottomAnchor),
        ])

        view.window?.addSubview(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
    }

    @objc private func dismissMoreMenu() {
        if let overlay = view.window?.viewWithTag(9100) {
            UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }

    @objc private func editFromMenu() {
        dismissMoreMenu()
        presentEditor()
    }

    @objc private func deleteFromMenu() {
        dismissMoreMenu()
        guard selectedEntry != nil else { return }

        // 삭제 확인 팝업
        let overlay = UIView()
        overlay.frame = view.window?.bounds ?? view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.tag = 9200

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
        cancelBtn.tag = 9200
        cancelBtn.addTarget(self, action: #selector(dismissDeletePopup), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle("삭제", for: .normal)
        confirmBtn.titleLabel?.font = DS.font(13)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.backgroundColor = UIColor(hex: "E8A0A0")
        confirmBtn.layer.cornerRadius = 10
        confirmBtn.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
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

        view.window?.addSubview(overlay)
    }

    @objc private func dismissDeletePopup() {
        if let overlay = view.window?.viewWithTag(9200) {
            overlay.removeFromSuperview()
        }
    }

    @objc private func confirmDelete() {
        dismissDeletePopup()
        guard let entry = selectedEntry else { return }
        for fileName in entry.audioFileNamesArray {
            let url = SpeechManager.recordingsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        CoreDataStack.shared.deleteEntry(entry)
        reloadData()
    }

    @objc private func audioCountTapped() {
        guard let entry = selectedEntry, !entry.audioFileNamesArray.isEmpty else { return }
        showPlaybackPopup(fileNames: entry.audioFileNamesArray, timestamps: entry.audioTimestampsArray)
    }

    private func showPlaybackPopup(fileNames: [String], timestamps: [Date]) {
        guard let window = view.window else { return }
        let popup = PlaybackPopupView(fileNames: fileNames, timestamps: timestamps)
        popup.delegate = self
        popup.show(in: window)
    }

    @objc private func voiceButtonTapped() {
        if isRecording {
            speechManager.stopRecording { [weak self] text, fileName in
                guard let self = self else { return }
                if let text = text, !text.isEmpty {
                    self.appendVoiceResult(text)
                } else {
                    let alert = CustomAlertView(title: "음성이 인식되지 않았어요", message: "조금 더 가까이에서 말해보세요.", buttonText: "확인")
                    alert.show(in: self.view)
                }
                if let fileName = fileName {
                    self.saveAudioFile(fileName: fileName)
                }
                self.isRecording = false
                self.updateVoiceButtonAppearance()
                self.reloadData()
            }
        } else {
            speechManager.startRecording()
            isRecording = true
            updateVoiceButtonAppearance()
        }
    }

    private func appendVoiceResult(_ voiceText: String) {
        guard !voiceText.isEmpty else { return }
        let newEntry = voiceText

        let stack = CoreDataStack.shared
        if let entry = stack.fetchEntry(for: selectedDate) {
            entry.text = entry.text.isEmpty ? newEntry : entry.text + "\n\(newEntry)"
            stack.save()
        } else {
            let _ = stack.createEntry(date: selectedDate, text: newEntry, photoData: nil, audioFileNames: [], audioTimestamps: [])
        }
    }

    private func saveAudioFile(fileName: String) {
        let stack = CoreDataStack.shared
        if let entry = stack.fetchEntry(for: selectedDate) {
            var names = entry.audioFileNamesArray
            var stamps = entry.audioTimestampsArray
            names.append(fileName)
            stamps.append(Date())
            entry.audioFileNamesArray = names
            entry.audioTimestampsArray = stamps
            stack.save()
        } else {
            let _ = stack.createEntry(date: selectedDate, text: "", photoData: nil, audioFileNames: [fileName], audioTimestamps: [Date()])
        }
    }

    private func presentDetail(entry: CDDiaryEntry) {
        guard let baby = CoreDataStack.shared.fetchBaby() else { return }
        let detailVC = DiaryDetailViewController(entry: entry, baby: baby)
        detailVC.modalPresentationStyle = .fullScreen
        detailVC.onDismiss = { [weak self] in
            self?.reloadData()
        }
        present(detailVC, animated: true)
    }

    private func presentEditor() {
        guard let baby = CoreDataStack.shared.fetchBaby() else { return }
        let editorVC = DiaryEditorViewController(date: selectedDate, baby: baby)
        editorVC.modalPresentationStyle = .fullScreen
        editorVC.onDismiss = { [weak self] in
            self?.reloadData()
        }
        present(editorVC, animated: true)
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

// MARK: - PlaybackPopupDelegate

extension TodayViewController: PlaybackPopupDelegate {
    func playbackPopupDidDelete(at index: Int) {
        guard let entry = selectedEntry else { return }
        var names = entry.audioFileNamesArray
        var stamps = entry.audioTimestampsArray

        if index < names.count {
            let fileName = names[index]
            let url = SpeechManager.recordingsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            names.remove(at: index)
        }
        if index < stamps.count {
            stamps.remove(at: index)
        }
        entry.audioFileNamesArray = names
        entry.audioTimestampsArray = stamps
        CoreDataStack.shared.save()
        reloadData()
    }

    func playbackPopupDidDismiss() {
        // no-op
    }
}
