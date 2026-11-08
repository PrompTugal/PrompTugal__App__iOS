import SwiftUI
import PTCore
import PTAgenda
import PTVaultUI

/// Entry point of the public PrompTugal app (news.promptugal.reader).
/// Background task ids for this app: news.promptugal.reader.refresh and
/// news.promptugal.reader.vault-refresh (both listed in Info.plist).
/// This app has no team and no lanes: it never calls the Team app's wiring.
@main @MainActor
struct PrompTugalApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The app's own URL scheme, before any view reads it (reminder links, deep links).
        AppLinks.scheme = "promptugal"
        // The one schedule. PTAsk's PublicAskProvider reads its picks from here.
        let schedule = ScheduleStore()
        AgendaHub.schedule = schedule
        // The widgets' "Now and next": the agenda, with the schedule's picks as the saved sessions.
        AgendaHub.agendaDidLoad = { events in
            schedule.updateEvents(events)
            NowNextPublisher.publish(agenda: events, saved: schedule.picks.compactMap(\.event))
        }
        AgendaHub.publishNowNext = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }
        // Background tasks must be registered before the app finishes launching.
        VaultBackground.register(taskIdentifier: "news.promptugal.reader.vault-refresh")
    }

    var body: some Scene {
        WindowGroup {
            PublicShell()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { VaultBackground.schedule() }
        }
    }
}
