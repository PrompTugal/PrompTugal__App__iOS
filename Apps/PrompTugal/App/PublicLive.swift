import Foundation
import PTCore
import PTSync

/// Live news for the public app: promptugal.news feeds only, kept on the device, refreshed at launch, when the app
/// comes to the front and in the background. One background task id serves it (also in Info.plist).
enum PublicLive {
    static let taskIdentifier = "news.promptugal.reader.refresh"
    static let updates = LiveUpdates()

    /// Call once from `PrompTugalApp.init`, before the first screen reads.
    static func start() {
        updates.start()
        SyncBackground.register(taskIdentifier: taskIdentifier) { await updates.backgroundWork() }
        Task { await updates.refresh() }
    }

    static func foreground() { Task { await updates.refresh() } }
}
