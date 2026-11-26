import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Ported from VoiceDebrief (https://github.com/VoiceDebrief/VoiceDebrief__App__iOS, Apache License 2.0):
// Apps/VoiceDebrief/Sources/Engine/OnDeviceModel.swift (status and errors in words a screen can show) and
// LabModelDoor.swift (one fresh session per request, no history), with the streaming and the iOS 26 gate of this
// repo's Apps/RiskMandate/Sources/Workbench/OnDeviceModel.swift. PTLocal supports iOS 18, so every use of the
// framework sits behind `#available(iOS 26.0, *)`, and the app weak-links FoundationModels (PrompTugal.xcconfig)
// so it still launches where the framework does not exist.

/// Whether Apple's on-device model can run here, in words a screen can show.
public enum LocalModelStatus: Equatable, Sendable {
    case available
    case unavailable(String)

    public var isAvailable: Bool { self == .available }
    public var text: String {
        switch self {
        case .available: LocalText.string("Apple Intelligence is available on this device.")
        case .unavailable(let why): why
        }
    }
}

public enum LocalModelError: LocalizedError, Equatable {
    case unavailable(String)
    case declined
    case tooLong
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let why): why
        case .declined: LocalText.string("Apple's on-device model declined to answer this.")
        case .tooLong: LocalText.string("This was too long for Apple's on-device model in one request.")
        case .failed(let why): why
        }
    }
}

/// Apple's Foundation Models framework, on the device. Nothing leaves the phone: one fresh session per request, so
/// nothing from one question is in the context of the next.
public enum LocalModel {
    public static let name = LocalText.string("Apple Intelligence (on this device)")

    public static var status: LocalModelStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return FoundationModelsRunner.status
        }
        return .unavailable(LocalText.string("Apple Intelligence needs iOS 26 or later on a device that supports it."))
        #else
        return .unavailable(LocalText.string("This build has no Foundation Models SDK."))
        #endif
    }

    /// Streams an answer. `onText` gets the whole answer so far on every chunk; returns the final text.
    @discardableResult
    public static func stream(instructions: String, prompt: String,
                              onText: @escaping @MainActor @Sendable (String) -> Void) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .unavailable(let why) = FoundationModelsRunner.status { throw LocalModelError.unavailable(why) }
            return try await FoundationModelsRunner.stream(instructions: instructions, prompt: prompt, onText: onText)
        }
        #endif
        throw LocalModelError.unavailable(status.text)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
enum FoundationModelsRunner {
    static var status: LocalModelStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(LocalText.string("This device does not support Apple Intelligence."))
            case .appleIntelligenceNotEnabled:
                return .unavailable(LocalText.string("Apple Intelligence is switched off in Settings."))
            case .modelNotReady:
                return .unavailable(LocalText.string("Apple's on-device model is still downloading. Try again later."))
            @unknown default:
                return .unavailable(LocalText.string("Apple's on-device model is not available right now."))
            }
        }
    }

    static func stream(instructions: String, prompt: String,
                       onText: @escaping @MainActor @Sendable (String) -> Void) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        var text = ""
        do {
            for try await snapshot in session.streamResponse(to: prompt) {
                text = snapshot.content
                let soFar = text
                await onText(soFar)
            }
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                throw LocalModelError.tooLong
            case .guardrailViolation:
                throw LocalModelError.declined
            default:
                // Sorted by its words rather than by case: the cases changed between SDKs (VoiceDebrief's note).
                let words = String(describing: error).lowercased()
                if words.contains("refus") { throw LocalModelError.declined }
                throw LocalModelError.failed(error.localizedDescription)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
