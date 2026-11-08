import Foundation
import PTCore
import PTSync

/// The public app's synced files: promptugal.news' manifest, kept on this device and checked against its SHA-256 hashes.
/// The core pack (agenda, days, stories, indexes, about 1.5 MB) comes first; the full pack (graph, search, entity pages)
/// follows when the connection is not cellular or in Low Data Mode. Nothing here is a screen: readers take the files
/// through PTCore's `ContentSources` (site id `promptugal.news`), and fall back to the network when it holds nothing.
@MainActor
enum PublicSync {
    /// Also listed in Info.plist under BGTaskSchedulerPermittedIdentifiers.
    static let taskIdentifier = "news.promptugal.reader.sync"

    private(set) static var store: ContentStore?
    private(set) static var engine: SyncEngine?
    private static let network = SystemNetworkPath()

    /// Called once from the app's `init`, before any view reads content. Opens the store off the main thread, registers it,
    /// then runs a first sync.
    static func start() {
        SyncBackground.register(taskIdentifier: taskIdentifier) { await PublicSync.refresh() }
        Task {
            // A folder named "Seed" in the app bundle holds the build's seed: Seed/promptugal.news/manifest.json and files.
            let seed = Bundle.main.url(forResource: "Seed", withExtension: nil)?
                .appendingPathComponent(SyncSource.promptugalNews.id, isDirectory: true)
            let opened = await ContentStore.open(source: .promptugalNews, seed: seed)
            store = opened
            ContentSources.register(opened, for: SyncSource.promptugalNews.id)
            engine = SyncEngine(store: opened, rules: .promptugalNews, network: network)
            _ = await refresh()
        }
    }

    /// One sync. Core always; full when the connection allows (the engine leaves it out otherwise). True when nothing failed.
    @discardableResult
    static func refresh(packs: Set<SyncPack> = [.core, .full]) async -> Bool {
        guard let engine else { return false }
        do {
            return try await engine.sync(packs).failures.isEmpty
        } catch {
            return false
        }
    }
}
