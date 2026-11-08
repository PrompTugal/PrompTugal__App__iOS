import Foundation

// The Team app's stores, given to the packages through the small protocols PTAgenda and PTWeb define.

extension TeamStore: AgendaTeamSource {
    /// Changes whenever the "me" build or a loaded command centre changes.
    var dataVersion: String {
        let loaded = centres.map { "\($0.key):\($0.value.builtAt)" }.sorted().joined(separator: ",")
        return "\(me?.builtAt ?? "")|\(loaded)"
    }

    func loadEveryone() async {
        let ids = me?.people.map(\.id) ?? TeamPerson.order
        for id in ids { await refreshCentre(for: id) }
    }

    func centreSessions() -> [AgendaCentreSession] {
        var result: [AgendaCentreSession] = []
        for (person, centre) in centres.sorted(by: { $0.key < $1.key }) {
            let name = me?.person(person)?.first ?? centre.person.name.split(separator: " ").first.map(String.init) ?? person
            for session in centre.sessions {
                result.append(AgendaCentreSession(person: person, name: name, title: session.title,
                                                  whyRelevant: session.whyRelevant))
            }
        }
        return result
    }
}

extension TeamIdentityStore: AgendaIdentitySource {
    var currentID: String? { current?.id }
    var currentName: String? { current?.name }
    var isVerified: Bool { verified }
}

extension MeterStore: BridgeMeterSource {
    var balanceText: String? { snapshot.map { "balance \($0.balance)p" } }
    var bridgeCredits: [BridgeCredit] { pendingCredits.map { BridgeCredit(reference: $0.reference, pence: $0.pence) } }
    func markCredited(reference: String) {
        if let credit = pendingCredits.first(where: { $0.reference == reference }) { markCredited(credit) }
    }
}

/// The reader's vault, for the schedule's "Save my day to the vault".
@MainActor
final class VaultSessionPicks: VaultPicksAccess {
    var hasVault: Bool { VaultSession.shared.reader != nil }
    var canSave: Bool {
        guard let reader = VaultSession.shared.reader else { return false }
        return reader.canWrite && VaultSession.shared.canPush
    }
    var openVaultID: String? { VaultSession.shared.reader?.vaultId }
    func loadPicks() async throws -> Data? { try await VaultSession.shared.loadPicks() }
    func savePicks(_ local: Data) async throws -> Data { try await VaultSession.shared.savePicks(local) }
}
