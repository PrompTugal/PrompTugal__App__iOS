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
final class VaultSession {
    static let shared = VaultSession()

    struct OpenVault: Identifiable {
        enum State: Equatable { case idle, pulling, ready, failed(String) }
        var id: String { vaultId }
        let vaultId: String
        let label: String
        let role: String
        let kind: VaultKey.Kind
        let canWrite: Bool
        let vault: SGitVault
        var state: State = .idle
        var head: VaultCommit?
        var fileCount = 0
        var lastPull: Date?
    }

    /// One row of the debug panel's key inventory. Never a key value.
    struct KeyInventoryItem: Identifiable, Hashable {
        var id: String { "\(store)/\(name)" }
        let name: String
        let store: String          // "Keychain", "Secure Enclave", "memory"
        let protection: String
        let detail: String
    }

    let log = VaultTrafficLog()
    private(set) var vaults: [OpenVault] = []
    private(set) var isUnlocking = false
    private(set) var lastError: String?
    /// Set when an account was opened by passkey: which vault is the reader vault.
    private(set) var readerVaultId: String?

    private let keychain = VaultKeychain.shared
    /// Access token for writes (from the master vault's `.vault/access-token.json`, or entered). Memory only.
    private var accessToken: String?
    var canPush: Bool { accessToken != nil }

    init() {
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

    var isLocked: Bool { vaults.isEmpty }
    var hasStoredKeys: Bool { !keychain.inventory().isEmpty }
    var reader: OpenVault? {
        vaults.first { $0.vaultId == readerVaultId } ?? vaults.first { $0.role == "reader" } ?? vaults.first
    }

    // MARK: Opening

    func makeReader(for key: VaultKey) -> SGitVault {
        SGitVault(key: key, server: VaultConfig.server, cache: VaultConfig.cacheDirectory, log: log)
    }

    /// Paste or QR text → key (PBKDF2 off the main actor for vault keys) → Keychain → open → pull.
    @discardableResult
    func importKey(_ raw: String, label: String = "Imported key") async throws -> OpenVault {
        let key = try await SGitVault.deriveKey(from: VaultUnlock.keyText(fromScanned: raw), log: log)
        try keychain.save(key, label: label, role: "imported")
        return try await open(key, label: label, role: "imported")
    }

    /// One Face ID, then every stored key opened and pulled.
    func unlockStoredKeys(reason: String = "Open your vaults") async throws {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            let context = try await keychain.unlock(reason: reason)
            for (key, meta) in try keychain.loadAll(context: context) where !vaults.contains(where: { $0.vaultId == key.vaultId }) {
                if meta.role == "reader" { readerVaultId = key.vaultId }
                try await open(key, label: meta.label, role: meta.role)
            }
            lastError = nil
        } catch {
            lastError = String(describing: error)
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
            lastError = String(describing: error)
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
        let keys = try await VaultAccount.unlock(secret: secret, log: log) { key in
            SGitVault(key: key, server: VaultConfig.server, cache: VaultConfig.cacheDirectory, log: log)
        }
        accessToken = keys.accessToken ?? accessToken
        try keychain.save(keys.master, label: "Master vault", role: "master")
        try await open(keys.master, label: "Master vault", role: "master")
        if let reader = keys.reader {
            try keychain.save(reader, label: "Your vault", role: "reader")
            readerVaultId = reader.vaultId
            try await open(reader, label: "Your vault", role: "reader")
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
            guard let i = vaults.firstIndex(where: { $0.vaultId == vaultId }) else { return }
            vaults[i].head = head
            vaults[i].fileCount = count
            vaults[i].lastPull = Date()
            vaults[i].state = .ready
        } catch {
            guard let i = vaults.firstIndex(where: { $0.vaultId == vaultId }) else { return }
            vaults[i].state = .failed(String(describing: error))
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

    /// For `BGAppRefreshTask` (identifier `VaultConfig.backgroundRefreshTask`): pulls the vaults already open
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

    func readText(_ path: String, vaultId: String? = nil) async throws -> String {
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
        let result = try await entry.vault.commit(changes, message: message, branch: deviceBranch, signer: signer,
                                                  writeKey: writeKey, accessToken: accessToken,
                                                  writer: HTTPVaultTransport(server: VaultConfig.server))
        await pull(entry.vaultId)
        return result
    }

    // MARK: Files other features keep in the vault

    /// A file of the reader vault (or `vaultId`), or nil when the vault has no such file.
    func readFile(_ path: String, vaultId: String? = nil) async throws -> Data? {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else { return nil }
        do { return try await entry.vault.read(path) } catch VaultError.fileNotFound { return nil }
    }

    /// Read-modify-write one file on a branch (default "current", which the website reads), retrying
    /// when another device moved the branch first. `transform` gets the latest content (nil if none)
    /// and returns the new content (nil = no change). Returns nil when nothing needed writing.
    @discardableResult
    func update(_ path: String, vaultId: String? = nil, branch: String = "current", message: String,
                transform: @escaping (Data?) throws -> Data?) async throws -> VaultPushResult? {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId ?? "")
        }
        guard entry.canWrite else { throw VaultError.invalidKey("this vault was opened with a read key; writing needs its vault key") }
        let context = try await keychain.unlock(reason: "Save to your vault")
        let key = try keychain.load(vaultId: entry.vaultId, context: context)
        guard let writeKey = key.writeKey else { throw VaultError.invalidKey("no write key stored") }
        let signer = try VaultDeviceSigner.load(context: context)
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
    func files(in folder: String, vaultId: String? = nil) async throws -> [VaultFile] {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else { return [] }
        let prefix = folder.hasSuffix("/") ? folder : folder + "/"
        return try await entry.vault.files().filter { $0.path.hasPrefix(prefix) }
    }

    /// Add one new file to `folder` and push it to `branch`. The name is unique
    /// (`<UTC time>-<device branch>-<4 hex>.json` unless given), so appends from several
    /// devices never conflict; a lost race on the ref only retries. Returns the path written.
    @discardableResult
    func append(_ data: Data, to folder: String, name: String? = nil, vaultId: String? = nil,
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
    func loadPicks() async throws -> Data? { try await readFile(Self.picksPath) }

    /// Merge local picks into the vault's copy (the website's rule: union by `id`, the vault's entry kept when
    /// both have it) and save. Returns the merged document, for `ScheduleStore.merge`.
    @discardableResult
    func savePicks(_ local: Data) async throws -> Data {
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
    var keyInventory: [KeyInventoryItem] {
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
