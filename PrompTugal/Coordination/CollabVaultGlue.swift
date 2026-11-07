import Foundation
import SGitVault

/// `CollabVaultAccess` over the vault session (night/vault). Installed as `CollabHooks.vault`.
@MainActor
final class VaultCollabAccess: CollabVaultAccess {
    let session: VaultSession

    init(session: VaultSession = .shared) { self.session = session }

    var isOpen: Bool { !session.isLocked }
    var canWrite: Bool { session.reader?.canWrite ?? false }

    func read(_ path: String) async throws -> Data? { try await session.readFile(path) }

    func write(_ path: String, _ data: Data, _ message: String) async throws {
        try await session.update(path, message: message) { _ in data }
    }

    func openShared(readKey: String, label: String) async throws -> String {
        try await session.importKey(readKey, label: label).vaultId
    }

    func read(_ path: String, vaultId: String) async throws -> Data? { try await session.readFile(path, vaultId: vaultId) }

    func savePicks(_ document: Data) async throws -> Data { try await session.savePicks(document) }

    func files(in folder: String, vaultId: String?) async throws -> [String] {
        try await session.files(in: folder, vaultId: vaultId).map(\.path)
    }

    func append(_ data: Data, to folder: String, message: String) async throws -> String {
        try await session.append(data, to: folder, message: message)
    }

    private var master: VaultSession.OpenVault? { session.vaults.first { $0.role == "master" } }

    func readMaster(_ path: String) async throws -> Data? {
        guard let master else { throw CollabHooks.HookError.noVault }
        return try await session.readFile(path, vaultId: master.vaultId)
    }

    /// The notes lane: `lane.json` in the master holds `{ lane: "sgit_private_vault_…:<id>", read, … }`.
    func writeNewsroomNote(_ path: String, _ data: Data) async throws {
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
