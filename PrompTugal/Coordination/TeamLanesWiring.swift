import Foundation
import PTCore
import PTLanes
import PTVaultUI

/// Gives PTLanes the teammates' vault ids from the coordination store. The Team app calls `install()` once at
/// launch (`Apps/Team/App/`). Lanes names no team type; this is the only link.
@MainActor
enum TeamLanesWiring {
    static func install() {
        VaultCollabAccess.install()
        LanesEnvironment.linkedVaults = { CoordinationStore.shared.linkedVaults }
    }
}
