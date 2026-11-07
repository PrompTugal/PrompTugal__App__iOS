import BackgroundTasks
import Foundation

/// Background refresh of the open vaults (`BGAppRefreshTask`, id `news.promptugal.reader.vault-refresh`).
///
/// Platform calls `VaultBackground.register()` once, before the app finishes launching
/// (in `PrompTugalApp.init`), and `VaultBackground.schedule()` when the scene goes to the background.
/// The refresh only pulls vaults already open in memory; it never asks for Face ID and never unlocks keys.
@MainActor
enum VaultBackground {
    private static var registered = false

    /// Register the task handler and schedule the first refresh. Safe to call more than once.
    static func register() {
        guard !registered else { return }
        registered = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: VaultConfig.backgroundRefreshTask, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            MainActor.assumeIsolated { handle(refresh) }
        }
        schedule()
    }

    /// Ask iOS for the next refresh, about 15 minutes from now (iOS chooses the real time).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: VaultConfig.backgroundRefreshTask)
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
