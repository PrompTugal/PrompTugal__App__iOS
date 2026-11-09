import SwiftUI
import PTCore
import PTAgenda
import PTDeck
import PTSync
import PTWeb

/// Entry point of the public PrompTugal app (news.promptugal.reader).
/// Background task id for this app: news.promptugal.reader.refresh (listed in Info.plist).
/// This app has no team and no lanes: it never calls the Team app's wiring.
@main @MainActor
struct PrompTugalApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The app's own language (default English, never the device's), before any view reads a string.
        AppCulture.start()
        // The app's own URL scheme, before any view reads it (reminder links, deep links).
        AppLinks.scheme = "promptugal"
        // The public list of websites (PrompTugal.news only, no team site), before any view reads it.
        WebsiteSources.resource = "WebsitesPublic"
        // The one schedule (AgendaHub.schedule) and agendaDidLoad are set by PublicFeatures (Shell/, design), when the
        // first screen appears. Here only the widgets' "Now and next" publisher, which PublicFeatures does not set.
        // The agenda built into the app, read by ReaderStore when nothing is cached (offline first launch).
        AgendaHub.seedAgenda = { AgendaSeed.events() }
        AgendaHub.publishNowNext = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }
        // Presenter mode's second screen: Info.plist names PTDeck.ExternalDisplaySceneDelegate, which nothing else
        // references, so mention the type here to keep the linker from dropping it.
        _ = ExternalDisplaySceneDelegate.self
        // Live news from promptugal.news only; registers the background refresh before launch finishes.
        PublicLive.start()
    }

    var body: some Scene {
        WindowGroup {
            PublicShell()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { PublicLive.foreground() }
            if phase == .background { SyncBackground.schedule() }
        }
    }
}


/// The agenda built into the app (`agenda-seed.json`, a copy of promptugal.news/api/v1/live/agenda.json), read
/// when nothing is cached yet so a first launch with no network still shows the programme.
enum AgendaSeed {
    private struct Seed: Decodable { let items: [Event] }

    static func events(bundle: Bundle = .main) -> [Event] {
        guard let url = bundle.url(forResource: "agenda-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(Seed.self, from: data) else { return [] }
        return seed.items.sorted(by: Event.earlier)
    }
}
