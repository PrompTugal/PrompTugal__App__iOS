import BackgroundTasks
import Foundation

/// Background refresh for a sync, with the task id taken from the app's entry point (it must also be listed in Info.plist).
/// Register before launch finishes, as `VaultBackground` does.
public enum SyncBackground {
    private final class Registration: @unchecked Sendable {
        private let lock = NSLock()
        private var identifier: String?
        private var work: (@Sendable () async -> Bool)?
        var isRegistered: Bool { lock.withLock { identifier != nil } }
        func set(identifier: String, work: @escaping @Sendable () async -> Bool) {
            lock.withLock { self.identifier = identifier; self.work = work }
        }
        func current() -> (String, @Sendable () async -> Bool)? {
            lock.lock()
            defer { lock.unlock() }
            guard let identifier, let work else { return nil }
            return (identifier, work)
        }
    }

    private static let registration = Registration()

    /// `run` does the sync and the outbox flush and returns whether it worked. Safe to call more than once.
    public static func register(taskIdentifier: String, run: @escaping @Sendable () async -> Bool) {
        guard !registration.isRegistered else { return }
        registration.set(identifier: taskIdentifier, work: run)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task)
        }
        schedule()
    }

    /// Ask iOS for the next refresh, about 15 minutes from now (iOS chooses the real time).
    public static func schedule() {
        guard let (identifier, _) = registration.current() else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGTask) {
        schedule()
        guard let (_, run) = registration.current() else {
            task.setTaskCompleted(success: false)
            return
        }
        let work = Task {
            let ok = await run()
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { work.cancel() }
    }
}
