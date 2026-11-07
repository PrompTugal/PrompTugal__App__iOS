import Foundation
import Observation

/// Connects the schedule to the reader's vault (`apps/agenda/picks.json`, the website's `agenda/picks`), through
/// the vault session's `loadPicks()` / `savePicks(_:)`.
///
/// - **Pull** happens by itself: whenever a reader vault opens, and on `pull()` (app foreground, refresh).
///   Reading needs no Face ID once the vault is open.
/// - **Save** happens only when the person asks ("Save my day to the vault"): `savePicks` asks for Face ID
///   each time, and needs the vault key and an access token.
@MainActor @Observable
final class ScheduleVaultLink {
    enum State: Equatable {
        case noVault, idle, working, done(String), failed(String)
    }

    private(set) var state: State = .noVault
    private(set) var lastPull: Date?
    private(set) var lastSave: Date?

    /// A reader vault is open on this device.
    var hasVault: Bool { VaultSession.shared.reader != nil }
    /// It was opened with its vault key and an access token is set, so saving can work.
    var canSave: Bool {
        guard let reader = VaultSession.shared.reader else { return false }
        return reader.canWrite && VaultSession.shared.canPush
    }

    @ObservationIgnored private let schedule: ScheduleStore
    @ObservationIgnored private let log: BridgeLog

    init(schedule: ScheduleStore, log: BridgeLog) {
        self.schedule = schedule
        self.log = log
    }

    /// Starts watching the vault session: each time a reader vault opens, its picks are pulled in.
    func start() {
        watch()
        Task { await pull() }
    }

    private func watch() {
        withObservationTracking {
            _ = VaultSession.shared.reader?.vaultId
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.watch()
                await self?.pull()
            }
        }
    }

    /// Reads the vault's picks and merges them into the schedule.
    func pull() async {
        let vault = VaultSession.shared
        guard vault.reader != nil else { state = .noVault; return }
        state = .working
        do {
            let result = try await ScheduleVaultSync.pull(into: schedule) { _ in
                try await vault.loadPicks().map { String(decoding: $0, as: UTF8.self) }
            }
            lastPull = .now
            state = .done(result.found ? "\(result.added) added from your vault" : "No picks in your vault yet")
            log.record(host: "vault", .app, op: "schedule.vault.pull",
                       detail: result.found ? "+\(result.added) −\(result.removed)" : "no picks file")
        } catch {
            state = .failed("Your vault could not be read.")
            log.record(host: "vault", .app, op: "schedule.vault.pull", detail: String(describing: type(of: error)),
                       outcome: .failed)
        }
    }

    /// Loads, merges, saves the union to the vault (one Face ID), and merges back what the vault holds.
    func save() async {
        let vault = VaultSession.shared
        guard vault.reader != nil else { state = .noVault; return }
        guard canSave else {
            state = .failed("Saving needs your vault opened with its vault key and an access token.")
            return
        }
        state = .working
        do {
            let result = try await ScheduleVaultSync.sync(schedule, load: { try await vault.loadPicks() },
                                                          save: { try await vault.savePicks($0) })
            lastSave = .now
            state = .done("Saved \(schedule.document.picks.count) picks to your vault")
            log.record(host: "vault", .app, op: "schedule.vault.save",
                       detail: "\(schedule.document.picks.count) picks, +\(result.added) from the vault")
        } catch {
            state = .failed("Your picks could not be saved to the vault.")
            log.record(host: "vault", .app, op: "schedule.vault.save", detail: String(describing: type(of: error)),
                       outcome: .failed)
        }
    }
}
