import SwiftUI
import PTCore
import PTAgenda
import PTDeck
import PTVaultUI
import PTWeb

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
        // The public list of websites (PrompTugal.news only, no team site), before any view reads it.
        WebsiteSources.resource = "WebsitesPublic"
        // The one schedule (AgendaHub.schedule) and agendaDidLoad are set by PublicFeatures (Shell/, design), when the
        // first screen appears. Here only the widgets' "Now and next" publisher, which PublicFeatures does not set.
        AgendaHub.publishNowNext = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }
        // Presenter mode's second screen: Info.plist names PTDeck.ExternalDisplaySceneDelegate, which nothing else
        // references, so mention the type here to keep the linker from dropping it.
        _ = ExternalDisplaySceneDelegate.self
        #if DEBUG
        // The vault is hidden in the public Release build, so its background refresh exists only in DEBUG.
        // Background tasks must be registered before the app finishes launching.
        VaultBackground.register(taskIdentifier: "news.promptugal.reader.vault-refresh")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            PublicShell()
        }
        #if DEBUG
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { VaultBackground.schedule() }
        }
        #endif
    }
}
