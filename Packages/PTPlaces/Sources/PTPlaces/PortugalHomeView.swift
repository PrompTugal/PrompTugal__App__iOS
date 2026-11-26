import MapKit
import PTCore
import SwiftUI

// The PrompTugal.news homepage in the app (Dinis, 26 Nov ~00:40, after build 675): the top news from everything,
// town, the Algarve and Portugal, more about the news than about places. A lead story, the top stories across the
// country with their town > region > country trail and source, the latest from the towns, and a compact map that
// opens the places. Read from since.json, the by-place index and the place files PlacesStore already loads.

extension SinceFeed {
    /// The lead: our newest article, else the newest item.
    var lead: SinceItem? {
        let all = newestFirst
        return all.first(where: \.isArticle) ?? all.first
    }

    /// The top stories: newest first, one per place before any place gets a second (an item with no place of its own
    /// counts as its first ring, else Portugal), so the front page spans the country.
    func topStories(limit: Int, excluding: Set<String> = []) -> [SinceItem] {
        var places = Set<String>()
        var first: [SinceItem] = []
        var more: [SinceItem] = []
        for item in newestFirst where !excluding.contains(item.id) {
            let key = item.place ?? item.rings.first ?? "portugal"
            if places.insert(key).inserted { first.append(item) } else { more.append(item) }
        }
        return Array((first + more).prefix(limit))
    }
}

/// The app's home: PrompTugal.news's front page. Put it in a NavigationStack; place links push `PlaceDetailView`.
/// `openPlaces`, when given, adds an "All places" button (the shell switches to the Places tab).
public struct PortugalHomeView: View {
    @State private var store = PlacesStore.shared
    @Environment(\.horizontalSizeClass) private var width
    private let openPlaces: (() -> Void)?

    public init(openPlaces: (() -> Void)? = nil) {
        self.openPlaces = openPlaces
    }

    private var wide: Bool { width == .regular }
    private var gutter: CGFloat { wide ? Space.xxl : Space.l }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.xl) {
                masthead
                if let feed = store.since.value, !feed.items.isEmpty {
                    front(feed)
                } else {
                    waiting
                }
                latestFromTowns
                mapStrip
            }
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: 1_100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .navigationTitle(String(localized: "Home"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PlaceRoute.self) { route in PlaceDetailView(id: route.id) }
        .refreshable { await store.load(force: true) }
        .task { await store.load() }
        .accessibilityIdentifier("home.news")
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PrompTugal.news")
                .font(.system(size: wide ? 44 : 32, weight: .black, design: .serif))
                .foregroundStyle(Palette.ink)
            Rectangle().fill(Palette.ink).frame(height: 2)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(String(localized: "AI news from Portugal, town by town")).fixedSize()
                    Spacer()
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).fixedSize()
                }
                Text(String(localized: "AI news from Portugal, town by town")).lineLimit(2)
            }
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Palette.muted)
            PlacesOriginLabel(origin: store.since.origin(dataDate: store.since.value?.built))
        }
        .padding(.horizontal, gutter)
        .padding(.top, Space.m)
    }

    @ViewBuilder private var waiting: some View {
        if store.since.failed {
            ContentUnavailableView {
                Label(String(localized: "The news did not load"), systemImage: "wifi.exclamationmark")
            } actions: {
                Button(String(localized: "Try again")) { Task { await store.load(force: true) } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    // MARK: The front: lead and top stories

    @ViewBuilder private func front(_ feed: SinceFeed) -> some View {
        if let lead = feed.lead {
            HomeLead(item: lead, feed: feed, store: store, wide: wide)
                .padding(.horizontal, gutter)
            let top = feed.topStories(limit: wide ? 10 : 7, excluding: [lead.id])
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "Top stories"),
                            subtitle: String(localized: "Across the country, each with where it happened and its source"),
                            accent: Palette.red)
                ForEach(top) { item in
                    HomeStoryRow(item: item, feed: feed, store: store)
                    Divider()
                }
            }
            .padding(.horizontal, gutter)
        }
    }

    // MARK: Latest from the towns (the place files)

    @ViewBuilder private var latestFromTowns: some View {
        let latest = store.latestAcrossTowns(limit: wide ? 8 : 5)
        if !latest.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Latest from the towns"),
                            subtitle: String(localized: "What the town agents read this week, each with its source"))
                ForEach(latest, id: \.item.id) { entry in
                    StoryRow(item: entry.item, place: entry.place,
                             accent: PlaceTheme.accent(store.file(entry.place.id), id: entry.place.id))
                }
                PlacesOriginLabel(origin: store.index.origin(dataDate: latest.map(\.place.updated).max()))
            }
            .padding(.horizontal, gutter)
        }
    }

    // MARK: The map strip

    private var mapStrip: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHead(title: String(localized: "The places"),
                        subtitle: String(localized: "The district capitals and the Algarve, each with its own agent. Tap one."))
            PortugalMapStrip(store: store)
                .frame(height: wide ? 260 : 200)
                .clipShape(RoundedRectangle(cornerRadius: Space.radius))
            if let openPlaces {
                Button(action: openPlaces) {
                    Label(String(localized: "All places"), systemImage: "map")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.red)
            }
        }
        .padding(.horizontal, gutter)
        .accessibilityIdentifier("home.map")
    }
}

// MARK: - Parts

/// The lead, set big: kind and outlet, title, its trail, and the link to its source.
struct HomeLead: View {
    let item: SinceItem
    let feed: SinceFeed
    let store: PlacesStore
    let wide: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Button {
                if let url = URL(string: item.url) { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(text: item.isArticle ? String(localized: "Our article") : item.byline, color: Palette.red)
                    Text(item.title)
                        .font(.system(size: wide ? 40 : 28, weight: .black, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    ReadAtLine(outlet: item.byline, readOn: "", accent: Palette.red)
                    Text(PlaceDates.short(item.date)).font(.caption).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            RingTrail(places: feed.trail(for: item), store: store)
        }
        .padding(Space.xl)
        .background(Palette.card)
        .overlay(alignment: .leading) { Rectangle().fill(Palette.red).frame(width: 6) }
        .clipShape(RoundedRectangle(cornerRadius: Space.radius))
        .accessibilityIdentifier("home.lead")
    }
}

/// A top story: title and source as one button, its trail under it (separate links, never inside the button).
struct HomeStoryRow: View {
    let item: SinceItem
    let feed: SinceFeed
    let store: PlacesStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if let url = URL(string: item.url) { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(Typo.story)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ReadAtLine(outlet: item.byline, readOn: "", accent: Palette.red)
                        Text(PlaceDates.short(item.date)).font(.caption2).foregroundStyle(Palette.muted).fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            RingTrail(places: feed.trail(for: item), store: store)
        }
        .padding(.vertical, Space.s)
        .accessibilityIdentifier("home.story")
    }
}

/// A small, still map of Portugal: the district capitals and the Algarve, each pin opening its place.
struct PortugalMapStrip: View {
    let store: PlacesStore

    var body: some View {
        Map(initialPosition: .camera(MapScope.portugal.camera), interactionModes: []) {
            ForEach(pins, id: \.place.id) { pin in
                Annotation(pin.place.name, coordinate: pin.coordinate, anchor: .bottom) {
                    NavigationLink(value: PlaceRoute(pin.place.id)) {
                        TownPin(place: pin.place, accent: PlaceTheme.accent(store.file(pin.place.id), id: pin.place.id),
                                highlighted: pin.place.kind == "region")
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
    }

    private var pins: [(place: PlaceSummary, coordinate: CLLocationCoordinate2D)] {
        let places = store.portugalCities + [store.place("algarve")].compactMap { $0 }
        return places.compactMap { place in PlaceTheme.coordinate(place).map { (place, $0) } }
    }
}
