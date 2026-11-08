import Foundation

// Shared seams for collaboration features (PTAsk, PTLanes, the Team app). Protocols, value types and one
// formatter only: no vault types, no team types. The vault conformance (`VaultCollabAccess`) lives in PTVaultUI.

/// The vault, as collaboration features need it. Plain types only.
@MainActor
public protocol CollabVaultAccess: AnyObject {
    /// A vault is open on this device.
    var isOpen: Bool { get }
    /// My own vault (the account's reader vault), never a vault imported from someone else's key. Nil when
    /// none is open. Everything "mine" (my key copy, my plan, my notes) reads and writes only this vault (S5).
    var ownVaultId: String? { get }
    /// My own vault was opened with a vault key (not a read key), so it can be written.
    var canWrite: Bool { get }
    /// A file of my own vault, or nil when there is no such file. Throws when my own vault is not open.
    func read(_ path: String) async throws -> Data?
    /// Write one file to my own vault (read-modify-write on the branch the website reads).
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

/// Seams to the running app. Defaults are team-free: the vault is nil until the app (or PTVaultUI) installs it.
@MainActor
public enum CollabHooks {
    public enum HookError: Error, LocalizedError {
        case noVault, noWritableVault, noNotesLane, noOwnVault
        public var errorDescription: String? {
            switch self {
            case .noOwnVault: "Open your own vault first. A teammate's vault is never used as yours."
            case .noNotesLane: "Your account has no newsroom notes lane yet. The website makes it the first time you send to the newsroom."
            case .noVault: "Open your vault first (Vault in the sidebar)."
            case .noWritableVault: "Writing needs your vault opened with its vault key (or passkey), not a read key."
            }
        }
    }

    /// The vault session, through `CollabVaultAccess`. Installed by the app. Tests may set nil or a fake.
    public static var vault: (any CollabVaultAccess)?

    /// Who I am on the team. Default: the saved identity. The public app has none.
    public static var me: @MainActor () -> CollabIdentity? = { CollabIdentity.saved() }

    /// The page on screen, for "current page" context. Screens that show a page call `noteCurrentPage`.
    public private(set) static var currentPage: PageContext?

    public static func noteCurrentPage(title: String, url: URL?, text: String? = nil) {
        currentPage = PageContext(title: title, url: url, text: text.map { String($0.prefix(6_000)) }, at: .now)
    }

    public static func clearCurrentPage() { currentPage = nil }
}

public struct PageContext: Equatable, Sendable {
    public let title: String
    public let url: URL?
    public let text: String?
    public let at: Date

    public init(title: String, url: URL?, text: String?, at: Date) {
        self.title = title; self.url = url; self.text = text; self.at = at
    }
}

/// The person chosen in "Who are you?" (team session's `TeamIdentityStore`, UserDefaults `team.identity.v1`).
public struct CollabIdentity: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public var colour: String?

    public init(id: String, name: String, colour: String? = nil) { self.id = id; self.name = name; self.colour = colour }

    public static let defaultsKey = "team.identity.v1"

    /// The design session's dashboards keep a bare person id under this key.
    public static let shellKey = "team.me"

    public static func saved(_ defaults: UserDefaults = .standard) -> CollabIdentity? {
        if let identity = defaults.data(forKey: defaultsKey).flatMap({ try? JSONDecoder().decode(CollabIdentity.self, from: $0) }) {
            return identity
        }
        guard let id = defaults.string(forKey: shellKey)?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
        return CollabIdentity(id: id, name: id.prefix(1).uppercased() + id.dropFirst(), colour: nil)
    }
}

public extension ISO8601DateFormatter {
    /// `2026-11-08T02:45:00.000Z`, as JavaScript's `toISOString()` writes.
    static var collabJS: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}


/// Short, readable error text for people (Q7): no "Error Domain=…", no object paths, no codes they cannot use.
public enum CollabErrorText {
    public static func short(_ error: Error) -> String {
        if error is CancellationError { return "Cancelled." }
        if let url = error as? URLError {
            switch url.code {
            case .cancelled: return "Cancelled."
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No internet connection. Try again when you are online."
            case .timedOut: return "The server took too long to answer. Try again."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Can't reach the server. Try again later."
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate:
                return "The secure connection failed."
            case .badServerResponse, .cannotParseResponse, .zeroByteResource:
                return "The server sent an answer the app could not read."
            default: return "The network request failed. Try again."
            }
        }
        if let described = (error as? LocalizedError)?.errorDescription, readable(described) {
            return described
        }
        let text = (error as NSError).localizedDescription
        return readable(text) ? text : "Something went wrong. Try again."
    }

    /// True for text a person can read: not a raw NSError dump, an object path or a very long string.
    public static func readable(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 200
            && !text.contains("Error Domain=") && !text.contains("NSLocalizedDescription")
            && !text.contains("bare/") && !text.contains("obj-cas-") && !text.contains("(null)")
    }
}
