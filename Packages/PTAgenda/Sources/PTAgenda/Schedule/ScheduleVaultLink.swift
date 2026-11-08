import Foundation
import Observation
import PTCore
import PTWeb

/// Connects the schedule to the reader's vault (`apps/agenda/picks.json`, the website's `agenda/picks`), through
/// the vault session's `loadPicks()` / `savePicks(_:)`, reached through `VaultPicksAccess`.
///
/// - **Pull** happens by itself: whenever a reader vault opens, and on `pull()` (app foreground, refresh).
///   Reading needs no Face ID once the vault is open.
/// - **Save** happens only when the person asks ("Save my day to the vault"): `savePicks` asks for Face ID
///   each time, and needs the vault key and an access token.
@MainActor @Observable
public final class ScheduleVaultLink {
    public enum State: Equatable {
        case noVault, idle, working, done(String), failed(String)
    }

    public private(set) var state: State = .noVault
    public private(set) var lastPull: Date?
    public private(set) var lastSave: Date?

    /// A reader vault is open on this device.
    public var hasVault: Bool { vault?.hasVault ?? false }
    /// It was opened with its vault key and an access token is set, so saving can work.
    public var canSave: Bool {
        vault?.canSave ?? false
    }

    @ObservationIgnored private let schedule: ScheduleStore
    @ObservationIgnored private let log: BridgeLog

    @ObservationIgnored private let vault: (any VaultPicksAccess)?

    public init(schedule: ScheduleStore, log: BridgeLog, vault: (any VaultPicksAccess)?) {
        self.schedule = schedule
        self.log = log
        self.vault = vault
    }

    /// Starts watching the vault session: each time a reader vault opens, its picks are pulled in.
    public func start() {
        watch()
        Task { await pull() }
    }

    private func watch() {
        withObservationTracking {
            _ = vault?.openVaultID
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.watch()
                await self?.pull()
            }
        }
    }

    /// Reads the vault's picks and merges them into the schedule.
    public func pull() async {
        guard let vault, vault.hasVault else { state = .noVault; return }
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
    public func save() async {
        guard let vault, vault.hasVault else { state = .noVault; return }
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
