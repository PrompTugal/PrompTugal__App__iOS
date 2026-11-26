import BackgroundTasks
import Foundation
import Observation
import UserNotifications

/// Posts local notifications; the system one in the app, a recorder in tests.
public protocol AlertNotifier: Sendable {
    /// Asks the reader once; true when notifications are allowed.
    func requestAuthorization() async -> Bool
    func isAuthorized() async -> Bool
    func post(_ alert: AlertCandidate) async
}

/// The system's notification centre. Local notifications only: nothing is registered for remote push.
public struct SystemNotifier: AlertNotifier {
    public init() {}

    public func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    public func post(_ alert: AlertCandidate) async {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.threadIdentifier = "local.alerts." + alert.topic
        if let link = alert.link { content.userInfo = ["url": link.absoluteString, "topic": alert.topic] }
        let request = UNNotificationRequest(identifier: "local.alerts." + alert.id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Opt-in alerts, local only. The reader turns each topic on in Alerts (notification permission is asked then, not
/// before). Each check reads the topics' public files (the same for every reader), picks what concerns the followed
/// places on the phone and posts what is new. The first check of a topic only notes what is there, so turning an
/// alert on never floods. Runs when the app is open and in background refresh.
@MainActor @Observable
public final class AlertsCenter {
    public static let shared = AlertsCenter()

    /// The background refresh task. The app lists it in Info.plist (BGTaskSchedulerPermittedIdentifiers).
    public nonisolated static let backgroundTaskID = "news.promptugal.reader.alerts"

    public private(set) var enabled: Set<String>
    public private(set) var lastCheck: Date?
    public private(set) var message: String?
    public private(set) var permissionDenied = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let notifier: any AlertNotifier
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var running = false

    nonisolated static let enabledKey = "local.alerts.enabled"
    nonisolated static let seenKey = "local.alerts.seen"
    /// At most this many notifications per topic per check; more become one summary line.
    nonisolated static let perCheck = 3
    nonisolated static let seenLimit = 600

    public init(defaults: UserDefaults = .standard, fetch: @escaping LocalFetch = LocalStore.liveFetch,
                notifier: any AlertNotifier = SystemNotifier(), clock: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.fetch = fetch
        self.notifier = notifier
        self.clock = clock
        enabled = Set(defaults.stringArray(forKey: Self.enabledKey) ?? [])
    }

    public func isOn(_ topic: String) -> Bool { enabled.contains(topic) }

    public var followed: [String] { FollowedPlaces.current(defaults) }

    /// Turns a topic on (asking for permission the first time) or off.
    public func set(_ topic: String, on: Bool) async {
        if on {
            var allowed = await notifier.isAuthorized()
            if !allowed { allowed = await notifier.requestAuthorization() }
            guard allowed else {
                permissionDenied = true
                message = LocalText.string("Notifications are off for PrompTugal in Settings, so alerts cannot be shown.")
                return
            }
            permissionDenied = false
            enabled.insert(topic)
        } else {
            enabled.remove(topic)
            clearSeen(topic)
        }
        defaults.set(enabled.sorted(), forKey: Self.enabledKey)
        message = nil
        if on {
            await check()
            Self.scheduleRefresh()
        }
    }

    /// Reads each enabled topic once and posts what is new for the followed places.
    public func check() async {
        guard !running, !enabled.isEmpty else { return }
        running = true
        defer { running = false }
        let places = followed
        let now = clock()
        for topic in AlertTopics.all where enabled.contains(topic.id) {
            guard let data = try? await fetch(topic.feed) else { continue }
            let found = topic.candidates(from: data, followed: places, now: now)
            let fresh = newAlerts(found, topic: topic.id)
            for alert in Self.limit(fresh, topic: topic.id) { await notifier.post(alert) }
        }
        lastCheck = now
    }

    /// What has not been seen, and notes all of `found` as seen. The first time a topic runs, nothing is new.
    func newAlerts(_ found: [AlertCandidate], topic: String) -> [AlertCandidate] {
        var seen = seenIDs()
        let firstRun = seen[topic] == nil
        let known = Set(seen[topic] ?? [])
        let fresh = firstRun ? [] : found.filter { !known.contains($0.id) }
        var list = seen[topic] ?? []
        for alert in found where !known.contains(alert.id) { list.append(alert.id) }
        seen[topic] = Array(list.suffix(Self.seenLimit))
        defaults.set(seen, forKey: Self.seenKey)
        return fresh
    }

    /// Up to three alerts as they are; any more become one line that says how many.
    nonisolated static func limit(_ alerts: [AlertCandidate], topic: String) -> [AlertCandidate] {
        guard alerts.count > perCheck else { return alerts }
        var out = Array(alerts.prefix(perCheck - 1))
        let rest = alerts.count - out.count
        out.append(AlertCandidate(id: "more|\(topic)|\(alerts[perCheck - 1].id)", topic: topic,
                                  title: LocalText.string("\(rest) more"),
                                  body: LocalText.string("Open PrompTugal to see them all."), link: nil))
        return out
    }

    private func seenIDs() -> [String: [String]] {
        (defaults.dictionary(forKey: Self.seenKey) as? [String: [String]]) ?? [:]
    }

    private func clearSeen(_ topic: String) {
        var seen = seenIDs()
        seen[topic] = nil
        defaults.set(seen, forKey: Self.seenKey)
    }

    // MARK: Background refresh

    /// Call once before launch finishes (the app's init). Safe to call more than once.
    public nonisolated static func registerBackgroundTask() {
        guard registration.claim() else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskID, using: nil) { task in
            handle(task)
        }
    }

    /// Asks iOS for the next refresh, about an hour from now, while any alert is on. Call when the app goes to the
    /// background.
    public nonisolated static func scheduleRefresh() {
        guard registration.isRegistered else { return }
        guard !(UserDefaults.standard.stringArray(forKey: enabledKey) ?? []).isEmpty else { return }
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private nonisolated static func handle(_ task: BGTask) {
        scheduleRefresh()
        let work = Task { @MainActor in
            await AlertsCenter.shared.check()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    private nonisolated static let registration = Registration()

    private final class Registration: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        var isRegistered: Bool { lock.withLock { done } }
        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }
}
