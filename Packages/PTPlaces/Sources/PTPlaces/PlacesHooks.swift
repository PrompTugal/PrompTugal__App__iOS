import SwiftUI

// Public slots so other packages (conductor.a.ios@'s PTLocal: the newsroom in action, persona, near me, owner talk)
// add to the places screens without editing them. Set them once, high in the app's view tree:
//
//   PlacesHomeView()
//       .placesHomeAccessory { AnyView(NewsroomLiveSection()) }
//       .placeAccessory { id in AnyView(TownNewsroomLive(placeID: id)) }
//
// The decoded data is public: `PlacesStore.shared.place(id)` (summary) and `.file(id)` (the whole place file).

private struct PlaceAccessoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor (String) -> AnyView)? = nil
}

private struct PlacesRegionMapKey: EnvironmentKey {
    static let defaultValue: (@MainActor (_ open: @escaping (String) -> Void) -> AnyView)? = nil
}

private struct PlacesHomeAccessoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}

extension EnvironmentValues {
    /// Rendered on a place's page under the mandate, for the place id given.
    public var placeAccessory: (@MainActor (String) -> AnyView)? {
        get { self[PlaceAccessoryKey.self] }
        set { self[PlaceAccessoryKey.self] = newValue }
    }

    /// Replaces the region's map on the Algarve page (e.g. PTLocal's AlgarveStyledMap with its four styles);
    /// call `open(placeID)` to open a place.
    public var placesRegionMap: (@MainActor (_ open: @escaping (String) -> Void) -> AnyView)? {
        get { self[PlacesRegionMapKey.self] }
        set { self[PlacesRegionMapKey.self] = newValue }
    }

    /// Rendered on the places home after the case studies.
    public var placesHomeAccessory: (@MainActor () -> AnyView)? {
        get { self[PlacesHomeAccessoryKey.self] }
        set { self[PlacesHomeAccessoryKey.self] = newValue }
    }
}

extension View {
    /// A section under the mandate of every place page; the closure gets the place id.
    public func placeAccessory(_ content: @escaping @MainActor (String) -> AnyView) -> some View {
        environment(\.placeAccessory, content)
    }

    /// The region's map on the Algarve page; the closure gets an `open(placeID)` to call on a tap.
    public func placesRegionMap(_ content: @escaping @MainActor (_ open: @escaping (String) -> Void) -> AnyView) -> some View {
        environment(\.placesRegionMap, content)
    }

    /// An extra section on the places home, after the case studies.
    public func placesHomeAccessory(_ content: @escaping @MainActor () -> AnyView) -> some View {
        environment(\.placesHomeAccessory, content)
    }
}
