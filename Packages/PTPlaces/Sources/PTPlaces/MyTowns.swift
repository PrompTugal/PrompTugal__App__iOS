import PTCore
import SwiftUI

/// The towns a reader follows ("pick my town"), kept on the device as ids in order. Now shows their latest.
public enum PlaceFollows {
    public static let key = "places.followed"

    public static func ids(_ raw: String) -> [String] {
        raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func raw(_ ids: [String]) -> String { ids.joined(separator: ",") }

    /// Adds the id at the end, or removes it when it is already there.
    public static func toggle(_ id: String, in raw: String) -> String {
        var list = ids(raw)
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { list.append(id) }
        return Self.raw(list)
    }
}

/// Follow or unfollow a place: a capsule button in the place's accent.
struct FollowButton: View {
    let id: String
    let accent: Color
    var onDark = false
    @AppStorage(PlaceFollows.key) private var followed = ""

    var body: some View {
        let on = PlaceFollows.ids(followed).contains(id)
        Button {
            withAnimation(.snappy) { followed = PlaceFollows.toggle(id, in: followed) }
        } label: {
            Label(on ? String(localized: "Following", bundle: .module) : String(localized: "Follow", bundle: .module),
                  systemImage: on ? "checkmark.circle.fill" : "plus.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(on ? (onDark ? Color.white : accent) : (onDark ? Color.white.opacity(0.2) : accent.opacity(0.12)), in: Capsule())
                .foregroundStyle(on ? (onDark ? accent : .white) : (onDark ? .white : accent))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityIdentifier("places.follow.\(id)")
    }
}

/// For Now: the latest from the towns the reader follows, or an invitation to pick one.
public struct MyTownsCard: View {
    @State private var store = PlacesStore.shared
    @AppStorage(PlaceFollows.key) private var followed = ""
    @Environment(\.openURL) private var openURL
    /// Opens the Places tab (the shell passes its own opener).
    let openPlaces: () -> Void

    public init(openPlaces: @escaping () -> Void) { self.openPlaces = openPlaces }

    public var body: some View {
        let ids = PlaceFollows.ids(followed)
        let invite: [PlaceSummary] = store.towns.sorted { a, b in
            (a.id == "loule" ? 0 : a.id == "faro" ? 1 : 2) < (b.id == "loule" ? 0 : b.id == "faro" ? 1 : 2)
        }
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Kicker(text: String(localized: "Your towns", bundle: .module))
                Spacer()
                Button(ids.isEmpty ? String(localized: "Pick", bundle: .module) : String(localized: "All places", bundle: .module), action: openPlaces)
                    .font(.footnote.weight(.semibold))
            }
            if ids.isEmpty {
                Text(String(localized: "Follow your town in the Algarve: its local AI news shows here.", bundle: .module))
                    .font(.subheadline).foregroundStyle(Palette.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(invite) { place in
                            VStack(spacing: 4) {
                                FollowButton(id: place.id, accent: PlaceTheme.accent(store.file(place.id), id: place.id))
                                Text(place.name).font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
            } else {
                ForEach(ids.compactMap { store.place($0) }) { place in
                    let accent = PlaceTheme.accent(store.file(place.id), id: place.id)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Space.s) {
                            Circle().fill(accent).frame(width: 10, height: 10)
                            Text(place.name).font(.headline)
                            StatusPill(status: place.status)
                            Spacer()
                        }
                        if let item = store.file(place.id)?.newsByDate.first {
                            StoryRow(item: item, place: nil, accent: accent)
                        } else {
                            Text(String(localized: "No local AI story yet.", bundle: .module)).font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
        .padding(Space.l)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
        .task { if store.places.isEmpty { await store.load() } }
        .accessibilityIdentifier("places.mytowns")
    }
}
