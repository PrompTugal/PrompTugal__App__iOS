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
    nonisolated static let postedKey = "local.alerts.posted"
    nonisolated static let seenLimit = 600
    /// No alert between these hours, local time (22:00 to 08:00).
    nonisolated static let quietFrom = 22
    nonisolated static let quietUntil = 8

    @ObservationIgnored private let calendar: Calendar

    public init(defaults: UserDefaults = .standard, fetch: @escaping LocalFetch = LocalStore.liveFetch,
                notifier: any AlertNotifier = SystemNotifier(), clock: @escaping @Sendable () -> Date = { Date() },
                calendar: Calendar = .current) {
        self.defaults = defaults
        self.fetch = fetch
        self.notifier = notifier
        self.clock = clock
        self.calendar = calendar
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

    /// Reads each enabled topic and posts at most one alert a topic a day, never between 22:00 and 08:00. What is
    /// new but held back (quiet hours, or already one today) stays unseen and goes into the next alert allowed.
    public func check() async {
        guard !running, !enabled.isEmpty else { return }
        running = true
        defer { running = false }
        let places = followed
        let now = clock()
        for topic in AlertTopics.all where enabled.contains(topic.id) {
            guard let data = try? await fetch(topic.feed) else { continue }
            let found = topic.candidates(from: data, followed: places, now: now)
            if !hasSeen(topic.id) {
                markSeen(found, topic: topic.id)          // first run: note what is there, post nothing
                continue
            }
            let fresh = unseen(found, topic: topic.id)
            guard !fresh.isEmpty, !Self.isQuiet(now, calendar: calendar), !postedToday(topic.id, now: now),
                  let alert = Self.combine(fresh) else { continue }
            await notifier.post(alert)
            markSeen(found, topic: topic.id)
            notePosted(topic.id, now: now)
        }
        lastCheck = now
    }

    /// Between 22:00 and 08:00 on the reader's clock.
    nonisolated static func isQuiet(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= quietFrom || hour < quietUntil
    }

    /// One alert for everything new in a topic: the first as it is, the rest counted.
    nonisolated static func combine(_ alerts: [AlertCandidate]) -> AlertCandidate? {
        guard let first = alerts.first else { return nil }
        guard alerts.count > 1 else { return first }
        let more = LocalText.string("And \(String(describing: alerts.count - 1)) more in PrompTugal.")
        return AlertCandidate(id: first.id, topic: first.topic, title: first.title, body: first.body + " " + more,
                              link: first.link)
    }

    func hasSeen(_ topic: String) -> Bool { seenIDs()[topic] != nil }

    func unseen(_ found: [AlertCandidate], topic: String) -> [AlertCandidate] {
        let known = Set(seenIDs()[topic] ?? [])
        return found.filter { !known.contains($0.id) }
    }

    func markSeen(_ found: [AlertCandidate], topic: String) {
        var seen = seenIDs()
        var list = seen[topic] ?? []
        let known = Set(list)
        for alert in found where !known.contains(alert.id) { list.append(alert.id) }
        seen[topic] = Array(list.suffix(Self.seenLimit))
        defaults.set(seen, forKey: Self.seenKey)
    }

    private func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private func postedToday(_ topic: String, now: Date) -> Bool {
        let posted = defaults.dictionary(forKey: Self.postedKey) as? [String: String] ?? [:]
        return posted[topic] == dayString(now)
    }

    private func notePosted(_ topic: String, now: Date) {
        var posted = defaults.dictionary(forKey: Self.postedKey) as? [String: String] ?? [:]
        posted[topic] = dayString(now)
        defaults.set(posted, forKey: Self.postedKey)
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
