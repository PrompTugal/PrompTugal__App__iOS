import Foundation
import Observation
import UserNotifications

/// Local notifications before each pick and each team stand-up (brief 03), in Lisbon time, within iOS's limit of
/// 64 pending notifications. Rescheduled whenever the schedule, the stand-ups or the identity change.
@MainActor @Observable
final class ReminderScheduler {
    enum Authorization: String, Sendable { case unknown, allowed, denied }

    var leadMinutes: Int {
        didSet { defaults.set(leadMinutes, forKey: Keys.lead); scheduleSoon() }
    }
    var picksOn: Bool {
        didSet { defaults.set(picksOn, forKey: Keys.picks); scheduleSoon() }
    }
    var standupsOn: Bool {
        didSet { defaults.set(standupsOn, forKey: Keys.standups); scheduleSoon() }
    }
    private(set) var authorization: Authorization = .unknown
    private(set) var planned: [ReminderItem] = []
    private(set) var lastScheduled: Date?
    /// A reminder the person tapped; the shell opens it.
    var openedURL: URL?

    static let leadChoices = [0, 5, 10, 15, 30]

    @ObservationIgnored private let schedule: ScheduleStore
    @ObservationIgnored private let team: TeamStore
    @ObservationIgnored private let identity: TeamIdentityStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var delegate: ReminderDelegate?

    private enum Keys {
        static let lead = "reminders.leadMinutes"
        static let picks = "reminders.picks"
        static let standups = "reminders.standups"
    }

    init(schedule: ScheduleStore, team: TeamStore, identity: TeamIdentityStore, defaults: UserDefaults = .standard) {
        self.schedule = schedule
        self.team = team
        self.identity = identity
        self.defaults = defaults
        leadMinutes = defaults.object(forKey: Keys.lead) as? Int ?? 10
        picksOn = defaults.object(forKey: Keys.picks) as? Bool ?? true
        standupsOn = defaults.object(forKey: Keys.standups) as? Bool ?? true
        for name in [Notification.Name.scheduleDidChange, .teamStandupsDidChange, .teamIdentityDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleSoon() }
            })
        }
    }

    /// Call once at launch: becomes the notification delegate (to show reminders in the foreground and open the
    /// tapped one) and schedules with the current permission, without asking for it.
    func start() {
        guard delegate == nil else { return }
        let delegate = ReminderDelegate { [weak self] url in
            Task { @MainActor in self?.openedURL = url }
        }
        self.delegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
        scheduleSoon()
    }

    /// Asks once; later calls return the answer given.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorization = granted ? .allowed : .denied
        return granted
    }

    /// Replaces the app's pending reminders with the current plan. Returns how many are scheduled.
    @discardableResult
    func reschedule(now: Date = .now) async -> Int {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorization = .allowed
        case .denied: authorization = .denied
        default: authorization = .unknown
        }
        let plan = ReminderPlan.items(picks: schedule.picks, standups: team.upcomingStandups(after: now),
                                      person: identity.current?.id, leadMinutes: leadMinutes, now: now,
                                      includePicks: picksOn, includeStandups: standupsOn)
        planned = plan
        guard authorization == .allowed else { return 0 }

        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(ReminderPlan.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        var added = 0
        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = item.kind.rawValue
            content.interruptionLevel = .timeSensitive
            if let url = item.url { content.userInfo = ["url": url.absoluteString] }
            let trigger = UNCalendarNotificationTrigger(dateMatching: ReminderPlan.components(item.fire), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
                added += 1
            } catch {
                continue
            }
        }
        lastScheduled = now
        return added
    }

    /// Coalesces bursts of changes (a sync can change many picks at once) into one reschedule.
    private func scheduleSoon() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.reschedule()
        }
    }
}

/// Shows reminders while the app is open, and reports the tapped one's link.
private final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let onOpen: @Sendable (URL) -> Void

    init(onOpen: @escaping @Sendable (URL) -> Void) {
        self.onOpen = onOpen
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let text = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: text) {
            onOpen(url)
        }
    }
}
