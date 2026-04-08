import AVFoundation
import UIKit

/// AVPlayerLayer 기반 비디오 재생 뷰
final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var loopObserver: Any?
    private var currentDataHash: Int?

    var isMuted: Bool = true {
        didSet { player?.isMuted = isMuted }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Play

    /// 준비만 (재생 안 함), resumeVideo에서 재생
    func prepare(data: Data) {
        let hash = data.hashValue
        if hash == currentDataHash, player != nil { return }

        cleanup()
        currentDataHash = hash

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let url = VideoCompressor.cachedTempFileURL(from: data)
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        self.player = player
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        player.pause()
    }

    func play(data: Data) {
        let hash = data.hashValue

        // 같은 동영상이면 처음부터 재생만
        if hash == currentDataHash, player != nil, playerLayer.player != nil {
            player?.seek(to: .zero)
            player?.play()
            return
        }

        cleanup()
        currentDataHash = hash

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let url = VideoCompressor.cachedTempFileURL(from: data)
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        self.player = player

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // 첫 프레임 seek 후 레이어 연결 + 재생
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.playerLayer.player = self.player
            self.playerLayer.videoGravity = .resizeAspectFill
            self.player?.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.seek(to: .zero)
        player?.play()
    }

    func cleanup() {
        player?.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        playerLayer.player = nil
        player = nil
        currentDataHash = nil
    }

    deinit {
        cleanup()
    }
}
