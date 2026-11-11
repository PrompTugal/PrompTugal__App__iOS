import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// Lisbon Fringe (news.promptugal.fringe): an independent guide to the side events, meetups and communities around
/// Web Summit Lisbon. It reads lisbontechfringe.com and the storm site only, collects no data and has no account.
@main @MainActor
struct FringeApp: App {
    @State private var store = FringeStore()
    @State private var schedule: ScheduleStore
    @State private var reminders: ReminderScheduler

    init() {
        // The scheme reminder links use; Info.plist registers it.
        AppLinks.scheme = "fringe"
        let schedule = ScheduleStore()
        AgendaHub.schedule = schedule
        _schedule = State(initialValue: schedule)
        _reminders = State(initialValue: ReminderScheduler(schedule: schedule, team: nil, identity: nil, urlScheme: AppLinks.scheme))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(schedule)
                .environment(reminders)
        }
    }
}
