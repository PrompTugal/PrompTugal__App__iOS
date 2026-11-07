import SwiftUI

/// One "who am I" for the whole app. The team session's `TeamIdentityStore` is the source of truth
/// (it is what a team vault verifies); the design screens read `team.me` from UserDefaults. This keeps
/// the two in step both ways: a pick in either place updates the other.
struct IdentitySync: ViewModifier {
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(TeamStore.self) private var team
    @AppStorage(DashboardData.meKey) private var me = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: identity.current?.id, initial: true) { _, id in
                if let id, id != me { me = id }
            }
            .onChange(of: me) { _, id in push(id) }
            .onChange(of: team.me?.people.count) { _, _ in push(me) }
    }

    private func push(_ id: String) {
        guard id != identity.current?.id else { return }
        if id.isEmpty || id == "reader" {
            if identity.current != nil, identity.verifiedBy == nil { identity.clear() }
        } else if let person = team.me?.person(id) {
            identity.choose(person)
        }
    }
}

extension View {
    func identitySync() -> some View { modifier(IdentitySync()) }
}
