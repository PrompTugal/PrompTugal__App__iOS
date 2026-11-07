import Foundation

/// Mirrors the schedule with the reader's vault at `agenda/picks` (brief 02: "Picks mirror to the vault path
/// agenda/picks"), in the same `nr.schedule.v1` document the website's vault code writes.
///
/// Written against closures so it does not depend on the vault code's types. The vault session wires it, e.g.:
///
///     try await ScheduleVaultSync.pull(into: TeamFeatures.shared.schedule) { path in
///         try await VaultSession.shared.readText(path)
///     }
///     // once vault writes exist:
///     try await ScheduleVaultSync.push(from: schedule) { path, text in try await session.writeText(path, text) }
@MainActor
enum ScheduleVaultSync {
    static let path = "agenda/picks"

    struct Outcome: Equatable, Sendable {
        let found: Bool
        let added: Int
        let removed: Int
    }

    /// Reads the vault's picks and merges them: the union, with removals made on this device winning when later.
    static func pull(into schedule: ScheduleStore,
                     read: (String) async throws -> String?) async throws -> Outcome {
        guard let text = try await read(path), let document = ScheduleDocument.decode(text) else {
            return Outcome(found: false, added: 0, removed: 0)
        }
        let outcome = schedule.merge(document, from: .vault)
        return Outcome(found: true, added: outcome.added.count, removed: outcome.removed.count)
    }

    /// The vault session's form (night/vault): `VaultSession.shared.loadPicks() -> Data?` and
    /// `savePicks(_:) -> Data`, which unions by id, commits to the branch the website reads, and returns the result.
    ///
    ///     if VaultSession.shared.reader != nil {
    ///         _ = try await ScheduleVaultSync.sync(schedule, load: { try await session.loadPicks() },
    ///                                              save: { try await session.savePicks($0) })
    ///     }
    static func sync(_ schedule: ScheduleStore, load: () async throws -> Data?,
                     save: (Data) async throws -> Data) async throws -> Outcome {
        var added = 0, removed = 0
        let found: Bool
        if let data = try await load(), let document = ScheduleDocument.decode(data) {
            let outcome = schedule.merge(document, from: .vault)
            added = outcome.added.count; removed = outcome.removed.count
            found = true
        } else {
            found = false
        }
        let saved = try await save(schedule.document.encoded())
        if let document = ScheduleDocument.decode(saved) {
            let outcome = schedule.merge(document, from: .vault)
            added += outcome.added.count; removed += outcome.removed.count
        }
        return Outcome(found: found, added: added, removed: removed)
    }

    /// Writes the merged schedule back, in the website's form.
    static func push(from schedule: ScheduleStore, write: (String, String) async throws -> Void) async throws {
        try await write(path, schedule.document.json)
    }
}
