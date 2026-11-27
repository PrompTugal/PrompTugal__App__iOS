import MapKit
import PTCore
import SwiftUI

/// Where a place link goes inside the magazine's navigation stack.
public struct PlaceRoute: Hashable, Sendable {
    public let id: String
    public init(_ id: String) { self.id = id }
}

/// The places magazine: PrompTugal.news by place, in the spirit of the early iPad news apps. A satellite hero of
/// the Algarve with its 17 towns, Loulé and Faro as the case studies, the national edition, a mosaic of the towns
/// in their own colours, the latest local AI stories, and the agents who make it.
public struct PlacesHomeView: View {
    @State private var store = PlacesStore.shared
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.openURL) private var openURL
    @Environment(\.placesHomeAccessory) private var homeAccessory

    /// The case studies, deepest first (Dinis, 15 November).
    static let caseStudies = ["loule", "faro"]

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.xl) {
                masthead
                if store.places.isEmpty {
                    loadingOrError
                } else {
                    PlacesMapHero(store: store, wide: wide)
                    SinceYouLookedSection(store: store, wide: wide)
                    BubblingUpSection(store: store, wide: wide)
                    if let homeAccessory { homeAccessory() }
                    // Locality first (design review C): the towns, the capitals, the latest, then the footer.
                    // Case studies, the national edition, connections, work with us and the agents strip left the
                    // page; the town pages keep their own agents and connections.
                    townMosaic
                    acrossPortugal
                    latestStories
                    footer
                }
            }
            .padding(.bottom, Space.xxl)
        }
        .background(Palette.paper)
        .navigationTitle(String(localized: "Places", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PlaceRoute.self) { route in
            PlaceDetailView(id: route.id)
        }
        .navigationDestination(for: ArticleRoute.self) { route in ArticleView(id: route.id) }
        .refreshable { await store.load(force: true) }
        .task { await store.load() }
        .accessibilityIdentifier("places.home")
    }

    private var wide: Bool { width == .regular }
    private var gutter: CGFloat { wide ? Space.xxl : Space.l }

    // MARK: Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("PrompTugal.news")
                    .font(.system(size: wide ? 44 : 32, weight: .black, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text(String(localized: "by place", bundle: .module))
                    .font(.system(wide ? .title2 : .title3, design: .serif).italic())
                    .foregroundStyle(Palette.red)
                Spacer()
                PersonBadge()
            }
            Rectangle().fill(Palette.ink).frame(height: 2)
            // One line on a wide screen; on a small phone (iPhone SE) the date goes and the line may wrap.
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(mastheadLine).fixedSize()
                    Spacer()
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).fixedSize()
                }
                Text(mastheadLine).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Palette.muted)
            Rectangle().fill(Palette.ink).frame(height: 0.5)
        }
        .padding(.horizontal, gutter)
        .padding(.top, Space.m)
    }

    private var mastheadLine: String {
        let towns = store.algarveTowns.count
        let capitals = store.portugalCities.count
        if towns == 0 { return String(localized: "Portugal · The Algarve", bundle: .module) }
        if capitals == 0 { return String(localized: "Portugal · The Algarve · \(towns) towns", bundle: .module) }
        return String(localized: "Portugal · The Algarve · \(towns) towns · \(capitals) district capitals", bundle: .module)
    }

    @ViewBuilder private var loadingOrError: some View {
        if case .failed(let message) = store.phase {
            ContentUnavailableView {
                Label(String(localized: "The places did not load", bundle: .module), systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button(String(localized: "Try again", bundle: .module)) { Task { await store.load(force: true) } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: Space.m) {
                ProgressView()
                Text(String(localized: "Reading the places from promptugal.news", bundle: .module)).font(.footnote).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    // MARK: Case studies

    private var caseStudies: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "The case studies", bundle: .module),
                        subtitle: String(localized: "Loulé and Faro, where the agents go deepest first", bundle: .module))
            let studies = Self.caseStudies.compactMap { store.place($0) }
            let layout = wide ? AnyLayout(HStackLayout(spacing: Space.l)) : AnyLayout(VStackLayout(spacing: Space.l))
            layout {
                ForEach(studies) { place in
                    NavigationLink(value: PlaceRoute(place.id)) {
                        CaseStudyCard(place: place, file: store.file(place.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, gutter)
    }

    // MARK: The national edition

    @ViewBuilder private var nationalEdition: some View {
        if let portugal = store.place("portugal") {
            let file = store.file("portugal")
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Portugal", bundle: .module), subtitle: file?.mandate, accent: Palette.red)
                    .padding(.horizontal, gutter)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Space.m) {
                        NavigationLink(value: PlaceRoute(portugal.id)) {
                            ZStack(alignment: .bottomLeading) {
                                SatelliteView(place: portugal)
                                Scrim()
                                VStack(alignment: .leading, spacing: 4) {
                                    Kicker(text: String(localized: "The national edition", bundle: .module), color: .white.opacity(0.85))
                                    Text("Portugal").font(.system(.largeTitle, design: .serif, weight: .black)).foregroundStyle(.white)
                                    Text(String(localized: "\(portugal.aiNews) stories · \(portugal.aiMap) on the AI map", bundle: .module))
                                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                                }
                                .padding(Space.l)
                            }
                            .frame(width: wide ? 340 : 260, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: Space.radius))
                        }
                        .buttonStyle(.plain)
                        ForEach((file?.newsByDate ?? []).prefix(8)) { item in
                            StoryTile(item: item, accent: Palette.red, place: nil)
                                .frame(width: wide ? 300 : 240, height: 300)
                        }
                    }
                    .padding(.horizontal, gutter)
                }
            }
        }
    }

    // MARK: The towns, as a mosaic

    private var townMosaic: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "The \(store.algarveTowns.count) towns", bundle: .module),
                        subtitle: String(localized: "Each town in its own colours, its agent, its AI map", bundle: .module))
            let columns = [GridItem(.adaptive(minimum: wide ? 200 : 150), spacing: Space.m)]
            LazyVGrid(columns: columns, spacing: Space.m) {
                ForEach(Array(store.algarveTowns.enumerated()), id: \.element.id) { index, place in
                    NavigationLink(value: PlaceRoute(place.id)) {
                        TownTile(place: place, file: store.file(place.id), seed: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, gutter)
    }

    // MARK: Across Portugal (every district capital the index has; the Algarve's numbers keep to the Algarve)

    @ViewBuilder private var acrossPortugal: some View {
        let cities = store.portugalCities
        if !cities.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Across Portugal", bundle: .module),
                            subtitle: capitalsSubtitle(cities.count), accent: Palette.red)
                PlacesOriginLabel(origin: store.index.origin(dataDate: cities.map(\.updated).max()))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: wide ? 200 : 150), spacing: Space.m)], spacing: Space.m) {
                    ForEach(Array(cities.enumerated()), id: \.element.id) { index, place in
                        NavigationLink(value: PlaceRoute(place.id)) {
                            TownTile(place: place, file: store.file(place.id), seed: index + 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityIdentifier("places.capitals")
            }
            .padding(.horizontal, gutter)
        }
    }

    private func capitalsSubtitle(_ count: Int) -> String {
        count == 1
            ? String(localized: "One district capital so far, with its own agent and AI map", bundle: .module)
            : String(localized: "The \(count) district capitals, each with its own agent and AI map", bundle: .module)
    }

    // MARK: Everything is connected

    private var connected: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "Everything is connected", bundle: .module),
                        subtitle: String(localized: "Towns joined where their AI maps name the same organisation. Tap a town.", bundle: .module))
            ConnectedTownsView(store: store)
        }
        .padding(.horizontal, gutter)
    }

    // MARK: Latest across the towns

    @ViewBuilder private var latestStories: some View {
        let latest = store.latestAcrossTowns(limit: wide ? 12 : 8)
        if !latest.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Latest from the towns", bundle: .module),
                            subtitle: String(localized: "Local AI news, each story with its source and the path to AI", bundle: .module))
                let columns = wide ? [GridItem(.flexible(), spacing: Space.l), GridItem(.flexible(), spacing: Space.l)] : [GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: Space.l) {
                    ForEach(latest, id: \.item.id) { entry in
                        StoryRow(item: entry.item, place: entry.place, accent: PlaceTheme.accent(store.file(entry.place.id), id: entry.place.id))
                    }
                }
            }
            .padding(.horizontal, gutter)
        }
    }

    // MARK: Work with us

    private var workWithUs: some View {
        WorkWithUsCard(compact: !wide).padding(.horizontal, gutter)
    }

    // MARK: The agents

    private var agentsStrip: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "The newsroom behind it", bundle: .module),
                        subtitle: String(localized: "One agent per place, and the team that builds, designs and checks. Powered by AgentiCCells.", bundle: .module))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(store.places.filter { !$0.agent.isEmpty }) { place in
                        NavigationLink(value: PlaceRoute(place.id)) {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle().fill(PlaceTheme.accent(store.file(place.id), id: place.id).gradient)
                                    Image(systemName: "face.smiling").font(.system(size: 28)).foregroundStyle(.white)
                                }
                                .frame(width: 56, height: 56)
                                .overlay(alignment: .bottomTrailing) {
                                    Circle().fill(place.isLive ? Palette.green : Palette.amber)
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Palette.paper, lineWidth: 2))
                                }
                                Text(place.name).font(.caption2.weight(.semibold)).lineLimit(1)
                                if let record = store.placeAgentStatus(place) {
                                    Text(PlaceDates.ago(record.updated)).font(.caption2).foregroundStyle(Palette.muted).lineLimit(1)
                                } else {
                                    Text(place.status).font(.caption2).foregroundStyle(Palette.muted)
                                }
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(String(localized: "\(store.places.filter { !$0.agent.isEmpty }.count) place agents, \(store.agentCount) agents in the whole newsroom. Open a place to see what its agent is doing now, from its own record.", bundle: .module))
                .font(.footnote).foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, gutter)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Rectangle().fill(Palette.rule).frame(height: 1)
            Text(String(localized: "Every fact on these pages comes from promptugal.news, with its source and the date it was read.", bundle: .module))
                .font(.caption).foregroundStyle(Palette.muted)
            Button {
                openURL(PlacesStore.site.appendingPathComponent("algarve/"))
            } label: {
                Label(String(localized: "Open promptugal.news/algarve", bundle: .module), systemImage: "safari")
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, gutter)
    }
}

// MARK: - The region map

/// The Algarve from above, each place a pin in its accent with its name; tapping one opens it.
struct RegionMap: View {
    let store: PlacesStore
    var interactive = true
    var selected: String?

    var body: some View {
        let center = CLLocationCoordinate2D(latitude: PlaceGeo.algarveCenter[1], longitude: PlaceGeo.algarveCenter[0])
        Map(initialPosition: .camera(MapCamera(centerCoordinate: center, distance: 210_000, heading: 0, pitch: 35)),
            interactionModes: interactive ? .all : []) {
            ForEach(pins) { pin in
                Annotation(pin.place.name, coordinate: pin.coordinate, anchor: .bottom) {
                    NavigationLink(value: PlaceRoute(pin.place.id)) {
                        TownPin(place: pin.place, accent: PlaceTheme.accent(store.file(pin.place.id), id: pin.place.id),
                                highlighted: selected == pin.place.id || PlacesHomeView.caseStudies.contains(pin.place.id))
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
    }

    private var pins: [Pin] {
        store.algarveTowns.compactMap { place in PlaceTheme.coordinate(place).map { Pin(place: place, coordinate: $0) } }
    }

    private struct Pin: Identifiable {
        let place: PlaceSummary
        let coordinate: CLLocationCoordinate2D
        var id: String { place.id }
    }
}

struct TownPin: View {
    let place: PlaceSummary
    let accent: Color
    var highlighted = false

    var body: some View {
        VStack(spacing: 2) {
            Text(place.name)
                .font(.system(size: highlighted ? 13 : 10, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(accent, in: Capsule())
                .foregroundStyle(.white)
                .shadow(radius: 2)
            Circle()
                .fill(.white)
                .frame(width: highlighted ? 12 : 8, height: highlighted ? 12 : 8)
                .overlay(Circle().fill(accent).padding(2))
        }
    }
}

// MARK: - Cards

/// A case study: a big aerial picture of the town, its name huge, its lead story and its numbers.
struct CaseStudyCard: View {
    let place: PlaceSummary
    let file: PlaceFile?

    var body: some View {
        let accent = PlaceTheme.accent(file, id: place.id)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                SatelliteView(place: place, pitch: 60, heading: place.id == "faro" ? 200 : 30)
                LinearGradient(colors: [.clear, accent.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Kicker(text: String(localized: "Case study", bundle: .module), color: .white.opacity(0.9))
                        StatusPill(status: place.status, onDark: true)
                    }
                    Text(place.name)
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                    if let landmark = file?.look?.landmark, !landmark.isEmpty {
                        Text(landmark).font(.footnote).foregroundStyle(.white.opacity(0.9)).lineLimit(2)
                    }
                }
                .padding(Space.l)
            }
            .frame(height: 280)
            .clipped()
            VStack(alignment: .leading, spacing: Space.s) {
                if let lead = file?.newsByWeight.first {
                    StepsBadge(steps: lead.steps, accent: accent)
                    Text(lead.title).font(Typo.storyTitle).foregroundStyle(Palette.ink).lineLimit(3)
                    Text(lead.summary).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(3)
                    if lead.isHeld {
                        ReadAtLine(outlet: lead.outlet, readOn: "", accent: accent, held: true)
                    }
                } else if let mandate = file?.mandate {
                    Text(mandate).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(4)
                }
                HStack(spacing: Space.xl) {
                    BigNumber(value: place.aiNews, label: String(localized: "AI stories", bundle: .module), accent: accent)
                    BigNumber(value: place.aiMap, label: String(localized: "AI map", bundle: .module), accent: accent)
                    BigNumber(value: file?.events.count ?? 0, label: String(localized: "Events", bundle: .module), accent: accent)
                }
                .padding(.top, Space.s)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).stroke(accent.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("places.case.\(place.id)")
    }
}

/// A town in the mosaic: its painted cover, name, landmark, status and counts.
struct TownTile: View {
    let place: PlaceSummary
    let file: PlaceFile?
    let seed: Int

    var body: some View {
        let accent = PlaceTheme.accent(file, id: place.id)
        ZStack(alignment: .bottomLeading) {
            AccentCover(accent: accent, seed: seed)
            Text(String(place.name.prefix(1)))
                .font(.system(size: 140, weight: .black, design: .serif))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 70, y: -30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                StatusPill(status: place.status, onDark: true)
                Spacer(minLength: 0)
                Text(place.name)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let landmark = file?.look?.landmark, !landmark.isEmpty {
                    Text(landmark).font(.caption2).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                }
                HStack(spacing: Space.m) {
                    Label("\(place.aiNews)", systemImage: "newspaper")
                    Label("\(place.aiMap)", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            }
            .padding(Space.m)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Space.radius))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("places.town.\(place.id)")
    }
}

/// A story as a tall tile (the national carousel).
struct StoryTile: View {
    let item: NewsItem
    let accent: Color
    let place: PlaceSummary?
    var subject: CommentSubject? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: item.url) { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Kicker(text: item.publisher.isEmpty ? String(localized: "Story", bundle: .module) : item.publisher, color: accent)
                    Spacer()
                    Text(PlaceDates.short(item.date)).font(.caption2).foregroundStyle(Palette.muted)
                }
                Text(item.title).font(Typo.story).foregroundStyle(Palette.ink).lineLimit(4)
                Text(PlacesTranslation.shared.text(item.summary)).font(.footnote).foregroundStyle(Palette.muted).lineLimit(5)
                Spacer(minLength: 0)
                if !item.isHeld { StepsBadge(steps: item.steps, accent: accent) }
                ReadAtLine(outlet: item.outlet, readOn: item.readOn, accent: accent, held: item.isHeld)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.card)
            .overlay(alignment: .top) { Rectangle().fill(accent).frame(height: 4) }
            .clipShape(RoundedRectangle(cornerRadius: Space.radius))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if let subject {
                HStack(spacing: Space.m) {
                    CommentButton(subject: subject, accent: accent, compact: true)
                    ThumbsBar(subject: subject, accent: accent)
                }
                .padding(Space.l)
            }
        }
    }
}

/// A story as a row with its town label in the town's colour (the latest list).
struct StoryRow: View {
    let item: NewsItem
    let place: PlaceSummary?
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: item.url) { openURL(url) }
        } label: {
            HStack(alignment: .top, spacing: Space.m) {
                Rectangle().fill(accent).frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let place {
                            Text(place.name)
                                .font(.caption2.weight(.heavy)).textCase(.uppercase)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(accent, in: Capsule()).foregroundStyle(.white)
                        }
                        Text([item.publisher, PlaceDates.age(item.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(Palette.muted)
                    }
                    Text(item.title).font(Typo.story).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                    if item.isHeld {
                        ReadAtLine(outlet: item.outlet, readOn: "", accent: accent, held: true)
                    } else {
                        if !item.aiPath.isEmpty {
                            Text(item.aiPath).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                        }
                        StepsBadge(steps: item.steps, accent: accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
    }
}

/// "Work with us" (Dinis, 15 Nov ~23:55): journalists, local media, bloggers, anyone making local content.
/// Opens promptugal.news/contribute/, or a signed comment with purpose "collaborate".
struct WorkWithUsCard: View {
    var compact = false
    @Environment(\.openURL) private var openURL
    static let contribute = URL(string: "https://promptugal.news/contribute/")!
    static let subject = CommentSubject(place: "algarve", title: String(localized: "Work with us", bundle: .module), item: "collaborate",
                                        page: contribute.absoluteString)

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m)) : AnyLayout(HStackLayout(alignment: .center, spacing: Space.xl))
        layout {
            VStack(alignment: .leading, spacing: Space.s) {
                Kicker(text: String(localized: "Work with us", bundle: .module), color: .white.opacity(0.85))
                Text(String(localized: "Make local news with us", bundle: .module))
                    .font(.system(.title, design: .serif, weight: .black))
                    .foregroundStyle(.white)
                Text(String(localized: "Journalists, local media, bloggers, anyone who makes content about their town: our agents research, you report, and readers come to you.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: Space.s) {
                Button {
                    openURL(Self.contribute)
                } label: {
                    Label(String(localized: "How to contribute", bundle: .module), systemImage: "hand.wave.fill").font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Palette.red)
                CommentButton(subject: Self.subject, accent: .white)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Palette.red, Palette.red.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Space.radius))
        .accessibilityIdentifier("places.workwithus")
    }
}
