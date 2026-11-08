import AppIntents
import Foundation
import PTAgenda

/// App Intents extension: Siri, Shortcuts and Spotlight answers that need
/// nothing but the App Group snapshot. It never reads the vault or the network.
@main
struct PrompTugalIntentsExtension: AppIntentsExtension {}

struct NextSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Next session"
    static let description = IntentDescription("Says which session is next, in Lisbon time.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let now = Date.now
        guard let snapshot = SharedContainer.readNowNext() else {
            return .result(value: "", dialog: "Open PrompTugal once to load the agenda.")
        }
        let next = snapshot.next(after: now, limit: 1).first
        if let running = snapshot.now(at: now).first {
            let after = next.map { " Next, at \(LisbonClock.time($0.start)): \($0.title)." } ?? ""
            return .result(value: running.title, dialog: "Now: \(running.title), \(running.place).\(after)")
        }
        guard let next else {
            return .result(value: "", dialog: "No sessions coming up.")
        }
        return .result(value: next.title,
                       dialog: "Next, at \(LisbonClock.time(next.start)): \(next.title), \(next.place).")
    }
}
