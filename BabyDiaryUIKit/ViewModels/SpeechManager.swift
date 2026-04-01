import Foundation
import Speech
import AVFoundation
import NaturalLanguage
import UIKit
import FoundationModels

class SpeechManager {
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    private var currentText: String = ""

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    private var audioPlayer: AVAudioPlayer?
    private var playQueue: [URL] = []
    private var playCompletion: (() -> Void)?

    // MARK: - Recording

    func startRecording() {
        currentText = ""

        let fileName = "recording_\(UUID().uuidString).m4a"
        let url = Self.recordingsDirectory().appendingPathComponent(fileName)
        currentRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { self.beginSpeechSession() }
        }
    }

    private func beginSpeechSession() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let result = result {
                self?.currentText = result.bestTranscription.formattedString
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    func stopRecording(completion: @escaping (String?, String?) -> Void) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        audioRecorder?.stop()
        audioRecorder = nil

        let rawText = currentText
        let fileName = currentRecordingURL?.lastPathComponent
        currentText = ""

        let fileNameResult: String?
        if let url = currentRecordingURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int, size < 1000 {
            try? FileManager.default.removeItem(at: url)
            fileNameResult = nil
        } else {
            fileNameResult = fileName
        }

        currentRecordingURL = nil

        if rawText.isEmpty {
            DispatchQueue.main.async { completion(nil, fileNameResult) }
        } else {
            Task {
                let corrected = await correctWithOnDeviceAI(rawText)
                DispatchQueue.main.async { completion(corrected, fileNameResult) }
            }
        }
    }

    // MARK: - Playback

    func playAll(fileNames: [String], completion: @escaping () -> Void) {
        let dir = Self.recordingsDirectory()
        playQueue = fileNames.compactMap { name in
            let url = dir.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        playCompletion = completion

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        playNext()
    }

    private func playNext() {
        guard !playQueue.isEmpty else {
            DispatchQueue.main.async { self.playCompletion?() }
            return
        }
        let url = playQueue.removeFirst()
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.volume = 1.0
        audioPlayer?.delegate = AudioPlayerDelegate.shared
        AudioPlayerDelegate.shared.onFinish = { [weak self] in
            self?.playNext()
        }
        audioPlayer?.play()
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playQueue = []
    }

    // MARK: - On-Device AI Correction

    private func correctWithOnDeviceAI(_ text: String) async -> String {
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession()
                let prompt = "다음 음성인식 텍스트를 자연스러운 육아 일기 문체로 다듬어줘. 맞춤법, 띄어쓰기, 구두점을 교정하고 문장을 매끄럽게 연결해. 원래 의미는 유지하고, 교정된 글만 출력해:\n\n\(text)"
                let response = try await session.respond(to: prompt)
                let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return result.isEmpty ? correctText(text) : result
            } catch {
                return correctText(text)
            }
        } else {
            return correctText(text)
        }
    }

    // MARK: - Text Correction (Fallback)

    func correctText(_ text: String) -> String {
        var result = text
        result = applySpellCheck(result)
        result = applyCommonFixes(result)
        result = applyPunctuation(result)
        return result
    }

    private func applySpellCheck(_ text: String) -> String {
        let checker = UITextChecker()
        let nsText = text as NSString
        var result = text
        var offset = 0

        while offset < nsText.length {
            let range = checker.rangeOfMisspelledWord(
                in: result, range: NSRange(location: offset, length: nsText.length - offset),
                startingAt: offset, wrap: false, language: "ko"
            )
            guard range.location != NSNotFound else { break }

            if let guesses = checker.guesses(forWordRange: range, in: result, language: "ko"),
               let best = guesses.first {
                let nsResult = result as NSString
                result = nsResult.replacingCharacters(in: range, with: best)
                offset = range.location + best.count
            } else {
                offset = range.location + range.length
            }
        }
        return result
    }

    private func applyCommonFixes(_ text: String) -> String {
        var result = text
        let fixes: [(String, String)] = [
            ("할수있", "할 수 있"), ("할수없", "할 수 없"), ("갈수있", "갈 수 있"),
            ("먹을수있", "먹을 수 있"), ("것같", "것 같"), ("거같", "거 같"),
            ("수있", "수 있"), ("수없", "수 없"), ("안돼", "안 돼"),
            ("해야돼", "해야 돼"), ("됬", "됐"), ("했데", "했대"),
            ("왔데", "왔대"), ("갔데", "갔대"), ("먹었데", "먹었대"),
            ("되요", "돼요"), ("안되", "안 돼"), ("할께", "할게"),
            ("갈께", "갈게"), ("먹을께", "먹을게"), ("몇일", "며칠"),
        ]
        for (wrong, correct) in fixes {
            result = result.replacingOccurrences(of: wrong, with: correct)
        }
        return result
    }

    private func applyPunctuation(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "  ", with: " ")
        return result
    }

    // MARK: - Directory

    static func recordingsDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

// MARK: - AudioPlayerDelegate

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
