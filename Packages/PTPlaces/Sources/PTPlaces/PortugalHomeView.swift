import MapKit
import PTCore
import SwiftUI

// The PrompTugal.news homepage in the app (Dinis, 26 Nov ~00:40, after build 675): the top news from everything,
// town, the Algarve and Portugal, more about the news than about places. A lead story, the top stories across the
// country with their town > region > country trail and source, the latest from the towns, and a compact map that
// opens the places. Read from since.json, the by-place index and the place files PlacesStore already loads.

extension SinceFeed {
    /// Local: the item has a place of its own (a town, the Algarve, a district capital), or its title names one of the
    /// feed's places (Portugal included), so Portugal-level news about a Portuguese place counts and general
    /// industry news does not (Dinis, 26 Nov ~00:49).
    func isLocal(_ item: SinceItem) -> Bool {
        if item.place != nil { return true }
        let title = Self.fold(item.title)
        return places.contains { place in
            let names = [place.name.replacingOccurrences(of: "The ", with: "")] + (Self.englishNames[place.id] ?? [])
            return names.contains { raw in
                let name = Self.fold(raw)
                return name.count > 2 && title.contains(name)
            }
        }
    }

    /// The names English titles use for some places.
    static let englishNames: [String: [String]] = [
        "portugal": ["Portuguese"],
        "lisboa": ["Lisbon"],
        "porto": ["Oporto"],
        "algarve": ["Algarvian"],
    ]

    /// Nothing about Web Summit on the home (Dinis, 25 Nov): the app is local news, not the summit's.
    static func isAboutWebSummit(_ item: SinceItem) -> Bool {
        fold(item.title).contains(" web summit ")
    }

    /// Lowercased, accents off, punctuation as spaces, padded: " olhao teacher returns ... ".
    static func fold(_ text: String) -> String {
        let plain = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let spaced = plain.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        return " " + spaced.split(separator: " ").joined(separator: " ") + " "
    }

    var localNewestFirst: [SinceItem] {
        newestFirst.filter { isLocal($0) && !Self.isAboutWebSummit($0) }
    }

    /// The lead: the newest local item.
    var lead: SinceItem? { localNewestFirst.first }

    /// Items with no place, for the lower "Also in the news" strip.
    func alsoInTheNews(limit: Int) -> [SinceItem] {
        Array(newestFirst.filter { !isLocal($0) && !Self.isAboutWebSummit($0) }.prefix(limit))
    }

    /// The top stories: local items newest first, one per place before any place gets a second (an item with no
    /// place of its own counts as its first ring, else Portugal), so the front page spans the country.
    /// Date first (Dinis, 27 Nov): newer days always above older ones; within one day, one item per place before a
    /// place gets a second, so a day's front spans the country.
    func topStories(limit: Int, excluding: Set<String> = []) -> [SinceItem] {
        let pool = localNewestFirst.filter { !excluding.contains($0.id) }
        var days: [String] = []
        var byDay: [String: [SinceItem]] = [:]
        for item in pool {
            if byDay[item.date] == nil { days.append(item.date) }
            byDay[item.date, default: []].append(item)
        }
        var ordered: [SinceItem] = []
        for day in days {
            var places = Set<String>()
            var first: [SinceItem] = []
            var more: [SinceItem] = []
            for item in byDay[day] ?? [] {
                if places.insert(placeID(for: item)).inserted { first.append(item) } else { more.append(item) }
            }
            ordered += first + more
        }
        return Array(ordered.prefix(limit))
    }

    /// An item's place: its own, else the finest place its title names (a town over a region over the country), else
    /// its first ring, else Portugal.
    func placeID(for item: SinceItem) -> String {
        if let own = item.place { return own }
        if let named = namedPlace(in: item.title) { return named.id }
        return item.rings.first ?? "portugal"
    }

    /// The finest place a title names, by whole words (accents and case aside).
    func namedPlace(in title: String) -> SincePlace? {
        let folded = Self.fold(title)
        let rank: (SincePlace) -> Int = { place in
            if place.kind == "country" { return 2 }
            return place.kind == "region" ? 1 : 0
        }
        return places
            .filter { place in
                let names = [place.name.replacingOccurrences(of: "The ", with: "")] + (Self.englishNames[place.id] ?? [])
                return names.contains { raw in
                    let name = Self.fold(raw)
                    return name.count > 2 && folded.contains(name)
                }
            }
            .min { rank($0) < rank($1) }
    }
}

/// The app's home: PrompTugal.news's front page. Put it in a NavigationStack; place links push `PlaceDetailView`.
/// `openPlaces`, when given, adds an "All places" button (the shell switches to the Places tab).
public struct PortugalHomeView: View {
    @State private var store = PlacesStore.shared
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.placesOfflineData) private var offlineData
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
                if let feed = store.sinceFeed, !feed.items.isEmpty {
                    front(feed)
                } else {
                    waiting
                }
                latestFromTowns
                if let feed = store.sinceFeed { alsoInTheNews(feed) }
                mapStrip
            }
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: 1_100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .navigationTitle(String(localized: "Home", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PlaceRoute.self) { route in PlaceDetailView(id: route.id) }
        .navigationDestination(for: ArticleRoute.self) { route in ArticleView(id: route.id) }
        .refreshable { await store.load(force: true) }
        .task {
            PlacesOffline.shared.use(offlineData)
            await store.load()
            // The followed towns' prose in Portuguese, ready before their pages open.
            let followed = PlaceFollows.ids(UserDefaults.standard.string(forKey: PlaceFollows.key) ?? "")
            await PlacesTranslation.shared.load(followed.compactMap { store.file($0)?.translatableProse }.flatMap { $0 })
        }
        .accessibilityIdentifier("home.news")
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PrompTugal.news")
                .font(.system(wide ? .largeTitle : .title, design: .serif, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Palette.ink)
            Rectangle().fill(Palette.ink).frame(height: 2)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(String(localized: "Portugal's AI news, town by town", bundle: .module)).fixedSize()
                    Spacer()
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).fixedSize()
                }
                Text(String(localized: "Portugal's AI news, town by town", bundle: .module)).lineLimit(2)
            }
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Palette.muted)
            PlacesOriginLabel(origin: store.sinceOrigin(dataDate: store.sinceFeed?.lead?.date))
        }
        .padding(.horizontal, gutter)
        .padding(.top, Space.m)
    }

    @ViewBuilder private var waiting: some View {
        if store.since.failed {
            ContentUnavailableView {
                Label(String(localized: "The news did not load", bundle: .module), systemImage: "wifi.exclamationmark")
            } actions: {
                Button(String(localized: "Try again", bundle: .module)) { Task { await store.load(force: true) } }
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
            let recent = top.filter { (PlaceDates.daysOld($0.date) ?? 99) <= 1 }
            let earlier = top.filter { (PlaceDates.daysOld($0.date) ?? 99) > 1 }
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "Top stories", bundle: .module),
                            subtitle: String(localized: "Across the country, newest first, each with where it happened and its source", bundle: .module),
                            accent: Palette.red)
                ForEach(recent) { item in
                    HomeStoryRow(item: item, feed: feed, store: store)
                    Divider()
                }
                if !earlier.isEmpty {
                    Kicker(text: String(localized: "Earlier", bundle: .module), color: Palette.muted)
                        .padding(.top, Space.m)
                    ForEach(earlier) { item in
                        HomeStoryRow(item: item, feed: feed, store: store)
                        Divider()
                    }
                }
            }
            .padding(.horizontal, gutter)
        }
    }

    // MARK: Also in the news (no place of its own)

    @ViewBuilder private func alsoInTheNews(_ feed: SinceFeed) -> some View {
        let items = feed.alsoInTheNews(limit: wide ? 6 : 4)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "Also in the news", bundle: .module),
                            subtitle: String(localized: "Read by our desk, not tied to one place", bundle: .module))
                ForEach(items) { item in
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
                SectionHead(title: String(localized: "Latest from the towns", bundle: .module),
                            subtitle: String(localized: "What the town agents read this week, each with its source", bundle: .module))
                ForEach(latest, id: \.item.id) { entry in
                    StoryRow(item: entry.item, place: entry.place,
                             accent: PlaceTheme.accent(store.file(entry.place.id), id: entry.place.id))
                }
                PlacesOriginLabel(origin: store.index.origin(dataDate: latest.map(\.item.date).max(), story: true))
            }
            .padding(.horizontal, gutter)
        }
    }

    // MARK: The map strip

    private var mapStrip: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHead(title: String(localized: "The places", bundle: .module),
                        subtitle: String(localized: "The district capitals and the Algarve, each with its own agent. Tap one.", bundle: .module))
            PortugalMapStrip(store: store)
                .frame(height: wide ? 200 : 150)
                .clipShape(RoundedRectangle(cornerRadius: Space.radius))
            if let openPlaces {
                Button(action: openPlaces) {
                    Label(String(localized: "All places", bundle: .module), systemImage: "map")
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
            StoryOpen(link: item.url) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(text: item.isArticle ? String(localized: "Our article", bundle: .module) : item.byline, color: Palette.red)
                    Text(english: item.title)
                        .font(.system(wide ? .largeTitle : .title, design: .serif, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    ReadAtLine(outlet: item.byline, readOn: "", accent: Palette.red)
                    Text(PlaceDates.age(item.date)).font(.caption).foregroundStyle(Palette.muted)
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
            StoryOpen(link: item.url) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(english: item.title)
                        .font(Typo.story)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ReadAtLine(outlet: item.byline, readOn: "", accent: Palette.red)
                        Text(PlaceDates.age(item.date)).font(.caption2).foregroundStyle(Palette.muted).fixedSize()
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
