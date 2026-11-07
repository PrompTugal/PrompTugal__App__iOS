import Foundation
import Observation
import SGitVault

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
        vaults.removeAll()
        readerVaultId = nil
        keychain.invalidate()
    }

    /// Remove every key from this device (the vaults themselves are untouched on the server).
    func forgetAllKeys() {
        lock()
        keychain.deleteAll()
    }

    // MARK: Reading

    func readText(_ path: String, vaultId: String? = nil) async throws -> String {
        guard let entry = vaultId.flatMap({ id in vaults.first { $0.vaultId == id } }) ?? reader else {
            throw VaultError.vaultNotFoundOrWrongKey(vaultId: vaultId ?? "")
        }
        return try await entry.vault.readText(path)
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
