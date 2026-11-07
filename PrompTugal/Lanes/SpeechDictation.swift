import AVFoundation
import Foundation
import Observation
import Speech

/// Hold-to-talk dictation for notes, transcribed on the device when the language allows it
/// (`requiresOnDeviceRecognition`). Audio is not kept.
@MainActor @Observable
final class SpeechDictation {
    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var onDevice = false
    private(set) var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    func start(locale: Locale = Locale(identifier: "en-GB")) async {
        guard !isRecording else { return }
        error = nil
        transcript = ""
        let speech = await Self.speechAuthorization()
        guard speech == .authorized else { error = "Speech recognition is not allowed (Settings → PrompTugal)."; return }
        guard await AVAudioApplication.requestRecordPermission() else { error = "The microphone is not allowed."; return }
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
            error = "Speech recognition is not available right now."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            onDevice = recognizer.supportsOnDeviceRecognition
            request.requiresOnDeviceRecognition = onDevice
            request.addsPunctuation = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            Self.installTap(on: input, format: format, feeding: request)
            engine.prepare()
            try engine.start()
            isRecording = true

            task = Self.recognize(recognizer, request) { [weak self] text, done in
                guard let self else { return }
                if let text { self.transcript = text }
                if done { self.finish() }
            }
        } catch {
            self.error = "Recording could not start (\(CollabErrorText.short(error)))."
            finish()
        }
    }

    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    /// Built outside the main actor: the tap runs on the audio thread.
    private nonisolated static func installTap(on input: AVAudioInputNode, format: AVAudioFormat,
                                               feeding request: SFSpeechAudioBufferRecognitionRequest) {
        nonisolated(unsafe) let sink = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in sink.append(buffer) }
    }

    /// Built outside the main actor: results arrive on a background queue and are handed to the main actor.
    private nonisolated static func recognize(_ recognizer: SFSpeechRecognizer, _ request: SFSpeechAudioBufferRecognitionRequest,
                                              update: @escaping @MainActor (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in update(text, done) }
        }
    }

    func stop() {
        request?.endAudio()
        finish()
    }

    private func finish() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.finish()
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
