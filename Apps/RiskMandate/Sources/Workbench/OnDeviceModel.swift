import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether the on-device model can run here, in words the screen can show.
enum ModelStatus: Equatable, Sendable {
    case available
    case unavailable(String)

    var isAvailable: Bool { self == .available }
}

/// The local model behind the Workbench. Today: Apple's Foundation Models (iOS 26).
/// Gemma 4 E2B (LiteRT-LM or MLX) comes next behind the same shape.
enum OnDeviceModel {
    static let name = "Apple Foundation Models"

    static var status: ModelStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelsRunner.status
        }
        return .unavailable("Needs iOS 26 or later with Apple Intelligence.")
        #else
        return .unavailable("This build has no Foundation Models SDK.")
        #endif
    }

    /// Streams an answer to `prompt`. `onText` gets the whole answer so far on every chunk.
    static func run(prompt: String, onText: @escaping @MainActor @Sendable (String) -> Void) async throws -> RunMetrics {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await FoundationModelsRunner.run(prompt: prompt, onText: onText)
        }
        #endif
        throw WorkbenchError.unavailable
    }
}

enum WorkbenchError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: "The on-device model is not available on this device."
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
enum FoundationModelsRunner {
    static var status: ModelStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("This device does not support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Turn on Apple Intelligence in Settings to use the on-device model.")
            case .modelNotReady:
                return .unavailable("The on-device model is still downloading. Try again later.")
            @unknown default:
                return .unavailable("The on-device model is not available right now.")
            }
        }
    }

    static func run(prompt: String, onText: @escaping @MainActor @Sendable (String) -> Void) async throws -> RunMetrics {
        let session = LanguageModelSession()
        var clock = RunClock()
        var text = ""
        for try await snapshot in session.streamResponse(to: prompt) {
            clock.markChunk()
            text = snapshot.content
            let soFar = text
            await onText(soFar)
        }
        return clock.finish(text: text)
    }
}
#endif
