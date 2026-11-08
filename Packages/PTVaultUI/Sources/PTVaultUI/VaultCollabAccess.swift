import Foundation
import PTCore
import SGitVault

/// `CollabVaultAccess` over the vault session (night/vault). Installed as `CollabHooks.vault`.
@MainActor
public final class VaultCollabAccess: CollabVaultAccess {
    let session: VaultSession

    /// Installs the vault session as the collaboration features' vault. Each app calls this once at launch.
    public static func install() { CollabHooks.vault = VaultCollabAccess() }

    public init(session: VaultSession = .shared) { self.session = session }

    public var isOpen: Bool { !session.isLocked }

    /// The account's own vault: the reader vault opened by passkey, recovery code or stored as "reader".
    /// An imported key (role "imported", e.g. a teammate's read key) is never mine.
    private var own: VaultSession.OpenVault? {
        session.vaults.first { $0.vaultId == session.readerVaultId } ?? session.vaults.first { $0.role == "reader" }
    }
    public var ownVaultId: String? { own?.vaultId }
    public var canWrite: Bool { own?.canWrite ?? false }

    private func ownId() throws -> String {
        guard let id = ownVaultId else { throw CollabHooks.HookError.noOwnVault }
        return id
    }

    public func read(_ path: String) async throws -> Data? { try await session.readFile(path, vaultId: ownId()) }

    public func write(_ path: String, _ data: Data, _ message: String) async throws {
        try await session.update(path, vaultId: ownId(), message: message) { _ in data }
    }

    public func openShared(readKey: String, label: String) async throws -> String {
        try await session.importKey(readKey, label: label).vaultId
    }

    public func read(_ path: String, vaultId: String) async throws -> Data? { try await session.readFile(path, vaultId: vaultId) }

    public func savePicks(_ document: Data) async throws -> Data {
        _ = try ownId()                    // the vault session writes picks to its reader vault; refuse if that is not mine
        return try await session.savePicks(document)
    }

    public func files(in folder: String, vaultId: String?) async throws -> [String] {
        try await session.files(in: folder, vaultId: vaultId).map(\.path)
    }

    public func append(_ data: Data, to folder: String, message: String) async throws -> String {
        try await session.append(data, to: folder, vaultId: ownId(), message: message)
    }

    private var master: VaultSession.OpenVault? { session.vaults.first { $0.role == "master" } }

    public func readMaster(_ path: String) async throws -> Data? {
        guard let master else { throw CollabHooks.HookError.noVault }
        return try await session.readFile(path, vaultId: master.vaultId)
    }

    /// The notes lane: `lane.json` in the master holds `{ lane: "sgit_private_vault_…:<id>", read, … }`.
    public func writeNewsroomNote(_ path: String, _ data: Data) async throws {
        guard let record = try await readMaster("lane.json"),
              let object = try JSONSerialization.jsonObject(with: record) as? [String: Any],
              let laneKey = object["lane"] as? String else {
            throw CollabHooks.HookError.noNotesLane
        }
        let laneId: String
        if let open = session.vaults.first(where: { laneKey.hasSuffix(":" + $0.vaultId) }) {
            laneId = open.vaultId
        } else {
            laneId = try await session.importKey(laneKey, label: "Newsroom notes lane").vaultId
        }
        try await session.update(path, vaultId: laneId, message: "A note from the PrompTugal app") { _ in data }
    }
}
