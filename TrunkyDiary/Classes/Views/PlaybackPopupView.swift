import UIKit
import AVFoundation

protocol PlaybackPopupDelegate: AnyObject {
    func playbackPopupDidDelete(at index: Int)
    func playbackPopupDidRename(at index: Int, newName: String)
    func playbackPopupDidDismiss()
}

extension PlaybackPopupDelegate {
    func playbackPopupDidRename(at index: Int, newName: String) {}
}

class PlaybackPopupView: UIView {

    weak var delegate: PlaybackPopupDelegate?
    private var fileNames: [String]
    private var displayNames: [String]
    private var timestamps: [Date]
    private let speechManager = SpeechManager()
    private var playingIndex: Int? = nil
    private var isPaused = false
    private var isPlayingAll = false
    private var pausedTime: TimeInterval = 0
    private var rowViews: [(icon: UIImageView, nameLabel: UILabel, timeLabel: UILabel)] = []
    private var playAllButton: UIButton?
    private var playTimer: Timer?

    init(fileNames: [String], timestamps: [Date], displayNames: [String]? = nil) {
        self.fileNames = fileNames
        self.timestamps = timestamps
        self.displayNames = displayNames ?? fileNames.enumerated().map { "녹음 \($0.offset + 1)" }
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        playTimer?.invalidate()
    }

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
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong

        let countLabel = UILabel()
        countLabel.text = "\(fileNames.count)개"
        countLabel.font = DS.font(11)
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
            playIcon.tintColor = DS.accent
            playIcon.contentMode = .scaleAspectFit
            playIcon.translatesAutoresizingMaskIntoConstraints = false
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
            nameLabel.text = displayNames[index]
            nameLabel.font = DS.font(13)
            nameLabel.textColor = DS.fgStrong
            nameLabel.tag = 2000 + index
            infoStack.addArrangedSubview(nameLabel)

            let timeLabel = UILabel()
            if index < timestamps.count {
                let tf = DateFormatter()
                tf.locale = Locale.current
                tf.dateFormat = "a h:mm"
                timeLabel.text = tf.string(from: timestamps[index])
            }
            timeLabel.font = DS.font(11)
            timeLabel.textColor = DS.fgPale
            infoStack.addArrangedSubview(timeLabel)

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
            rowViews.append((icon: playIcon, nameLabel: nameLabel, timeLabel: timeLabel))

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
        playAllBtn.titleLabel?.font = DS.font(13)
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
            if isPaused {
                // Resume from paused position
                isPaused = false
                updateIcons()
                startTimer()
                speechManager.playSingle(fileName: fileNames[index], from: pausedTime) { [weak self] in
                    guard let self = self, self.playingIndex == index else { return }
                    self.playingIndex = nil
                    self.isPaused = false
                    self.pausedTime = 0
                    self.stopTimer()
                    self.updateIcons()
                }
            } else {
                // Pause
                pausedTime = speechManager.currentTime
                speechManager.stopPlayback()
                isPaused = true
                stopTimerOnly()
                updateIcons()
            }
        } else {
            // 다른 파일 재생
            speechManager.stopPlayback()
            playingIndex = index
            isPaused = false
            isPlayingAll = false
            pausedTime = 0
            updateIcons()
            startTimer()
            speechManager.playSingle(fileName: fileNames[index]) { [weak self] in
                guard let self = self, self.playingIndex == index else { return }
                self.playingIndex = nil
                self.isPaused = false
                self.stopTimer()
                self.updateIcons()
            }
        }
    }

    @objc private func playAllTapped() {
        if isPlayingAll {
            speechManager.stopPlayback()
            playingIndex = nil
            isPlayingAll = false
            stopTimer()
            updateIcons()
        } else {
            speechManager.stopPlayback()
            isPlayingAll = true
            playingIndex = 0
            updateIcons()
            startTimer()
            speechManager.playAll(fileNames: fileNames) { [weak self] in
                self?.playingIndex = nil
                self?.isPlayingAll = false
                self?.stopTimer()
                self?.updateIcons()
            }
        }
    }

    @objc private func deleteItemTapped(_ sender: UIButton) {
        let index = sender.tag
        speechManager.stopPlayback()
        playingIndex = nil
        isPlayingAll = false
        stopTimer()
        showDeleteConfirm(index: index)
    }

    private func showDeleteConfirm(index: Int) {
        guard let window = window else { return }

        let dim = UIView()
        dim.frame = window.bounds
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dim.tag = 9900
        window.addSubview(dim)

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 20
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.15
        popup.layer.shadowRadius = 12
        popup.layer.shadowOffset = CGSize(width: 0, height: 4)
        popup.translatesAutoresizingMaskIntoConstraints = false
        dim.addSubview(popup)

        let titleLabel = UILabel()
        titleLabel.text = "녹음 \(index + 1)을 삭제할까요?"
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(titleLabel)

        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 10
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(btnStack)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("취소", for: .normal)
        cancelBtn.titleLabel?.font = DS.font(13)
        cancelBtn.setTitleColor(DS.fgMuted, for: .normal)
        cancelBtn.backgroundColor = DS.bgSubtle
        cancelBtn.layer.cornerRadius = 12
        cancelBtn.addAction(UIAction { _ in
            dim.removeFromSuperview()
        }, for: .touchUpInside)
        btnStack.addArrangedSubview(cancelBtn)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setTitle("삭제", for: .normal)
        deleteBtn.titleLabel?.font = DS.font(13)
        deleteBtn.setTitleColor(.white, for: .normal)
        deleteBtn.backgroundColor = UIColor(hex: "D05050")
        deleteBtn.layer.cornerRadius = 12
        deleteBtn.addAction(UIAction { [weak self] _ in
            dim.removeFromSuperview()
            self?.delegate?.playbackPopupDidDelete(at: index)
            self?.dismiss()
        }, for: .touchUpInside)
        btnStack.addArrangedSubview(deleteBtn)

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: 260),

            titleLabel.topAnchor.constraint(equalTo: popup.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),

            btnStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            btnStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            btnStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),
            btnStack.heightAnchor.constraint(equalToConstant: 44),
            btnStack.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -20),
        ])
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    @objc private func dismissTapped() {
        speechManager.stopPlayback()
        stopTimer()
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

    // MARK: - Timer (남은 시간 카운트다운)

    private func startTimer() {
        playTimer?.invalidate()
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }

    private func stopTimerOnly() {
        playTimer?.invalidate()
        playTimer = nil
    }

    private func stopTimer() {
        stopTimerOnly()
        // 시간 표시 복원
        for (index, item) in rowViews.enumerated() {
            if index < timestamps.count {
                let tf = DateFormatter()
                tf.locale = Locale.current
                tf.dateFormat = "a h:mm"
                item.timeLabel.text = tf.string(from: timestamps[index])
                item.timeLabel.textColor = DS.fgPale
            }
        }
    }

    private func updatePlaybackTime() {
        guard let index = playingIndex, index < rowViews.count else { return }
        let remaining = speechManager.duration - speechManager.currentTime
        let minutes = Int(max(0, remaining)) / 60
        let seconds = Int(max(0, remaining)) % 60
        let timeStr = String(format: "%d:%02d", minutes, seconds)

        rowViews[index].timeLabel.text = timeStr
        rowViews[index].timeLabel.textColor = UIColor(hex: "D05050")
    }

    // MARK: - UI Update

    private func updateIcons() {
        for (i, item) in rowViews.enumerated() {
            if i == playingIndex && !isPaused {
                item.icon.image = UIImage(systemName: "pause.circle.fill")
                item.icon.tintColor = UIColor(hex: "D05050")
            } else {
                item.icon.image = UIImage(systemName: "play.circle.fill")
                item.icon.tintColor = i == playingIndex && isPaused ? UIColor(hex: "D05050") : DS.accent
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
