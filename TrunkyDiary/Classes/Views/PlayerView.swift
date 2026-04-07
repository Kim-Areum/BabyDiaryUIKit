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

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let url = VideoCompressor.tempFileURL(from: data)

            // 백그라운드에서 asset 로드
            let asset = AVURLAsset(url: url)
            asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.tempURL = url

                    let item = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: item)
                    player.isMuted = self.isMuted
                    player.automaticallyWaitsToMinimizeStalling = false
                    self.player = player
                    self.playerLayer.videoGravity = .resizeAspectFill

                    // Loop
                    self.loopObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: item,
                        queue: .main
                    ) { [weak player] _ in
                        player?.seek(to: .zero)
                        player?.play()
                    }

                    // readyToPlay 후에 playerLayer 연결 + 첫 프레임 seek + 재생
                    self.statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                        guard item.status == .readyToPlay, let self = self else { return }
                        self.statusObserver = nil
                        self.playerLayer.player = self.player
                        self.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                            self.player?.play()
                        }
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
