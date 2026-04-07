import AVFoundation
import UIKit

/// AVPlayerLayer 기반 비디오 재생 뷰
final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var loopObserver: Any?

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

    func play(data: Data) {
        cleanup()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let url = VideoCompressor.cachedTempFileURL(from: data)

        // player 생성 후 seek(0)으로 첫 프레임 확정, 그 다음 레이어 연결 + 재생
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

        // 첫 프레임을 먼저 seek으로 확정
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            // seek 완료 후 레이어에 연결 → 첫 프레임부터 깨끗하게 표시
            self.playerLayer.player = self.player
            self.playerLayer.videoGravity = .resizeAspectFill
            self.player?.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
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
    }

    deinit {
        cleanup()
    }
}
