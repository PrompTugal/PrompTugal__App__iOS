import Foundation

/// The vault, as collaboration features need it. `VaultSession` (night/vault) is wrapped in this once it is on dev;
/// until then the features say "open your vault" and keep working without it.
@MainActor
protocol CollabVaultAccess: AnyObject {
    /// A vault is open on this device.
    var isOpen: Bool { get }
    /// The open reader vault was opened with a vault key (not a read key), so it can be written.
    var canWrite: Bool { get }
    /// A file of the reader vault, or nil when there is no such file.
    func read(_ path: String) async throws -> Data?
    /// Write one file to the reader vault (read-modify-write on the branch the website reads).
    func write(_ path: String, _ data: Data, _ message: String) async throws
    /// Open a teammate's vault with the read key they shared (`sgit_private_read_…:<vault_id>` or a `#key=` link).
    /// Stored behind Face ID like any key. Returns the vault id.
    func openShared(readKey: String, label: String) async throws -> String
    /// A file of another open vault.
    func read(_ path: String, vaultId: String) async throws -> Data?
    /// My picks merged into the vault's copy (`apps/agenda/picks.json`, nr.schedule.v1). Returns the merged document.
    func savePicks(_ document: Data) async throws -> Data
    /// Commit one note file to my newsroom notes lane: the vault of my own whose read key the newsroom holds
    /// (newsroom.sgit.ai "the feedback loop"; its vault key is in my master vault's `lane.json`).
    func writeNewsroomNote(_ path: String, _ data: Data) async throws
    /// Paths of the files under `folder` in a vault (mine when `vaultId` is nil).
    func files(in folder: String, vaultId: String?) async throws -> [String]
    /// A new file in `folder` of my vault, never overwriting (vault session's `append`). Returns its path.
    func append(_ data: Data, to folder: String, message: String) async throws -> String
    /// A file of my master vault (e.g. `inbox.json`, the inbox record the website made), or nil.
    func readMaster(_ path: String) async throws -> Data?
}

/// Seams to other sessions' code, so `AI/`, `Lanes/` and `Coordination/` compile on their own and pick up the
/// real stores when those land on dev. Each has a default that works tonight from what is on dev.
@MainActor
enum CollabHooks {
    enum HookError: Error, LocalizedError {
        case noVault, noWritableVault, noNotesLane
        var errorDescription: String? {
            switch self {
            case .noNotesLane: "Your account has no newsroom notes lane yet. The website makes it the first time you send to the newsroom."
            case .noVault: "Open your vault first (Vault in the sidebar)."
            case .noWritableVault: "Writing needs your vault opened with its vault key (or passkey), not a read key."
            }
        }
    }

    /// The vault session (`VaultSession.shared`, through `VaultCollabAccess`). Tests may set nil or a fake.
    static var vault: (any CollabVaultAccess)? = VaultCollabAccess()

    /// My picks as bare slugs (nr.schedule.v1), from the team session's `ScheduleStore` (which also takes in the
    /// reader's saved sessions and the website's picks).
    static var myPickIds: @MainActor () -> [String] = { TeamFeatures.shared.schedule.picks.map { PickId.normalise($0.id) } }

    /// The summit agenda. Default: the reader's cache on this device, then the network (logged).
    static var agenda: @MainActor () async -> [Event] = {
        let loaded = TeamFeatures.shared.planner.agenda
        if !loaded.isEmpty { return loaded }
        let cached = ReaderFiles.cachedAgenda()
        if !cached.isEmpty { return cached }
        return (try? await FeedClient.agenda()) ?? []
    }

    /// Who I am on the team (web-summit.sgit.ai `ws.me`). Default: the team session's saved identity.
    static var me: @MainActor () -> CollabIdentity? = { CollabIdentity.saved() }

    /// The day plan as text, from the team session's planner (`PlannerStore`). Nil: no planner.
    static var dayPlan: (@MainActor () async -> String?)? = { CollabTeamGlue.planText(TeamFeatures.shared.planner.plan) }

    /// The page on screen, for "current page" context. Screens that show a page call `noteCurrentPage`.
    private(set) static var currentPage: PageContext?

    static func noteCurrentPage(title: String, url: URL?, text: String? = nil) {
        currentPage = PageContext(title: title, url: url, text: text.map { String($0.prefix(6_000)) }, at: .now)
    }

    static func clearCurrentPage() { currentPage = nil }
}

struct PageContext: Equatable, Sendable {
    let title: String
    let url: URL?
    let text: String?
    let at: Date
}

/// The person chosen in "Who are you?" (team session's `TeamIdentityStore`, UserDefaults `team.identity.v1`).
struct CollabIdentity: Codable, Equatable, Sendable {
    let id: String
    let name: String
    var colour: String?

    static let defaultsKey = "team.identity.v1"

    /// The design session's dashboards keep a bare person id under this key.
    static let shellKey = "team.me"

    static func saved(_ defaults: UserDefaults = .standard) -> CollabIdentity? {
        if let identity = defaults.data(forKey: defaultsKey).flatMap({ try? JSONDecoder().decode(CollabIdentity.self, from: $0) }) {
            return identity
        }
        guard let id = defaults.string(forKey: shellKey)?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        return CollabIdentity(id: id, name: id.prefix(1).uppercased() + id.dropFirst(), colour: nil)
    }
}

/// Reads the reader's files on this device (written by `ReaderStore`), without touching its state.
enum ReaderFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
    }

    private struct Cache: Decodable { var agenda: [Event] = [] }

    static func cachedAgenda(in directory: URL = ReaderFiles.directory) -> [Event] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("content.json")),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return [] }
        return cache.agenda
    }

    static func savedEventIds(in directory: URL = ReaderFiles.directory) -> [String] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("saved.json")),
              let saved = try? JSONDecoder().decode([String: Event].self, from: data) else { return [] }
        return saved.keys.map(PickId.normalise).sorted()
    }
}

/// Pick ids are the bare event slug (contracts §3, changed 03:45 UTC): the website takes it from
/// `events/<slug>/index.html`. Older forms (`events/<slug>`, the page path) are read and turned into the slug.
enum PickId {
    static func normalise(_ raw: String) -> String {
        var id = raw.trimmingCharacters(in: .whitespaces)
        if id.hasPrefix("/") { id.removeFirst() }
        for suffix in ["/index.html", "/"] where id.hasSuffix(suffix) {
            id.removeLast(suffix.count)
        }
        if let range = id.range(of: "events/", options: .backwards) { id = String(id[range.upperBound...]) }
        return id
    }

    static func of(_ event: Event) -> String { normalise(event.page) }

    /// The ids in an nr.schedule.v1 document. Unknown shapes give an empty list.
    static func ids(inScheduleDocument data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let picks = object["picks"] as? [[String: Any]] else { return [] }
        return picks.compactMap { $0["id"] as? String }.map(normalise)
    }

    /// `{"v":1,"picks":[{"id":…,"at":…}]}` for the ids given, with `at` as an ISO 8601 string.
    static func scheduleDocument(ids: [String], at date: Date = .now) throws -> Data {
        let at = ISO8601DateFormatter.collabJS.string(from: date)
        let picks = ids.map { ["id": normalise($0), "at": at] }
        return try JSONSerialization.data(withJSONObject: ["v": 1, "picks": picks], options: [.sortedKeys])
    }
}

extension ISO8601DateFormatter {
    /// `2026-11-08T02:45:00.000Z`, as JavaScript's `toISOString()` writes.
    static var collabJS: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
