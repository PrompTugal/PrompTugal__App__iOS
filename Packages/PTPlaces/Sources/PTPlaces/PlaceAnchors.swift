import SwiftUI

// Deep links into a place page (c.ios.ux spec S5): `place:<id>`, `place:<id>#now` (the "Now in" card) and
// `place:<id>#lead` (the lead story). The shell parses its destination with `PlacesDeepLink` and sets it once with
// `.placesDeepLink(_:)`, or opens `PlaceDetailView(id:anchor:)` directly. A page scrolls only for its own id, so
// places pushed from it open at the top.

public enum PlaceAnchor: String, Sendable, CaseIterable {
    case now, lead
}

public struct PlacesDeepLink: Equatable, Hashable, Sendable {
    public let id: String
    public let anchor: PlaceAnchor?

    public init(id: String, anchor: PlaceAnchor? = nil) {
        self.id = id
        self.anchor = anchor
    }

    /// Reads "place:loule", "place:loule#lead" or "place:faro#now"; nil for anything else (an unknown fragment
    /// keeps the place and drops the anchor).
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("place:") else { return nil }
        let rest = trimmed.dropFirst("place:".count)
        let parts = rest.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let id = String(parts.first ?? "")
        guard !id.isEmpty else { return nil }
        self.id = id
        anchor = parts.count > 1 ? PlaceAnchor(rawValue: String(parts[1])) : nil
    }

    public var text: String { anchor.map { "place:\(id)#\($0.rawValue)" } ?? "place:\(id)" }
}

private struct PlacesDeepLinkKey: EnvironmentKey {
    static let defaultValue: PlacesDeepLink? = nil
}

extension EnvironmentValues {
    /// The place link the app was opened with; the page for that id scrolls to its anchor.
    public var placesDeepLink: PlacesDeepLink? {
        get { self[PlacesDeepLinkKey.self] }
        set { self[PlacesDeepLinkKey.self] = newValue }
    }
}

extension View {
    /// Opens the place page for `link.id` scrolled to `link.anchor` (set high in the tree, like the other hooks).
    public func placesDeepLink(_ link: PlacesDeepLink?) -> some View {
        environment(\.placesDeepLink, link)
    }
}
