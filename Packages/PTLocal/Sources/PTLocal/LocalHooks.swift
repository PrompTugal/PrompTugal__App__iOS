import SwiftUI

// A public slot so the app shell routes PTLocal's "open this place" taps to its own place page (place:<id>) instead
// of PTLocal's built-in TownView. Set it once, high in the app's view tree:
//
//   AlgarveMapsView()
//       .localOpenPlace { id in router.open("place:\(id)") }
//
// Without it, PTLocal pushes its own TownView, as before.

private struct LocalOpenPlaceKey: EnvironmentKey {
    static let defaultValue: (@MainActor (String) -> Void)? = nil
}

extension EnvironmentValues {
    /// Opens a place's page by its id ("faro", "algarve"); nil means PTLocal shows its own page.
    public var localOpenPlace: (@MainActor (String) -> Void)? {
        get { self[LocalOpenPlaceKey.self] }
        set { self[LocalOpenPlaceKey.self] = newValue }
    }
}

extension View {
    /// Routes PTLocal's place taps (Algarve maps) to the shell's place page.
    public func localOpenPlace(_ open: @escaping @MainActor (String) -> Void) -> some View {
        environment(\.localOpenPlace, open)
    }
}
