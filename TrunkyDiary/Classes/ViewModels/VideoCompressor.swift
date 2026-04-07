import AVFoundation
import UIKit
import Photos

final class VideoCompressor {

    static let maxDuration: TimeInterval = 30

    // MARK: - Compress from PHAsset

    static func compress(asset: PHAsset, completion: @escaping (Data?) -> Void) {
        compress(asset: asset, timeRange: nil, completion: completion)
    }

    static func compress(asset: PHAsset, timeRange: CMTimeRange?, completion: @escaping (Data?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            compressFromURL(url: urlAsset.url, timeRange: timeRange, completion: completion)
        }
    }

    // MARK: - Compress from URL

    static func compressFromURL(url: URL, timeRange: CMTimeRange? = nil, completion: @escaping (Data?) -> Void) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 지정된 구간 또는 30초 제한
        if let range = timeRange {
            exportSession.timeRange = range
        } else if duration > maxDuration {
            let start = CMTime.zero
            let end = CMTime(seconds: maxDuration, preferredTimescale: 600)
            exportSession.timeRange = CMTimeRange(start: start, end: end)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            defer { try? FileManager.default.removeItem(at: outputURL) }

            guard exportSession.status == .completed else {
                print("Video export failed: \(exportSession.error?.localizedDescription ?? "")")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let data = try? Data(contentsOf: outputURL)
            DispatchQueue.main.async { completion(data) }
        }
    }

    // MARK: - Thumbnail from PHAsset

    static func thumbnail(from asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1080, height: 1080)

            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                DispatchQueue.main.async { completion(image) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - Thumbnail from Data

    static func thumbnail(from data: Data) -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let asset = AVURLAsset(url: tempURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1080, height: 1080)

        guard let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Temp File for Playback

    static func tempFileURL(from data: Data) -> URL {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("video_cache")
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        let url = cacheDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        try? data.write(to: url)
        return url
    }

    // MARK: - Duration Check

    static func duration(of asset: PHAsset) -> TimeInterval {
        asset.duration
    }
}
