import AVFoundation
import UIKit

final class PlayerView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var loopObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var tempURL: URL?

    var isMuted: Bool = true {
        didSet { player?.isMuted = isMuted }
    }

    // MARK: - Play

    func play(data: Data) {
        cleanup()

        // 무음 모드에서도 볼륨 키로 소리 재생 가능하도록
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        // 파일 쓰기를 백그라운드에서 처리
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let url = VideoCompressor.tempFileURL(from: data)

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.tempURL = url

                let asset = AVURLAsset(url: url)
                let item = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: item)
                player.isMuted = self.isMuted
                player.automaticallyWaitsToMinimizeStalling = false
                self.playerLayer.player = player
                self.playerLayer.videoGravity = .resizeAspectFill
                self.player = player

                // Loop
                self.loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak player] _ in
                    player?.seek(to: .zero)
                    player?.play()
                }

                // readyToPlay 상태가 되면 재생 시작
                self.statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    if item.status == .readyToPlay {
                        self?.player?.play()
                        self?.statusObserver = nil
                    }
                }
            }
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
        playerLayer.player = nil
        statusObserver?.invalidate()
        statusObserver = nil
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
            tempURL = nil
        }
        player = nil
    }

    deinit {
        cleanup()
    }
}
