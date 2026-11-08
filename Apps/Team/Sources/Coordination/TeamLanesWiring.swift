import Foundation
import PTCore
import PTAsk
import PTLanes
import PTVaultUI

/// Gives PTLanes the teammates' vault ids from the coordination store, installs the vault seam, and gives Ask the Team provider. The Team app calls `install()` once at
/// launch (`Apps/Team/App/`). Lanes names no team type; this is the only link.
@MainActor
enum TeamLanesWiring {
    static func install() {
        VaultCollabAccess.install()
        TeamAskProvider.install()
        LanesEnvironment.linkedVaults = { CoordinationStore.shared.linkedVaults }
    }
}
