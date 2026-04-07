import UIKit
import AVFoundation
import Photos

final class VideoTrimViewController: UIViewController {

    private let phAsset: PHAsset
    var onConfirm: ((PHAsset, CMTimeRange) -> Void)?

    private var asset: AVURLAsset?
    private var player: AVPlayer?
    private var timeObserver: Any?

    private var duration: TimeInterval = 0
    private var trimStart: TimeInterval = 0
    private var trimEnd: TimeInterval = 0
    private let minDuration: TimeInterval = 5
    private let maxDuration: TimeInterval = VideoCompressor.maxDuration

    private var isPlaying = false

    // UI
    private let playerView = PlayerView()
    private let durationLabel = UILabel()
    private let thumbnailStrip = UIView()
    private let selectionBox = UIView()
    private let leftHandle = UIView()
    private let rightHandle = UIView()
    private let leftDimView = UIView()
    private let rightDimView = UIView()
    private let playheadView = UIView()
    private let playButton = UIButton(type: .system)

    private let stripHeight: CGFloat = 56
    private let handleWidth: CGFloat = 14
    private var thumbnailsGenerated = false

    init(asset: PHAsset) {
        self.phAsset = asset
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupNav()
        setupPlayerView()
        setupDurationLabel()
        setupTrimUI()
        setupPlayButton()
        loadAsset()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        generateThumbnails()
        updateTrimUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
    }

    // MARK: - Nav

    private func setupNav() {
        let navContainer = UIView()
        navContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navContainer)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "구간 선택"
        titleLabel.font = DS.font(16)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = UIButton(type: .system)
        var doneConfig = UIButton.Configuration.plain()
        var doneTitle = AttributedString("다음")
        doneTitle.font = DS.font(15)
        doneConfig.attributedTitle = doneTitle
        doneConfig.baseForegroundColor = DS.fgStrong
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        doneButton.configuration = doneConfig
        doneButton.backgroundColor = DS.accent
        doneButton.layer.cornerRadius = 15
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        navContainer.addSubview(closeButton)
        navContainer.addSubview(titleLabel)
        navContainer.addSubview(doneButton)

        NSLayoutConstraint.activate([
            navContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navContainer.heightAnchor.constraint(equalToConstant: 48),
            closeButton.leadingAnchor.constraint(equalTo: navContainer.leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: navContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: navContainer.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),
        ])
    }

    // MARK: - Player

    private func setupPlayerView() {
        playerView.playerLayer.videoGravity = .resizeAspect
        playerView.backgroundColor = .black
        playerView.layer.cornerRadius = 8
        playerView.clipsToBounds = true
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9.0 / 16.0),
        ])
    }

    private func setupDurationLabel() {
        durationLabel.font = DS.font(13)
        durationLabel.textColor = DS.accent
        durationLabel.textAlignment = .center
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            durationLabel.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: 16),
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Trim UI (프레임 기반)

    private func setupTrimUI() {
        thumbnailStrip.clipsToBounds = true
        thumbnailStrip.layer.cornerRadius = 6
        thumbnailStrip.backgroundColor = UIColor.darkGray
        thumbnailStrip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailStrip)

        NSLayoutConstraint.activate([
            thumbnailStrip.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 24),
            thumbnailStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 76),
            thumbnailStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            thumbnailStrip.heightAnchor.constraint(equalToConstant: stripHeight),
        ])

        leftDimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        rightDimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        thumbnailStrip.addSubview(leftDimView)
        thumbnailStrip.addSubview(rightDimView)

        selectionBox.layer.borderWidth = 2
        selectionBox.layer.borderColor = DS.accent.cgColor
        selectionBox.layer.cornerRadius = 4
        selectionBox.isUserInteractionEnabled = false
        view.addSubview(selectionBox)

        for (handle, isLeft) in [(leftHandle, true), (rightHandle, false)] {
            handle.backgroundColor = DS.accent
            handle.layer.cornerRadius = 3
            view.addSubview(handle)

            let pan = UIPanGestureRecognizer(target: self, action: isLeft ? #selector(leftPan(_:)) : #selector(rightPan(_:)))
            handle.addGestureRecognizer(pan)

            let grip = UIView()
            grip.backgroundColor = .white
            grip.layer.cornerRadius = 1
            handle.addSubview(grip)
            grip.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                grip.centerXAnchor.constraint(equalTo: handle.centerXAnchor),
                grip.centerYAnchor.constraint(equalTo: handle.centerYAnchor),
                grip.widthAnchor.constraint(equalToConstant: 2),
                grip.heightAnchor.constraint(equalToConstant: 16),
            ])
        }

        playheadView.backgroundColor = .clear
        playheadView.isUserInteractionEnabled = true
        view.addSubview(playheadView)

        // 실제 흰색 바 (중앙, 가는 선)
        let playheadLine = UIView()
        playheadLine.backgroundColor = .white
        playheadLine.layer.cornerRadius = 1
        playheadLine.layer.shadowColor = UIColor.black.cgColor
        playheadLine.layer.shadowOpacity = 0.3
        playheadLine.layer.shadowRadius = 1
        playheadLine.translatesAutoresizingMaskIntoConstraints = false
        playheadView.addSubview(playheadLine)
        NSLayoutConstraint.activate([
            playheadLine.centerXAnchor.constraint(equalTo: playheadView.centerXAnchor),
            playheadLine.topAnchor.constraint(equalTo: playheadView.topAnchor),
            playheadLine.bottomAnchor.constraint(equalTo: playheadView.bottomAnchor),
            playheadLine.widthAnchor.constraint(equalToConstant: 2),
        ])

        let playheadPan = UIPanGestureRecognizer(target: self, action: #selector(playheadDragged(_:)))
        playheadView.addGestureRecognizer(playheadPan)

        let stripTap = UITapGestureRecognizer(target: self, action: #selector(stripTapped(_:)))
        thumbnailStrip.addGestureRecognizer(stripTap)
    }

    // MARK: - Play Button

    private func setupPlayButton() {
        playButton.tintColor = .white
        updatePlayButtonIcon()
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playButton)

        NSLayoutConstraint.activate([
            playButton.centerYAnchor.constraint(equalTo: thumbnailStrip.centerYAnchor),
            playButton.trailingAnchor.constraint(equalTo: thumbnailStrip.leadingAnchor, constant: -14),
            playButton.widthAnchor.constraint(equalToConstant: 32),
            playButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func updatePlayButtonIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconName = isPlaying ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    @objc private func playTapped() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
            player?.play()
            isPlaying = true
        }
        updatePlayButtonIcon()
    }

    // MARK: - Load Asset

    private func loadAsset() {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { [weak self] avAsset, _, _ in
            guard let self = self, let urlAsset = avAsset as? AVURLAsset else { return }
            DispatchQueue.main.async {
                self.asset = urlAsset
                self.duration = CMTimeGetSeconds(urlAsset.duration)
                self.trimStart = 0
                self.trimEnd = min(self.duration, self.maxDuration)

                let avPlayer = AVPlayer(url: urlAsset.url)
                avPlayer.isMuted = true
                self.playerView.playerLayer.player = avPlayer
                self.player = avPlayer

                self.timeObserver = avPlayer.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
                    queue: .main
                ) { [weak self] time in
                    guard let self = self, self.isPlaying else { return }
                    let current = CMTimeGetSeconds(time)
                    if current >= self.trimEnd {
                        self.player?.pause()
                        self.isPlaying = false
                        self.updatePlayButtonIcon()
                        self.player?.seek(to: CMTime(seconds: self.trimStart, preferredTimescale: 600))
                    }
                    self.updatePlayhead(currentTime: current)
                }

                self.updateTrimUI()
                self.updateDurationLabel()
            }
        }
    }

    // MARK: - Trim UI Updates (프레임 기반)

    private var stripOriginX: CGFloat { thumbnailStrip.frame.minX }
    private var stripW: CGFloat { thumbnailStrip.bounds.width }

    private func xForTime(_ t: TimeInterval) -> CGFloat {
        guard duration > 0, stripW > 0 else { return stripOriginX }
        return stripOriginX + CGFloat(t / duration) * stripW
    }

    private func updateTrimUI() {
        guard stripW > 0 else { return }

        let startX = xForTime(trimStart)
        let endX = xForTime(trimEnd)
        let localStartX = startX - stripOriginX
        let localEndX = endX - stripOriginX

        leftDimView.frame = CGRect(x: 0, y: 0, width: localStartX, height: stripHeight)
        rightDimView.frame = CGRect(x: localEndX, y: 0, width: stripW - localEndX, height: stripHeight)

        selectionBox.frame = CGRect(
            x: startX - handleWidth,
            y: thumbnailStrip.frame.minY - 2,
            width: endX - startX + handleWidth * 2,
            height: stripHeight + 4
        )

        leftHandle.frame = CGRect(
            x: startX - handleWidth,
            y: thumbnailStrip.frame.minY - 4,
            width: handleWidth,
            height: stripHeight + 8
        )
        rightHandle.frame = CGRect(
            x: endX,
            y: thumbnailStrip.frame.minY - 4,
            width: handleWidth,
            height: stripHeight + 8
        )

        // 플레이헤드는 현재 재생 위치 (재생 중이 아니면 trimStart)
        let currentTime = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        let playheadTime = (currentTime >= trimStart && currentTime <= trimEnd) ? currentTime : trimStart
        playheadView.frame = CGRect(
            x: xForTime(playheadTime) - 22,
            y: thumbnailStrip.frame.minY - 8,
            width: 44,
            height: stripHeight + 16
        )

        updateDurationLabel()
    }

    private func updatePlayhead(currentTime: TimeInterval) {
        playheadView.frame.origin.x = xForTime(currentTime) - 22
    }

    private func updateDurationLabel() {
        let dur = trimEnd - trimStart
        let mins = Int(dur) / 60
        let secs = Int(dur) % 60
        durationLabel.text = String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Playhead Drag & Strip Tap

    @objc private func playheadDragged(_ g: UIPanGestureRecognizer) {
        if isPlaying { player?.pause(); isPlaying = false; updatePlayButtonIcon() }

        let delta = Double(g.translation(in: view).x / stripW) * duration
        let current = CMTimeGetSeconds(player?.currentTime() ?? .zero)
        var newTime = current + delta
        newTime = max(trimStart, min(newTime, trimEnd))

        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        updatePlayhead(currentTime: newTime)
        g.setTranslation(.zero, in: view)
    }

    @objc private func stripTapped(_ g: UITapGestureRecognizer) {
        if isPlaying { player?.pause(); isPlaying = false; updatePlayButtonIcon() }

        let x = g.location(in: thumbnailStrip).x
        let time = max(trimStart, min(Double(x / stripW) * duration, trimEnd))
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        updatePlayhead(currentTime: time)
    }

    // MARK: - Handle Pan (델타 방식, setTranslation 리셋)

    @objc private func leftPan(_ g: UIPanGestureRecognizer) {
        let delta = Double(g.translation(in: view).x / stripW) * duration
        var newStart = trimStart + delta

        newStart = max(0, newStart)
        let selectedDuration = trimEnd - newStart
        if selectedDuration < minDuration { newStart = trimEnd - minDuration }
        if selectedDuration > maxDuration { newStart = trimEnd - maxDuration }
        newStart = max(0, newStart)

        trimStart = newStart
        g.setTranslation(.zero, in: view)
        updateTrimUI()

        if isPlaying { player?.pause(); isPlaying = false; updatePlayButtonIcon() }
        player?.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
    }

    @objc private func rightPan(_ g: UIPanGestureRecognizer) {
        let delta = Double(g.translation(in: view).x / stripW) * duration
        var newEnd = trimEnd + delta

        newEnd = min(duration, newEnd)
        let selectedDuration = newEnd - trimStart
        if selectedDuration < minDuration { newEnd = trimStart + minDuration }
        if selectedDuration > maxDuration { newEnd = trimStart + maxDuration }
        newEnd = min(duration, newEnd)

        trimEnd = newEnd
        g.setTranslation(.zero, in: view)
        updateTrimUI()

        if isPlaying { player?.pause(); isPlaying = false; updatePlayButtonIcon() }
    }

    // MARK: - Thumbnails

    private func generateThumbnails() {
        guard !thumbnailsGenerated, stripW > 0, let asset = asset else { return }
        thumbnailsGenerated = true

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)

        let count = max(1, Int(stripW / 60))
        let thumbWidth = stripW / CGFloat(count)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var images: [(Int, CGImage)] = []
            for i in 0..<count {
                let time = CMTime(seconds: self.duration * Double(i) / Double(count), preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    images.append((i, cgImage))
                }
            }
            DispatchQueue.main.async {
                for (i, cgImage) in images {
                    let iv = UIImageView(image: UIImage(cgImage: cgImage))
                    iv.contentMode = .scaleAspectFill
                    iv.clipsToBounds = true
                    iv.frame = CGRect(x: thumbWidth * CGFloat(i), y: 0, width: thumbWidth + 1, height: self.stripHeight)
                    self.thumbnailStrip.insertSubview(iv, at: 0)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        player?.pause()
        let start = CMTime(seconds: trimStart, preferredTimescale: 600)
        let dur = CMTime(seconds: trimEnd - trimStart, preferredTimescale: 600)
        let range = CMTimeRange(start: start, duration: dur)
        onConfirm?(phAsset, range)

        if let root = presentingViewController?.presentingViewController {
            root.dismiss(animated: true)
        } else {
            presentingViewController?.dismiss(animated: true) ?? dismiss(animated: true)
        }
    }
}
