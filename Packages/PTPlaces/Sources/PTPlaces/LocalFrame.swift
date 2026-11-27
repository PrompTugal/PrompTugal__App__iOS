import MapKit
import PTCore
import SwiftUI

// Locality as the frame (Dinis, 25 Nov ~23:35): what makes the app special is the towns. The home opens on a big
// map of the Algarve's towns and the district capitals (tap one to open it), and shows how news bubbles up: a
// town's story rises to the Algarve and to Portugal, read from since.json's `place` and `rings`.

// MARK: - Rings (since.json)

extension SinceFeed {
    /// The place for an id, from the feed's own list (a bare place made from the id otherwise).
    func place(_ id: String) -> SincePlace {
        places.first { $0.id == id } ?? SincePlace(id: id, name: id.capitalized)
    }

    /// The item's way up: its own place, its region, the country (rings in order, without repeats).
    func trail(for item: SinceItem) -> [SincePlace] {
        var seen = Set<String>()
        var ids = item.rings
        if ids.isEmpty, let own = item.place { ids = [own] }
        // A placeless item takes the finest place its title names, then that place's parents.
        if item.place == nil, let named = namedPlace(in: item.title) {
            var chain: [String] = []
            var next: String? = named.id
            while let id = next, !chain.contains(id), chain.count < 4 {
                chain.append(id)
                let parent = place(id).parent
                next = parent.isEmpty ? nil : parent
            }
            ids = chain
        }
        return ids.filter { seen.insert($0).inserted }.map(place)
    }

    /// Items that reach a ring: every item whose rings include the id (exact match, never a prefix).
    func items(reaching id: String) -> [SinceItem] {
        items.filter { $0.rings.contains(id) }
    }

    /// Items that started in a town (an own place that is neither the country nor a region).
    var townItems: [SinceItem] {
        items.filter { item in
            guard let own = item.place else { return false }
            let kind = place(own).kind
            return kind != "country" && kind != "region"
        }
    }

    /// The town to show bubbling up: the first followed town with a story, else the town of the newest town story.
    func featuredTown(followed: [String]) -> String? {
        let towns = townItems
        if let id = followed.first(where: { id in towns.contains { $0.place == id } }) { return id }
        return towns.max { $0.date < $1.date }?.place
    }
}

// MARK: - The map hero

enum MapScope: String, CaseIterable, Identifiable {
    case portugal, algarve
    var id: String { rawValue }

    var title: String {
        switch self {
        case .algarve: String(localized: "The Algarve", bundle: .module)
        case .portugal: String(localized: "Portugal", bundle: .module)
        }
    }

    var camera: MapCamera {
        switch self {
        case .algarve:
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 37.2, longitude: -8.15), distance: 190_000, heading: 0, pitch: 0)
        case .portugal:
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 39.6, longitude: -8.0), distance: 1_250_000, heading: 0, pitch: 0)
        }
    }
}

/// A big map near the top of the home: the Algarve's towns, or Portugal's district capitals with the Algarve.
/// Every pin opens its place; the chips under the map do the same for anyone who prefers a list.
struct PlacesMapHero: View {
    let store: PlacesStore
    let wide: Bool
    /// Places opens on Portugal (Dinis, 26 Nov); the Algarve is one tap away.
    @State private var scope: MapScope = .portugal
    @State private var position: MapCameraPosition = .camera(MapScope.portugal.camera)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            header
            map
            chips
            PlacesOriginLabel(origin: store.index.origin(dataDate: places.map(\.updated).max()))
        }
        .padding(.horizontal, wide ? Space.xxl : Space.l)
        .accessibilityIdentifier("places.map")
    }

    private var places: [PlaceSummary] {
        switch scope {
        case .algarve: store.algarveTowns
        case .portugal: store.portugalCities + [store.place("algarve")].compactMap { $0 }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHead(title: String(localized: "Your town, on the map", bundle: .module),
                        subtitle: subtitle, accent: Palette.red)
            Picker(String(localized: "Map", bundle: .module), selection: $scope) {
                ForEach(MapScope.allCases) { scope in Text(scope.title).tag(scope) }
            }
            .pickerStyle(.segmented)
            .onChange(of: scope) { _, new in
                withAnimation(.easeInOut(duration: 0.6)) { position = .camera(new.camera) }
            }
        }
    }

    private var subtitle: String {
        switch scope {
        case .algarve:
            String(localized: "The Algarve's \(store.algarveTowns.count) towns, each with its own agent. Tap a town.", bundle: .module)
        case .portugal:
            String(localized: "The \(store.portugalCities.count) district capitals and the Algarve. Tap a place.", bundle: .module)
        }
    }

    private var map: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(pins) { pin in
                Annotation(pin.place.name, coordinate: pin.coordinate, anchor: .bottom) {
                    NavigationLink(value: PlaceRoute(pin.place.id)) {
                        TownPin(place: pin.place, accent: pin.accent, highlighted: pin.place.kind == "region")
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .containerRelativeFrame(.vertical) { height, _ in min(wide ? 560 : 420, max(260, height * 0.55)) }
        .clipShape(RoundedRectangle(cornerRadius: Space.radius))
    }

    private var pins: [MapPin] {
        places.compactMap { place in
            guard let coordinate = PlaceTheme.coordinate(place) else { return nil }
            return MapPin(place: place, coordinate: coordinate, accent: PlaceTheme.accent(store.file(place.id), id: place.id))
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(places) { place in
                    NavigationLink(value: PlaceRoute(place.id)) {
                        PlaceChip(name: place.name, count: place.aiNews,
                                  accent: PlaceTheme.accent(store.file(place.id), id: place.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct MapPin: Identifiable {
        let place: PlaceSummary
        let coordinate: CLLocationCoordinate2D
        let accent: Color
        var id: String { place.id }
    }
}

/// A place's name and its story count, in its colour.
struct PlaceChip: View {
    let name: String
    let count: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(accent).frame(width: 8, height: 8)
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            if count > 0 {
                Text("\(count)").font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(accent.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bubbling up

/// How the news rises: a town's stories, the Algarve's, Portugal's, as three steps with their counts from the last
/// days of since.json, then the town's newest stories each with the trail it took (town, region, country).
struct BubblingUpSection: View {
    let store: PlacesStore
    let wide: Bool
    @AppStorage(PlaceFollows.key) private var followed = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let feed = store.since.value, let town = feed.featuredTown(followed: PlaceFollows.ids(followed)) {
            content(feed, town: town)
        }
    }

    private func content(_ feed: SinceFeed, town: String) -> some View {
        let place = feed.place(town)
        let stories = feed.newestFirst.filter { $0.place == town }
        let region = feed.trail(for: stories.first ?? SinceItem(date: "", title: "", url: "")).dropFirst().first
        return VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "From the town up", bundle: .module),
                        subtitle: String(localized: "How a story in \(place.name) rises to the region and the country, from the last \(feed.days) days", bundle: .module),
                        accent: Palette.red)
            ladder(feed, town: place, region: region)
            ForEach(Array(stories.prefix(wide ? 4 : 3))) { item in
                trailRow(item, feed: feed)
                Divider()
            }
        }
        .padding(.horizontal, wide ? Space.xxl : Space.l)
        .accessibilityIdentifier("places.bubbling")
    }

    /// Three steps, the country at the top: each with how many items reach it.
    private func ladder(_ feed: SinceFeed, town: SincePlace, region: SincePlace?) -> some View {
        let country = feed.place("portugal")
        var steps: [(SincePlace, Int)] = [(country, feed.items(reaching: country.id).count)]
        if let region { steps.append((region, feed.items(reaching: region.id).count)) }
        steps.append((town, feed.items(reaching: town.id).count))
        let most = max(steps.map(\.1).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                LadderStep(place: step.0, count: step.1, share: Double(step.1) / Double(most),
                           accent: ladderColor(step.0, isTown: index == steps.count - 1), indent: CGFloat(index))
            }
        }
    }

    /// Only towns own colours; the region and the country are ink at 0.6 (design review E).
    private func ladderColor(_ place: SincePlace, isTown: Bool) -> Color {
        isTown ? PlaceTheme.accent(store.file(place.id), id: place.id) : Palette.ink.opacity(0.6)
    }

    private func trailRow(_ item: SinceItem, feed: SinceFeed) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            StoryOpen(link: item.url) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(Typo.story).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    Text(String(localized: "Read at \(item.byline)", bundle: .module) + " · " + PlaceDates.age(item.date))
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            RingTrail(places: feed.trail(for: item), store: store)
        }
        .padding(.vertical, Space.s)
    }
}

/// One step of the ladder: the place, a bar for its share, the count.
struct LadderStep: View {
    let place: SincePlace
    let count: Int
    let share: Double
    let accent: Color
    let indent: CGFloat

    var body: some View {
        NavigationLink(value: PlaceRoute(place.id)) {
            // One row when the name fits beside the bar, else the name above it (design review B).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s) {
                    name.fixedSize()
                    barAndCount
                }
                VStack(alignment: .leading, spacing: 4) {
                    name.fixedSize(horizontal: false, vertical: true)
                    barAndCount
                }
            }
            .padding(.leading, indent * 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(place.name): \(count) items", bundle: .module))
    }

    private var name: some View {
        Text(place.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.ink)
    }

    private var barAndCount: some View {
        HStack(spacing: Space.s) {
            GeometryReader { geo in
                Capsule().fill(accent).frame(width: max(8, geo.size.width * share))
            }
            .frame(minWidth: 80)
            .frame(height: 10)
            Text("\(count)").font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(Palette.muted)
                .fixedSize()
        }
    }
}

/// A story's way up as linked chips: town › region › country; each opens its place.
struct RingTrail: View {
    let places: [SincePlace]
    let store: PlacesStore

    /// Wraps onto more lines on a small phone or at large text sizes (design review A).
    var body: some View {
        WrapLayout(spacing: 4) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                NavigationLink(value: PlaceRoute(place.id)) {
                    HStack(spacing: 4) {
                        if index > 0 {
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Text(place.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(index: index, place: place))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Only the town owns a colour; the region and the country are ink (design review E).
    private func color(index: Int, place: SincePlace) -> Color {
        index == 0 && place.id != "portugal" ? PlaceTheme.accent(store.file(place.id), id: place.id) : Palette.ink.opacity(0.7)
    }
}
