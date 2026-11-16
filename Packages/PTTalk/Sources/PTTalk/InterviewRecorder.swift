import AVFoundation
import Foundation
import Observation
import Speech

// Ported from VoiceDebrief `Engine/VoiceRecorder.swift` and `Engine/LiveTranscriber.swift` (Apache 2.0,
// github.com/VoiceDebrief/VoiceDebrief__App__iOS). Differences: an interview is recorded as AAC (.m4a, small enough
// to send), and the transcript that is kept is made from the file afterwards by Speech on the device
// (SFSpeechRecognizer with on-device recognition, iOS 18), with the live words (SpeechAnalyzer, iOS 26) as a preview.

/// Records an interview to a file and transcribes it on the device.
@MainActor @Observable
public final class InterviewRecorder {
    public enum Phase: Equatable {
        case idle, recording, paused, transcribing, done
        case failed(String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var level: Double = 0
    public private(set) var elapsed: TimeInterval = 0
    /// While recording (iOS 26): the settled words and the part that may still change.
    public private(set) var livePreview = ""
    /// The kept transcript, from the file.
    public var transcript = ""
    public private(set) var transcriptSource: String?
    public private(set) var file: URL?

    private var recorder: AVAudioRecorder?
    private var meter: Task<Void, Never>?
    private var live: AnyObject?

    public init() {}

    public var localeId: String { Locale.current.language.languageCode?.identifier == "pt" ? "pt-PT" : Locale.current.identifier }

    public func start(localeId: String) async {
        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .failed("The microphone is not allowed. Allow it for PrompTugal in Settings."); return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("interview-\(UUID().uuidString.prefix(8)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let made = try AVAudioRecorder(url: url, settings: settings)
            made.isMeteringEnabled = true
            guard made.record() else { phase = .failed("Recording could not start."); return }
            recorder = made
            file = url
            transcript = ""
            livePreview = ""
            transcriptSource = nil
            phase = .recording
            startMeter()
            startLivePreview(localeId: localeId)
        } catch {
            phase = .failed("Recording could not start (\(error.localizedDescription)).")
        }
    }

    public func pause() { recorder?.pause(); phase = .paused }
    public func resume() { _ = recorder?.record(); phase = .recording }

    /// Stops, then transcribes the file on the device.
    public func stop(localeId: String) async {
        recorder?.stop()
        recorder = nil
        meter?.cancel()
        level = 0
        await stopLivePreview()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard let file else { phase = .idle; return }
        phase = .transcribing
        do {
            transcript = try await FileTranscriber.transcribe(file, localeId: localeId)
            transcriptSource = "on-device speech recognition (\(localeId))"
        } catch {
            transcript = livePreview
            transcriptSource = livePreview.isEmpty ? nil : "live preview on this device (\(localeId)); the full transcript failed: \(error.localizedDescription)"
        }
        phase = .done
    }

    public func discard() {
        recorder?.stop()
        recorder = nil
        meter?.cancel()
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil
        transcript = ""
        livePreview = ""
        elapsed = 0
        phase = .idle
        Task { await stopLivePreview() }
    }

    private func startMeter() {
        meter?.cancel()
        meter = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.level = Self.level(decibels: Double(recorder.averagePower(forChannel: 0)))
                self.elapsed = recorder.currentTime
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Decibels (0 is full scale, about -55 a quiet room) as 0 to 1 on a curve, so speech sits mid-scale.
    nonisolated static func level(decibels: Double) -> Double {
        guard decibels.isFinite else { return 0 }
        let linear = min(1, max(0, (decibels + 55) / 55))
        return linear * linear
    }

    private func startLivePreview(localeId: String) {
        #if canImport(Speech)
        if #available(iOS 26.0, *) {
            let transcriber = LiveTranscriber()
            live = transcriber
            let sink: @Sendable (String, String) -> Void = { [weak self] settled, volatile in
                Task { @MainActor [weak self] in self?.livePreview = settled + volatile }
            }
            Task { try? await transcriber.start(localeId: localeId, onText: sink) }
        }
        #endif
    }

    private func stopLivePreview() async {
        if #available(iOS 26.0, *), let transcriber = live as? LiveTranscriber {
            await transcriber.stop()
        }
        live = nil
    }
}

/// The kept transcript: Speech on the recorded file, on the device only.
enum FileTranscriber {
    enum Failure: LocalizedError {
        case denied, unsupported, noOnDevice, empty
        var errorDescription: String? {
            switch self {
            case .denied: "speech recognition is not allowed"
            case .unsupported: "no speech recognizer for this language"
            case .noOnDevice: "this language cannot be transcribed on the device"
            case .empty: "no words were heard"
            }
        }
    }

    static func authorize() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    static func transcribe(_ file: URL, localeId: String) async throws -> String {
        guard await authorize() else { throw Failure.denied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId)) else { throw Failure.unsupported }
        guard recognizer.supportsOnDeviceRecognition else { throw Failure.noOnDevice }
        let request = SFSpeechURLRecognitionRequest(url: file)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        let box = RecognitionBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                box.task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        let text = result.bestTranscription.formattedString
                        box.finish { text.isEmpty ? continuation.resume(throwing: Failure.empty) : continuation.resume(returning: text) }
                    } else if let error {
                        box.finish { continuation.resume(throwing: error) }
                    }
                }
            }
        } onCancel: {
            box.task?.cancel()
        }
    }

    /// Resumes the continuation once, whatever the recognizer calls back with.
    final class RecognitionBox: @unchecked Sendable {
        var task: SFSpeechRecognitionTask?
        private var done = false
        private let lock = NSLock()
        func finish(_ body: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            body()
        }
    }
}

#if canImport(Speech)
/// The words as they are spoken (SpeechAnalyzer, iOS 26). A preview only; if anything fails, recording goes on.
@available(iOS 26.0, *)
final class LiveTranscriber: @unchecked Sendable {
    enum Failure: LocalizedError {
        case unsupportedLocale, noFormat, noInput
        var errorDescription: String? {
            switch self {
            case .unsupportedLocale: "the speech model does not support this language"
            case .noFormat: "the speech model gave no audio format"
            case .noInput: "there is no microphone input"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let converter = BufferConverter()
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var tapped = false
    private var generation = 0

    func start(localeId: String, onText: @escaping @Sendable (String, String) -> Void) async throws {
        let mine = generation
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeId)) else {
            throw Failure.unsupportedLocale
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw Failure.noFormat
        }
        guard mine == generation else { return }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.analyzer = analyzer
        self.continuation = continuation

        results = Task {
            var settled = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        settled += text
                        onText(settled, "")
                    } else {
                        onText(settled, text)
                    }
                }
            } catch {
                // A preview that stops is not worth showing: the recording goes on.
            }
        }

        try await analyzer.start(inputSequence: stream)
        guard mine == generation else {
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            return
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw Failure.noInput }
        let converter = self.converter
        // installTap raises an Objective-C exception if a tap is already on the bus or the format does not match the
        // hardware's (VoiceDebrief build 0.1.91): take off any old tap and let the node use its own format (nil).
        input.removeTap(onBus: 0)
        tapped = false
        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            guard let converted = converter.convert(buffer, to: format) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
        tapped = true
        engine.prepare()
        try engine.start()
    }

    func stop() async {
        generation += 1
        if tapped {
            engine.inputNode.removeTap(onBus: 0)
            tapped = false
        }
        if engine.isRunning { engine.stop() }
        continuation?.finish()
        continuation = nil
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        results?.cancel()
        results = nil
    }
}

/// Converts the microphone's buffers to the format the speech model asks for.
final class BufferConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none
        }
        guard let converter, buffer.format.sampleRate > 0 else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var error: NSError?
        nonisolated(unsafe) var consumed = false
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }
}
#endif
