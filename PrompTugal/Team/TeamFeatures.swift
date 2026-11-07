import SwiftUI

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

    private var started = false

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
    }

    /// Starts the StoreKit listener and the reminders, and refreshes the team data in the background.
    func start() {
        guard !started else { return }
        started = true
        credits.start()
        reminders.start()
        Task { await team.refresh(person: identity.current?.id) }
    }

    /// Gives the schedule the current agenda (call after each agenda refresh), so picks sort and remind by start time.
    func agendaDidLoad(_ events: [Event]) {
        schedule.updateEvents(events)
        planner.updateAgenda(events)
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

    func body(content: Content) -> some View {
        @Bindable var bridge = features.bridge
        content
            .environment(features.schedule)
            .environment(features.team)
            .environment(features.identity)
            .environment(features.reminders)
            .environment(features.meter)
            .environment(features.credits)
            .environment(features.bridgeLog)
            .environment(features.bridge)
            .environment(features.planner)
            .sheet(isPresented: $bridge.topUpRequested) {
                NavigationStack { ReadingCreditView() }
                    .environment(features.meter)
                    .environment(features.credits)
            }
            .task { features.start() }
    }
}
