import BackgroundTasks
import Foundation

/// Background refresh of the open vaults (`BGAppRefreshTask`).
///
/// Each app passes its own task id (for example `news.promptugal.reader.vault-refresh` in the public app) and
/// lists it in `BGTaskSchedulerPermittedIdentifiers` in its Info.
/// The app calls `VaultBackground.register(taskIdentifier:)` once, before it finishes launching
/// (in its `App.init`), and `VaultBackground.schedule()` when the scene goes to the background.
/// The refresh only pulls vaults already open in memory; it never asks for Face ID and never unlocks keys.
@MainActor
public enum VaultBackground {
    private static var registered = false
    private static var identifier: String?

    /// Register the task handler and schedule the first refresh. Safe to call more than once.
    public static func register(taskIdentifier: String) {
        guard !registered else { return }
        registered = true
        identifier = taskIdentifier
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            MainActor.assumeIsolated { handle(refresh) }
        }
        schedule()
    }

    /// Ask iOS for the next refresh, about 15 minutes from now (iOS chooses the real time).
    /// Does nothing until `register(taskIdentifier:)` has been called.
    public static func schedule() {
        guard let identifier else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task { @MainActor in
            let ok = await VaultSession.shared.backgroundRefresh()
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { work.cancel() }
    }
}
