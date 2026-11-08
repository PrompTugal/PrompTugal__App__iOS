import Foundation
import Observation
import SGitVault
#if canImport(UIKit)
import UIKit
#endif

/// The vaults open on this device, for the UI and the debug panel.
///
///     let session = VaultSession.shared
///     try await session.importKey(pastedText)          // paste or QR: stored behind Face ID, opened, pulled
///     try await session.unlockStoredKeys()             // Face ID once, every stored key opened
///     try await session.unlockWithPasskey()            // passkey PRF → door → master → reader (flagged)
///     let text = try await session.readText("apps/schedule.json")   // from the reader vault
///
/// Keys live in `VaultKeychain`; this object holds open `SGitVault` readers in memory only, and drops them on `lock()`.
@MainActor @Observable
public final class VaultSession {
    public static let shared = VaultSession()

    public struct OpenVault: Identifiable {
        public enum State: Equatable, Sendable { case idle, pulling, ready, failed(String) }
        public var id: String { vaultId }
        public let vaultId: String
        public let label: String
        public let role: String
        public let kind: VaultKey.Kind
        public let canWrite: Bool
        let vault: SGitVault
        var state: State = .idle
        /// Set when the head was refused because a key this device does not trust signed it.
        var untrustedSigner: String?
        var head: VaultCommit?
        var fileCount = 0
        var lastPull: Date?
    }

    /// One row of the debug panel's key inventory. Never a key value.
    public struct KeyInventoryItem: Identifiable, Hashable {
        public var id: String { "\(store)/\(name)" }
        public let name: String
        public let store: String          // "Keychain", "Secure Enclave", "memory"
        public let protection: String
        public let detail: String
    }

    public let log = VaultTrafficLog()
    public private(set) var vaults: [OpenVault] = []
    private(set) var isUnlocking = false
    private(set) var lastError: String?
    /// Set when an account was opened by passkey: which vault is the reader vault.
    public private(set) var readerVaultId: String?

    private let keychain = VaultKeychain.shared
    /// Access token for writes (from the master vault's `.vault/access-token.json`, or entered). Memory only.
    private var accessToken: String?
    public var canPush: Bool { accessToken != nil }

    public init() {
        #if canImport(UIKit)
        // Pull when the app comes to the foreground; end the Face ID reuse window when it leaves.
        // Observed here so the app needs no scene-phase code for the vault.
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sceneBecameActive() }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sceneMovedToBackground() }
        }
        #endif
    }

    public var isLocked: Bool { vaults.isEmpty }
    var hasStoredKeys: Bool { !keychain.inventory().isEmpty }

    /// Roles. "Mine" is the person's own vault; a teammate's or pasted vault is never treated as theirs (S5).
    enum Role: Sendable {
        static let reader = "reader"        // the person's own vault, from the passkey account
        static let master = "master"        // the person's master vault
        static let mine = "mine"            // a key the person imported and marked as their own
        static let teammate = "teammate"    // a teammate's or shared vault, read only for "my" purposes
        static func isMine(_ role: String) -> Bool { role == reader || role == mine }
    }

    /// The vault the person explicitly chose as theirs (persisted), if any.
    private(set) var chosenVaultId: String? = UserDefaults.standard.string(forKey: "vault.myVault")

    /// "My vault": the person's explicit choice, else their reader vault, else a vault they marked as theirs,
    /// else their master. Never just the first vault open: a teammate's vault must not become "mine" (S5).
    public var reader: OpenVault? {
        let id = Self.myVaultId(among: vaults.map { (id: $0.vaultId, role: $0.role) }, chosen: chosenVaultId, account: readerVaultId)
        return id.flatMap { id in vaults.first { $0.vaultId == id } }
    }

    /// The rule for "my vault", as a pure function (tested): the explicit choice, then the passkey account's
    /// reader vault, then a vault marked as mine, then the master. A teammate's vault never qualifies.
    nonisolated static func myVaultId(among vaults: [(id: String, role: String)], chosen: String?, account: String?) -> String? {
        if let chosen, vaults.contains(where: { $0.id == chosen }) { return chosen }
        if let account, vaults.contains(where: { $0.id == account }) { return account }
        return vaults.first { Role.isMine($0.role) }?.id ?? vaults.first { $0.role == Role.master }?.id
    }

    /// How the stored keys are really protected, in words (S3).
    var protectionSummary: String { keychain.protectionSummary() }

    /// Make an open vault "my vault" (an explicit choice), or clear the choice.
    public func chooseMyVault(_ vaultId: String?) {
        chosenVaultId = vaultId
        UserDefaults.standard.set(vaultId, forKey: "vault.myVault")
    }

    // MARK: Opening

    /// A reader that requires a verified signature from a trusted key on every new head (S1).
    func makeReader(for key: VaultKey) -> SGitVault {
        SGitVault(key: key, server: VaultConfig.server, cache: VaultConfig.cacheDirectory, log: log,
                  requireSignatures: true, trust: VaultTrustStore.trust(for: key.vaultId))
    }

    /// Paste or QR text → key (PBKDF2 off the main actor for vault keys) → Keychain → open → pull.
    /// `mine`: the person says this is their own vault. Otherwise it is a teammate's (S5).
    @discardableResult
    public func importKey(_ raw: String, label: String = "Teammate vault", mine: Bool = false) async throws -> OpenVault {
        let key = try await SGitVault.deriveKey(from: VaultUnlock.keyText(fromScanned: raw), log: log)
        let role = mine ? Role.mine : Role.teammate
        try keychain.save(key, label: label, role: role)
        let opened = try await open(key, label: label, role: role)
        if mine { chooseMyVault(key.vaultId) }
        return opened
    }

    /// The person approves a signer this device did not trust yet (shown after `untrustedSigner`).
    func trustSigner(_ keyId: String, in vaultId: String) async {
        guard let entry = vaults.first(where: { $0.vaultId == vaultId }) else { return }
        await entry.vault.pin(keyId)
        VaultTrustStore.save(await entry.vault.trust, for: vaultId)
        await pull(vaultId)
    }

    /// Short text for people (Q7). The full detail goes to the vault traffic log, never to the screen.
    public func userMessage(for error: Error, context: String = "") -> String {
        let detail = String(describing: error)
        log.record(VaultTrafficEvent(kind: .error, path: context.isEmpty ? "app" : context, detail: detail))
        if let vaultError = error as? VaultError { return vaultError.localizedDescription }
        if let localized = error as? LocalizedError, let text = localized.errorDescription { return text }
        if error is URLError { return String(localized: "The vault server could not be reached. Check the connection and try again.", bundle: .module) }
        return String(localized: "Something went wrong. The details are in Debug → Vault traffic.", bundle: .module)
    }

    /// One Face ID, then every stored key opened and pulled.
    func unlockStoredKeys(reason: String = String(localized: "Open your vaults", bundle: .module)) async throws {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            let context = try await keychain.unlock(reason: reason)
            for (key, meta) in try keychain.loadAll(context: context) where !vaults.contains(where: { $0.vaultId == key.vaultId }) {
                if meta.role == Role.reader { readerVaultId = key.vaultId }
                try await open(key, label: meta.label, role: meta.role)
            }
            lastError = nil
        } catch {
            lastError = userMessage(for: error, context: "unlock")
            throw error
        }
    }

    /// Passkey PRF → door → master → reader, as on promptugal.news. Stores the master and reader keys behind Face ID.
    func unlockWithPasskey() async throws {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            var prf = try await PasskeyPRF().prfBytes()
            defer { prf.resetBytes(in: 0..<prf.count) }
            try await openAccount(secret: prf)
        } catch {
            lastError = userMessage(for: error, context: "passkey")
            throw error
        }
    }

    /// The website's recovery code, in place of the passkey.
    func unlockWithRecoveryCode(_ code: String) async throws {
        guard var bytes = VaultDoor.recoveryBytes(code) else {
            throw VaultError.invalidKey("a recovery code is 26 letters and digits")
        }
        defer { bytes.resetBytes(in: 0..<bytes.count) }
        try await openAccount(secret: bytes)
    }

    private func openAccount(secret: Data) async throws {
        let log = self.log
        let trusts = Dictionary(uniqueKeysWithValues: keychain.inventory().map { ($0.vaultId, VaultTrustStore.trust(for: $0.vaultId)) })
        let keys = try await VaultAccount.unlock(secret: secret, log: log) { key in
            SGitVault(key: key, server: VaultConfig.server, cache: VaultConfig.cacheDirectory, log: log,
                      requireSignatures: true, trust: trusts[key.vaultId] ?? VaultTrust())
        }
        accessToken = keys.accessToken ?? accessToken
        try keychain.save(keys.master, label: "Master vault", role: Role.master)
        try await open(keys.master, label: "Master vault", role: Role.master)
        if let reader = keys.reader {
            try keychain.save(reader, label: "Your vault", role: Role.reader)
            readerVaultId = reader.vaultId
            try await open(reader, label: "Your vault", role: Role.reader)
        }
    }

    @discardableResult
    private func open(_ key: VaultKey, label: String, role: String) async throws -> OpenVault {
        vaults.removeAll { $0.vaultId == key.vaultId }
        let entry = OpenVault(vaultId: key.vaultId, label: label, role: role, kind: key.kind,
                              canWrite: key.canWrite, vault: makeReader(for: key))
        vaults.append(entry)
        await pull(entry.vaultId)
        return vaults.first { $0.vaultId == key.vaultId } ?? entry
    }

    // MARK: Sync

    func pull(_ vaultId: String) async {
        guard let index = vaults.firstIndex(where: { $0.vaultId == vaultId }) else { return }
        vaults[index].state = .pulling
        let vault = vaults[index].vault
        do {
            let head = try await vault.pull()
            let count = try await vault.files().count
            VaultTrustStore.save(await vault.trust, for: vaultId)          // first use pins the signers seen now
            guard let i = vaults.firstIndex(where: { $0.vaultId == vaultId }) else { return }
            vaults[i].head = head
            vaults[i].fileCount = count
            vaults[i].lastPull = Date()
            vaults[i].untrustedSigner = nil
            vaults[i].state = .ready
        } catch {
            let message = userMessage(for: error, context: "pull \(vaultId)")
            guard let i = vaults.firstIndex(where: { $0.vaultId == vaultId }) else { return }
            if case VaultError.untrustedSigner(_, let keyId) = error { vaults[i].untrustedSigner = keyId }
            vaults[i].state = .failed(message)
        }
    }

    func pullAll() async {
        for id in vaults.map(\.vaultId) { await pull(id) }
    }

    /// Call when the scene becomes active (`scenePhase == .active`).
    func sceneBecameActive() {
        guard !vaults.isEmpty else { return }
        Task { await pullAll() }
    }

    /// Call when the scene goes to the background: the Face ID reuse window ends.
    func sceneMovedToBackground() {
        keychain.invalidate()
    }

    /// For `BGAppRefreshTask` (the identifier each app passes to `VaultBackground.register(taskIdentifier:)`): pulls the vaults already open
    /// in memory. Returns false when there is nothing open (keys stay behind Face ID; nothing is unlocked here).
    func backgroundRefresh() async -> Bool {
        guard !vaults.isEmpty else { return false }
        await pullAll()
        return vaults.allSatisfy { $0.state == .ready }
    }

    func lock() {
        accessToken = nil
        vaults.removeAll()
        readerVaultId = nil
        keychain.invalidate()
    }

    /// Remove every key from this device (the vaults themselves are untouched on the server).
    func forgetAllKeys() {
        lock()
        keychain.deleteAll()
        VaultDeviceSigner.delete()
    }

    // MARK: Reading

    public func readText(_ path: String, vaultId: String? = nil) async throws -> String {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId ?? "")
        }
        return try await entry.vault.readText(path)
    }

    // MARK: Writing

    /// Set the access token writes need (x-sgraph-access-token). Kept in memory only.
    func setAccessToken(_ token: String?) { accessToken = token?.isEmpty == false ? token : nil }

    /// This device's branch: `device-` and 8 characters that stay the same for this app on this device.
    var deviceBranch: String {
        let key = "vault.deviceBranch"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let made = "device-" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)
        UserDefaults.standard.set(made, forKey: key)
        return made
    }

    /// Commit `changes` to this device's branch of a vault opened with a vault key, signed in the Secure Enclave.
    /// Face ID once: it unlocks the write key and signs.
    @discardableResult
    func commit(_ changes: [String: Data?], message: String, vaultId: String? = nil) async throws -> VaultPushResult {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId ?? "")
        }
        guard entry.canWrite else { throw VaultError.invalidKey("this vault was opened with a read key; writing needs its vault key") }
        let context = try await keychain.unlock(reason: "Sign and save to your vault")
        let key = try keychain.load(vaultId: entry.vaultId, context: context)
        guard let writeKey = key.writeKey else { throw VaultError.invalidKey("no write key stored") }
        let signer = try VaultDeviceSigner.load(context: context)
        await entry.vault.pin(signer.keyId)                          // this device's own commits are trusted
        VaultTrustStore.save(await entry.vault.trust, for: entry.vaultId)
        let result = try await entry.vault.commit(changes, message: message, branch: deviceBranch, signer: signer,
                                                  writeKey: writeKey, accessToken: accessToken,
                                                  writer: HTTPVaultTransport(server: VaultConfig.server))
        await pull(entry.vaultId)
        return result
    }

    // MARK: Files other features keep in the vault

    /// A file of the reader vault (or `vaultId`), or nil when the vault has no such file.
    public func readFile(_ path: String, vaultId: String? = nil) async throws -> Data? {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else { return nil }
        do { return try await entry.vault.read(path) } catch VaultError.fileNotFound { return nil }
    }

    /// Read-modify-write one file on a branch (default "current", which the website reads), retrying
    /// when another device moved the branch first. `transform` gets the latest content (nil if none)
    /// and returns the new content (nil = no change). Returns nil when nothing needed writing.
    @discardableResult
    public func update(_ path: String, vaultId: String? = nil, branch: String = "current", message: String,
                transform: @escaping (Data?) throws -> Data?) async throws -> VaultPushResult? {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId ?? "")
        }
        guard entry.canWrite else { throw VaultError.invalidKey("this vault was opened with a read key; writing needs its vault key") }
        let context = try await keychain.unlock(reason: "Save to your vault")
        let key = try keychain.load(vaultId: entry.vaultId, context: context)
        guard let writeKey = key.writeKey else { throw VaultError.invalidKey("no write key stored") }
        let signer = try VaultDeviceSigner.load(context: context)
        await entry.vault.pin(signer.keyId)                          // this device's own commits are trusted
        VaultTrustStore.save(await entry.vault.trust, for: entry.vaultId)
        for attempt in 1...3 {
            await entry.vault.switchBranch(branch)
            try await entry.vault.pull()
            let current: Data?
            do { current = try await entry.vault.read(path) } catch VaultError.fileNotFound { current = nil }
            guard let next = try transform(current), next != current else { return nil }
            do {
                let result = try await entry.vault.commit([path: next], message: message, branch: branch, signer: signer,
                                                          writeKey: writeKey, accessToken: accessToken,
                                                          writer: HTTPVaultTransport(server: VaultConfig.server))
                await pull(entry.vaultId)
                return result
            } catch VaultError.pushConflict where attempt < 3 {
                continue                                   // someone else moved the branch: read again, merge again
            }
        }
        return nil
    }

    // MARK: Append lanes (for collab)

    /// The files under `folder` (e.g. "lanes/to-newsroom") in a vault, newest name last.
    public func files(in folder: String, vaultId: String? = nil) async throws -> [VaultFile] {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else { return [] }
        let prefix = folder.hasSuffix("/") ? folder : folder + "/"
        return try await entry.vault.files().filter { $0.path.hasPrefix(prefix) }
    }

    /// Add one new file to `folder` and push it to `branch`. The name is unique
    /// (`<UTC time>-<device branch>-<4 hex>.json` unless given), so appends from several
    /// devices never conflict; a lost race on the ref only retries. Returns the path written.
    @discardableResult
    public func append(_ data: Data, to folder: String, name: String? = nil, vaultId: String? = nil,
                branch: String = "current", message: String? = nil) async throws -> String {
        let unique = name ?? VaultLanes.fileName(device: deviceBranch)
        let trimmed = folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        let path = VaultLanes.path(folder: trimmed, name: unique)
        try await update(path, vaultId: vaultId, branch: branch, message: message ?? "Append to \(trimmed)") { current in
            current == nil ? data : nil                    // never overwrite: an existing name is left alone
        }
        return path
    }

    // MARK: Schedule picks (the website's `agenda/picks`, nr.schedule.v1)

    /// Where the website keeps picks in the reader vault: `__vault.save('agenda/picks', …)` writes
    /// `apps/agenda/picks.json` (promptugal.news assets/schedule/schedule.js and assets/vault/boot.js).
    static let picksPath = VaultPicks.path

    /// The vault's picks document (nr.schedule.v1 JSON), or nil. Team's ScheduleStore decodes and merges it.
    public func loadPicks() async throws -> Data? { try await readFile(Self.picksPath) }

    /// Merge local picks into the vault's copy (the website's rule: union by `id`, the vault's entry kept when
    /// both have it) and save. Returns the merged document, for `ScheduleStore.merge`.
    @discardableResult
    public func savePicks(_ local: Data) async throws -> Data {
        var merged = local
        try await update(Self.picksPath, message: "Picks from the app") { current in
            merged = try Self.unionPicks(vault: current, local: local)
            return merged
        }
        return merged
    }

    /// Union by id, the vault's entry kept (`VaultPicks.union`, tested in the SGitVault package).
    nonisolated static func unionPicks(vault: Data?, local: Data) throws -> Data {
        try VaultPicks.union(vault: vault, local: local)
    }

    // MARK: Debug panel feeds

    /// The vault inspector for one open vault: branches, head, history with messages, tree with sizes, cache stats.
    func inspect(_ vaultId: String, historyLimit: Int = 30) async throws -> VaultInspection {
        guard let entry = vaults.first(where: { $0.vaultId == vaultId }) else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId)
        }
        return try await entry.vault.inspect(historyLimit: historyLimit)
    }

    /// Which keys exist and where. Never values.
    public var keyInventory: [KeyInventoryItem] {
        var items = keychain.inventory().map { meta in
            KeyInventoryItem(name: "\(meta.label) · vault \(meta.vaultId)", store: "Keychain",
                             protection: meta.protection.rawValue,
                             detail: "\(meta.kind.rawValue) key, \(meta.role), stored \(meta.createdAt.formatted(date: .abbreviated, time: .shortened))\(meta.wrapped ? ", wrapped by the Secure Enclave key" : "")")
        }
        if let signer = VaultDeviceSigner.inventory() {
            items.append(KeyInventoryItem(name: "Commit signing key (P-256) · \(signer.keyId)",
                                          store: signer.secureEnclave ? "Secure Enclave" : "Keychain (software key)",
                                          protection: signer.secureEnclave ? "Face ID, this device only" : "this device only",
                                          detail: "signs commits on \(deviceBranch)"))
        }
        if accessToken != nil {
            items.append(KeyInventoryItem(name: "Vault access token", store: "memory",
                                          protection: "dropped on lock", detail: "allows pushes"))
        }
        if VaultKeyWrap.isAvailable {
            items.append(KeyInventoryItem(name: "Vault wrapping key (P-256)", store: "Secure Enclave",
                                          protection: "Face ID (current enrolment), this device only",
                                          detail: VaultKeyWrap.shared.exists ? "exists; never leaves the chip" : "not made yet"))
        }
        for entry in vaults {
            items.append(KeyInventoryItem(name: "Open reader · vault \(entry.vaultId)", store: "memory",
                                          protection: "dropped on lock",
                                          detail: "\(entry.kind.rawValue)\(entry.canWrite ? ", can write" : ", read only")"))
        }
        return items
    }

    /// Ciphertext cache totals across every vault on disk.
    func cacheStats() async -> [String: VaultCacheStats] {
        var out: [String: VaultCacheStats] = [:]
        for entry in vaults { out[entry.vaultId] = await entry.vault.cacheStats() }
        return out
    }
}
