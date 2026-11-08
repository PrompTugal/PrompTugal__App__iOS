import Foundation
import Observation

/// "Who are you?" (as on web-summit.sgit.ai, `ws.me`): a person picked from the team's people list.
/// Picking is a view choice, not a sign-in, exactly as on the website. It becomes **verified** only when a team vault
/// is open on this device (decision D7): the vault session calls `verify(by:)` after it opens one.
@MainActor @Observable
final class TeamIdentityStore {
    struct Identity: Codable, Hashable, Sendable {
        let id: String
        let name: String
        let colour: String
    }

    private(set) var current: Identity?
    /// The id of the team vault that verified this identity, when one is open. Never a key.
    private(set) var verifiedBy: String?
    var verified: Bool { verifiedBy != nil }
    /// True when team features should show: a person is chosen (view) or a team vault is open (verified).
    var isTeamMember: Bool { current != nil }

    @ObservationIgnored private let defaults: UserDefaults
    static let key = "team.identity.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Identity.self, from: data) {
            current = saved
        }
    }

    func choose(_ person: TeamPerson) {
        set(Identity(id: person.id, name: person.name, colour: person.colour))
    }

    func clear() {
        verifiedBy = nil
        set(nil)
    }

    /// Called by the vault session when a team vault opens. The identity it names becomes the current one, verified.
    func verify(by vaultID: String, person: Identity) {
        verifiedBy = vaultID
        set(person)
    }

    func vaultClosed() {
        verifiedBy = nil
        NotificationCenter.default.post(name: .teamIdentityDidChange, object: self)
    }

    private func set(_ identity: Identity?) {
        guard identity != current || identity == nil else { return }
        current = identity
        if let identity, let data = try? JSONEncoder().encode(identity) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
        NotificationCenter.default.post(name: .teamIdentityDidChange, object: self)
    }
}
