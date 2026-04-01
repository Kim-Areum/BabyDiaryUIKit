import UIKit

protocol PlaybackPopupDelegate: AnyObject {
    func playbackPopupDidDelete(at index: Int)
    func playbackPopupDidDismiss()
}

class PlaybackPopupView: UIView {

    weak var delegate: PlaybackPopupDelegate?
    private var fileNames: [String]
    private var timestamps: [Date]
    private let speechManager = SpeechManager()
    private var playingIndex: Int? = nil
    private var isPlayingAll = false
    private var rowViews: [(icon: UIImageView, row: UIStackView)] = []
    private var playAllButton: UIButton?

    init(fileNames: [String], timestamps: [Date]) {
        self.fileNames = fileNames
        self.timestamps = timestamps
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.01)

        let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        addGestureRecognizer(tapDismiss)

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.tag = 100
        addSubview(popup)

        // Header
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "녹음 파일"
        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong

        let countLabel = UILabel()
        countLabel.text = "\(fileNames.count)개"
        countLabel.font = DS.font(13)
        countLabel.textColor = DS.fgMuted

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = DS.fgStrong
        closeBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(countLabel)
        headerStack.addArrangedSubview(closeBtn)

        popup.addSubview(headerStack)

        let headerDivider = UIView()
        headerDivider.backgroundColor = DS.line
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(headerDivider)

        // List
        let listStack = UIStackView()
        listStack.axis = .vertical
        listStack.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(listStack)

        for (index, _) in fileNames.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center

            // Play/Pause icon
            let playIcon = UIImageView(image: UIImage(systemName: "play.circle.fill"))
            playIcon.tintColor = DS.blue
            playIcon.contentMode = .scaleAspectFit
            playIcon.translatesAutoresizingMaskIntoConstraints = false
            playIcon.isUserInteractionEnabled = true
            NSLayoutConstraint.activate([
                playIcon.widthAnchor.constraint(equalToConstant: 22),
                playIcon.heightAnchor.constraint(equalToConstant: 22),
            ])
            row.addArrangedSubview(playIcon)

            // Info
            let infoStack = UIStackView()
            infoStack.axis = .vertical
            infoStack.spacing = 2

            let nameLabel = UILabel()
            nameLabel.text = "녹음 \(index + 1)"
            nameLabel.font = DS.font(14)
            nameLabel.textColor = DS.fgStrong
            infoStack.addArrangedSubview(nameLabel)

            if index < timestamps.count {
                let timeLabel = UILabel()
                let tf = DateFormatter()
                tf.locale = Locale.current
                tf.dateFormat = "a h:mm"
                timeLabel.text = tf.string(from: timestamps[index])
                timeLabel.font = DS.font(11)
                timeLabel.textColor = DS.fgPale
                infoStack.addArrangedSubview(timeLabel)
            }
            row.addArrangedSubview(infoStack)

            let rowSpacer = UIView()
            rowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(rowSpacer)

            // Delete button
            let deleteBtn = UIButton(type: .system)
            let trashConfig = UIImage.SymbolConfiguration(pointSize: 13)
            deleteBtn.setImage(UIImage(systemName: "trash", withConfiguration: trashConfig), for: .normal)
            deleteBtn.tintColor = DS.fgPale
            deleteBtn.tag = index
            deleteBtn.addTarget(self, action: #selector(deleteItemTapped(_:)), for: .touchUpInside)
            deleteBtn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                deleteBtn.widthAnchor.constraint(equalToConstant: 28),
                deleteBtn.heightAnchor.constraint(equalToConstant: 28),
            ])
            row.addArrangedSubview(deleteBtn)

            // Tap to play
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
            row.isUserInteractionEnabled = true
            row.addGestureRecognizer(tapGesture)
            row.tag = index

            let rowContainer = UIView()
            rowContainer.translatesAutoresizingMaskIntoConstraints = false
            row.translatesAutoresizingMaskIntoConstraints = false
            rowContainer.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: rowContainer.topAnchor, constant: 12),
                row.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor, constant: -12),
                row.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
            ])

            listStack.addArrangedSubview(rowContainer)
            rowViews.append((icon: playIcon, row: row))

            if index < fileNames.count - 1 {
                let divider = UIView()
                divider.backgroundColor = DS.line
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                listStack.addArrangedSubview(divider)
            }
        }

        let bottomDivider = UIView()
        bottomDivider.backgroundColor = DS.line
        bottomDivider.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(bottomDivider)

        // Play all button
        let playAllBtn = UIButton(type: .system)
        let playConfig = UIImage.SymbolConfiguration(pointSize: 12)
        playAllBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: playConfig), for: .normal)
        playAllBtn.setTitle(" 전체 재생", for: .normal)
        playAllBtn.titleLabel?.font = DS.font(14)
        playAllBtn.tintColor = DS.fgStrong
        playAllBtn.setTitleColor(DS.fgStrong, for: .normal)
        playAllBtn.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)
        playAllBtn.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(playAllBtn)
        self.playAllButton = playAllBtn

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: centerYAnchor),
            popup.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85),

            headerStack.topAnchor.constraint(equalTo: popup.topAnchor, constant: 18),
            headerStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),

            headerDivider.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            headerDivider.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            headerDivider.heightAnchor.constraint(equalToConstant: 0.5),

            listStack.topAnchor.constraint(equalTo: headerDivider.bottomAnchor),
            listStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            listStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),

            bottomDivider.topAnchor.constraint(equalTo: listStack.bottomAnchor),
            bottomDivider.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: popup.trailingAnchor),
            bottomDivider.heightAnchor.constraint(equalToConstant: 0.5),

            playAllBtn.topAnchor.constraint(equalTo: bottomDivider.bottomAnchor, constant: 10),
            playAllBtn.centerXAnchor.constraint(equalTo: popup.centerXAnchor),
            playAllBtn.heightAnchor.constraint(equalToConstant: 40),
            playAllBtn.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Actions

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view else { return }
        let index = row.tag
        togglePlay(at: index)
    }

    private func togglePlay(at index: Int) {
        if playingIndex == index {
            // Stop
            speechManager.stopPlayback()
            playingIndex = nil
            isPlayingAll = false
            updateIcons()
        } else {
            // Play
            speechManager.stopPlayback()
            playingIndex = index
            isPlayingAll = false
            updateIcons()
            speechManager.playAll(fileNames: [fileNames[index]]) { [weak self] in
                self?.playingIndex = nil
                self?.updateIcons()
            }
        }
    }

    @objc private func playAllTapped() {
        if isPlayingAll {
            speechManager.stopPlayback()
            playingIndex = nil
            isPlayingAll = false
            updateIcons()
        } else {
            speechManager.stopPlayback()
            isPlayingAll = true
            playingIndex = 0
            updateIcons()
            speechManager.playAll(fileNames: fileNames) { [weak self] in
                self?.playingIndex = nil
                self?.isPlayingAll = false
                self?.updateIcons()
            }
        }
    }

    @objc private func deleteItemTapped(_ sender: UIButton) {
        let index = sender.tag
        speechManager.stopPlayback()
        playingIndex = nil
        isPlayingAll = false
        delegate?.playbackPopupDidDelete(at: index)
        dismiss()
    }

    @objc private func dismissTapped() {
        speechManager.stopPlayback()
        dismiss()
    }

    private func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.delegate?.playbackPopupDidDismiss()
        }
    }

    private func updateIcons() {
        for (i, item) in rowViews.enumerated() {
            if i == playingIndex {
                item.icon.image = UIImage(systemName: "pause.circle.fill")
                item.icon.tintColor = UIColor(hex: "D05050")
            } else {
                item.icon.image = UIImage(systemName: "play.circle.fill")
                item.icon.tintColor = DS.blue
            }
        }

        if isPlayingAll {
            let stopConfig = UIImage.SymbolConfiguration(pointSize: 12)
            playAllButton?.setImage(UIImage(systemName: "stop.fill", withConfiguration: stopConfig), for: .normal)
            playAllButton?.setTitle(" 전체 중지", for: .normal)
        } else {
            let playConfig = UIImage.SymbolConfiguration(pointSize: 12)
            playAllButton?.setImage(UIImage(systemName: "play.fill", withConfiguration: playConfig), for: .normal)
            playAllButton?.setTitle(" 전체 재생", for: .normal)
        }
    }

    func show(in parentView: UIView) {
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        parentView.addSubview(self)
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }
}
