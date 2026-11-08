import Foundation
import PTLanes

/// Gives PTLanes the teammates' vault ids from the coordination store. The Team app calls `install()` once at
/// launch (`Apps/Team/App/`). Lanes names no team type; this is the only link.
@MainActor
enum TeamLanesWiring {
    static func install() {
        LanesEnvironment.linkedVaults = { CoordinationStore.shared.linkedVaults }
    }
}
