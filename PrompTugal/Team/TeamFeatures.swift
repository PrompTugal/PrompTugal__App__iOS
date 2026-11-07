import SwiftUI
import UIKit
import UserNotifications

/// The team session's stores and services, created once and shared. The shell injects them with
/// `.teamFeatures()` and calls `TeamFeatures.shared.start()` once at launch.
///
///     WindowGroup { AppShell().teamFeatures() }
///
/// Every view in Schedule/, Team/, Notifications/ and Store/ reads its store from the environment.
@MainActor
final class TeamFeatures {
    static let shared = TeamFeatures()

    let schedule: ScheduleStore
    let team: TeamStore
    let identity: TeamIdentityStore
    let reminders: ReminderScheduler
    let meter: MeterStore
    let credits: CreditStore
    let bridgeLog: BridgeLog
    let bridge: AppBridge
    let planner: PlannerStore
    let vaultLink: ScheduleVaultLink

    private var started = false
    private var agenda: [Event] = []
    private var observers: [NSObjectProtocol] = []

    init(directory: URL? = nil) {
        schedule = ScheduleStore(directory: directory)
        team = TeamStore(directory: directory?.appendingPathComponent("team", isDirectory: true))
        identity = TeamIdentityStore()
        reminders = ReminderScheduler(schedule: schedule, team: team, identity: identity)
        meter = MeterStore(directory: directory)
        credits = CreditStore(meter: meter)
        bridgeLog = BridgeLog()
        bridge = AppBridge(log: bridgeLog, schedule: schedule, meter: meter, identity: identity, reminders: reminders)
        planner = PlannerStore(schedule: schedule, team: team, identity: identity)
        vaultLink = ScheduleVaultLink(schedule: schedule, log: bridgeLog)
    }

    /// Starts the StoreKit listener and the reminders, and refreshes the team data in the background.
    func start() {
        guard !started else { return }
        started = true
        credits.start()
        reminders.start()
        vaultLink.start()
        observers.append(NotificationCenter.default.addObserver(forName: .scheduleDidChange, object: schedule,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishNowNext() }
        })
        publishNowNext()
        observers.append(NotificationCenter.default.addObserver(forName: .teamIdentityDidChange, object: identity,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateBadge() }
        })
        Task { await refreshTeam() }
    }

    /// Team data, then the badge and reminders. Also the work for a `BGAppRefreshTask` (platform registers it,
    /// identifier `news.promptugal.reader.refresh`, and calls this).
    func refreshTeam() async {
        await team.refresh(person: identity.current?.id)
        await vaultLink.pull()
        updateBadge()
        await reminders.reschedule()
    }

    /// The app icon badge (brief 03): only you + decide + overdue for the chosen person, from me.json.
    /// Shown only when notifications are allowed (iOS needs the badge permission), cleared with no identity.
    func updateBadge() {
        let count = identity.current.flatMap { team.me?.person($0.id)?.badge } ?? 0
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.badgeSetting == .enabled || count == 0 else { return }
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    private var lastForeground: Date?

    /// The app came to the foreground: top up reminders (iOS keeps at most 64, so later ones are added as earlier
    /// ones pass), read the vault's picks and refresh team data, at most every 10 minutes.
    func didBecomeActive() {
        guard started else { return }
        if let last = lastForeground, Date.now.timeIntervalSince(last) < 600 { return }
        lastForeground = .now
        Task {
            await reminders.reschedule()
            await vaultLink.pull()
            await team.refresh(person: identity.current?.id)
            updateBadge()
        }
    }

    /// Gives the schedule the current agenda (call after each agenda refresh), so picks sort and remind by start time.
    func agendaDidLoad(_ events: [Event]) {
        agenda = events
        schedule.updateEvents(events)
        planner.updateAgenda(events)
        publishNowNext()
    }

    /// The widgets' "Now and next" (platform's `NowNextPublisher`), with the schedule's picks as mine.
    func publishNowNext() {
        guard !agenda.isEmpty else { return }       // until the agenda arrives, the reader's snapshot stands
        NowNextPublisher.publish(agenda: agenda, saved: schedule.picks.compactMap(\.event))
    }
}

extension View {
    /// Puts the team session's stores in the environment and presents the native top-up when a page asks for it.
    func teamFeatures(_ features: TeamFeatures = .shared) -> some View {
        modifier(TeamFeaturesModifier(features: features))
    }
}

private struct TeamFeaturesModifier: ViewModifier {
    let features: TeamFeatures
    @Environment(\.teamFeaturesApplied) private var alreadyApplied
    @Environment(\.scenePhase) private var scenePhase

    /// Applied more than once (the app root and the shell both do), only the outermost copy injects and presents,
    /// so there is one top-up sheet.
    @ViewBuilder func body(content: Content) -> some View {
        if alreadyApplied {
            content
        } else {
            applied(content)
        }
    }

    private func applied(_ content: Content) -> some View {
        @Bindable var bridge = features.bridge
        return content
            .environment(\.teamFeaturesApplied, true)
            .environment(features.schedule)
            .environment(features.team)
            .environment(features.identity)
            .environment(features.reminders)
            .environment(features.meter)
            .environment(features.credits)
            .environment(features.bridgeLog)
            .environment(features.bridge)
            .environment(features.planner)
            .environment(features.vaultLink)
            .sheet(isPresented: Binding(get: { bridge.topUpRequested && ReadingCredit.isAvailable },
                                        set: { bridge.topUpRequested = $0 })) {
                NavigationStack { ReadingCreditView(showsDone: true) }
                    .environment(features.meter)
                    .environment(features.credits)
            }
            // notify.plan from a page: the permission prompt only follows a tap on this native alert (S7).
            .alert("Turn on reminders?", isPresented: $bridge.remindersRequested) {
                Button("Turn On") {
                    Task {
                        if await features.reminders.requestAuthorization() { await features.reminders.reschedule() }
                    }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("PrompTugal reminds you before the sessions you pick and your team stand-ups.")
            }
            .task { features.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { features.didBecomeActive() }
            }
            // A tapped reminder (Q6): its promptugal://open/… link goes through the system, so it reaches the
            // shell's onOpenURL → AppShell.route, as any other deep link.
            .onChange(of: features.reminders.openedURL, initial: true) { _, url in
                guard let url else { return }
                features.reminders.openedURL = nil
                UIApplication.shared.open(url)
            }
    }
}

private struct TeamFeaturesAppliedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var teamFeaturesApplied: Bool {
        get { self[TeamFeaturesAppliedKey.self] }
        set { self[TeamFeaturesAppliedKey.self] = newValue }
    }
}
