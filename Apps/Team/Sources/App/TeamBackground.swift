import BackgroundTasks
import Foundation

/// Background refresh of the team data (`news.promptugal.team.refresh`): me.json, the command centre,
/// the vault picks, the badge and the reminders, through `TeamFeatures.refreshTeam()`.
/// The vault has its own task (`VaultBackground`). Both ids are in Apps/Team/Config/Team-Info.plist.
@MainActor
enum TeamBackground {
    static let identifier = "news.promptugal.team.refresh"
    private static var registered = false

    /// Call once, before the app finishes launching.
    static func register() {
        guard !registered else { return }
        registered = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            MainActor.assumeIsolated { handle(refresh) }
        }
    }

    /// Ask iOS for the next refresh, about 20 minutes from now (iOS chooses the real time).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task { @MainActor in
            await TeamFeatures.shared.refreshTeam()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
        task.expirationHandler = { work.cancel() }
    }
}
