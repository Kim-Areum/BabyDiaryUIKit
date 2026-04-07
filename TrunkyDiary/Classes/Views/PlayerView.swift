import AVFoundation
import UIKit

final class PlayerView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var player: AVPlayer?
    private var loopObserver: Any?
    private var tempURL: URL?

    var isMuted: Bool = true {
        didSet { player?.isMuted = isMuted }
    }

    // MARK: - Play

    func play(data: Data) {
        cleanup()

        let url = VideoCompressor.tempFileURL(from: data)
        tempURL = url

        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        self.player = player

        // Loop
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        player.play()
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
