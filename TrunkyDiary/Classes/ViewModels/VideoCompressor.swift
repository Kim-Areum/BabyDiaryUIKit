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

            let duration = CMTimeGetSeconds(avAsset.duration)
            // 여러 시점에서 시도, 검은 프레임 건너뛰기
            let times: [Double] = [0.5, 1.0, 2.0, duration * 0.1, duration * 0.25]
            for t in times {
                guard t < duration else { continue }
                if let cgImage = try? generator.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
                    let image = UIImage(cgImage: cgImage)
                    if !isBlackFrame(image) {
                        DispatchQueue.main.async { completion(image) }
                        return
                    }
                }
            }
            // 모두 검은 프레임이면 첫 번째라도 반환
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                DispatchQueue.main.async { completion(UIImage(cgImage: cgImage)) }
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

        let duration = CMTimeGetSeconds(asset.duration)
        let times: [Double] = [0.5, 1.0, 2.0, duration * 0.1, duration * 0.25]
        for t in times {
            guard t < duration else { continue }
            if let cgImage = try? generator.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                if !isBlackFrame(image) { return image }
            }
        }
        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
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

    /// data의 해시 기반 캐시 - 같은 데이터면 파일 재사용
    static func cachedTempFileURL(from data: Data) -> URL {
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("video_cache")
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        let hash = data.hashValue
        let url = cacheDir.appendingPathComponent("v_\(hash)").appendingPathExtension("mp4")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
        }
        return url
    }

    // MARK: - Duration Check

    /// 이미지가 거의 검은색인지 판단 (평균 밝기 기준)
    private static func isBlackFrame(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        let pixel = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let data = pixel?.cgImage?.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return true }
        let r = CGFloat(ptr[0])
        let g = CGFloat(ptr[1])
        let b = CGFloat(ptr[2])
        let brightness = (r + g + b) / (3.0 * 255.0)
        return brightness < 0.05
    }

    static func duration(of asset: PHAsset) -> TimeInterval {
        asset.duration
    }
}
