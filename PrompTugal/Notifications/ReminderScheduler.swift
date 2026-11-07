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
    @ObservationIgnored private var started = false

    private enum Keys {
        static let lead = "reminders.leadMinutes"
        static let picks = "reminders.picks"
        static let standups = "reminders.standups"
        static let asked = "reminders.askedOnce"
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
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let name = note.name
                let personal = name != .teamStandupsDidChange
                MainActor.assumeIsolated {
                    // Only a native tap may lead to the permission prompt: a pick made in the app or choosing who
                    // I am. A change a web page or the vault made is not a gesture (S7).
                    if personal, self?.changeWasNative(name) == true { self?.askOnceWhenUseful() }
                    self?.scheduleSoon()
                }
            })
        }
    }

    /// Sets the notification delegate. Call from `PrompTugalApp.init`: a reminder tapped while the app is not
    /// running is delivered during launch, before any view exists (Q6). Safe to call more than once.
    static func installNotificationDelegate() {
        let center = UNUserNotificationCenter.current()
        if center.delegate !== ReminderInbox.delegate { center.delegate = ReminderInbox.delegate }
    }

    /// Call once when the app is up: takes a reminder tapped at launch, and schedules with the current permission,
    /// without asking for it.
    func start() {
        guard !started else { return }
        started = true
        Self.installNotificationDelegate()
        observers.append(NotificationCenter.default.addObserver(forName: .reminderOpened, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.openedURL = ReminderInbox.take() }
        })
        if let pending = ReminderInbox.take() { openedURL = pending }
        scheduleSoon()
    }

    /// The first time a person picks a session or says who they are, ask for notification permission, once.
    /// That is the moment reminders make sense; asking at launch gets refused.
    private func askOnceWhenUseful() {
        guard !defaults.bool(forKey: Keys.asked) else { return }
        guard !schedule.picks.isEmpty || identity.current != nil else { return }
        defaults.set(true, forKey: Keys.asked)
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            if await requestAuthorization() { await reschedule() }
        }
    }

    private func changeWasNative(_ name: Notification.Name) -> Bool {
        name == .teamIdentityDidChange || schedule.lastChange?.source == .app
    }

    /// The permission as it stands, without asking.
    func currentAuthorization() async -> Authorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: authorization = .allowed
        case .denied: authorization = .denied
        default: authorization = .unknown
        }
        return authorization
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
            content.userInfo = ["open": item.appLink.absoluteString, "url": item.url?.absoluteString ?? ""]
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

extension Notification.Name {
    static let reminderOpened = Notification.Name("PrompTugal.reminderOpened")
}

/// Holds the link of a tapped reminder until the app can open it (a cold launch delivers it before any view).
@MainActor
enum ReminderInbox {
    static let delegate = ReminderDelegate()
    private static var pending: URL?

    static func receive(_ url: URL) {
        pending = url
        NotificationCenter.default.post(name: .reminderOpened, object: nil)
    }

    static func take() -> URL? {
        defer { pending = nil }
        return pending
    }
}

/// Shows reminders while the app is open, and reports the tapped one's in-app link.
final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let text = info["open"] as? String, let url = URL(string: text), url.scheme == "promptugal" else { return }
        await MainActor.run { ReminderInbox.receive(url) }
    }
}
