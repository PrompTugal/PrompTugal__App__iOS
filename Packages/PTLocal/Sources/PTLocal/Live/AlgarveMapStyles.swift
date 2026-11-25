import MapKit
import PTCore
import SwiftUI

// The Algarve map in switchable styles, as a standalone component: it takes the towns as plain values and calls back
// when one is tapped, so any reader (PTPlaces, the live newsroom) can host it with its own town pages.
//
//   AlgarveStyledMap(towns: towns) { id in open(id) }
//
// Styles: the flat map; a 3D flight over the terrain from town to town; a tile grid that keeps the region's shape with
// every town the same size; a cartogram where each town's circle grows with the chosen measure. Grid and cartogram
// share one view, so switching between them morphs town by town.

/// One town, as the map needs it.
public struct AlgarveMapTown: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let accentHex: String?
    public let live: Bool
    public let stories: Int
    public let mapped: Int
    /// When the town's agent last showed a sign of life, if known.
    public let agentLastSign: Date?
    public let agent: String?
    /// What the town's agent says it is doing, in its own words.
    public let agentLine: String?
    /// The town's newest story headline.
    public let latestStory: String?

    public init(id: String, name: String, latitude: Double, longitude: Double, accentHex: String?, live: Bool,
                stories: Int, mapped: Int = 0, agentLastSign: Date? = nil, agent: String? = nil,
                agentLine: String? = nil, latestStory: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.accentHex = accentHex
        self.live = live
        self.stories = stories
        self.mapped = mapped
        self.agentLastSign = agentLastSign
        self.agent = agent
        self.agentLine = agentLine
        self.latestStory = latestStory
    }

    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var accent: Color { accentHex.map { Color(hex: $0) } ?? Palette.stable(id) }

    /// The 17 towns from this package's store and the newsroom dashboard.
    @MainActor public static func fromLocalStore(_ store: LocalStore = .shared, now: Date = Date()) -> [AlgarveMapTown] {
        PlaceDirectory.towns.map { info in
            let site = store.site(info.id)
            let agent = store.dashboard?.agent(forPlace: info.id)
            let newest = site.map { StoryAgents.newest($0, limit: 1) }?.first
            return AlgarveMapTown(id: info.id, name: info.name, latitude: info.latitude, longitude: info.longitude,
                                  accentHex: site?.look?.accent, live: site?.isLive == true,
                                  stories: site?.aiNews.count ?? 0, mapped: site?.aiMap.count ?? 0,
                                  agentLastSign: agent?.lastSign(now: now), agent: agent?.handle,
                                  agentLine: agent?.state, latestStory: newest?.title)
        }
    }
}

public enum AlgarveMapStyle: String, CaseIterable, Identifiable, Sendable {
    case flat = "Map", flight = "3D", tiles = "Grid", bubbles = "Cartogram"
    public var id: Self { self }
    var symbol: String {
        switch self {
        case .flat: "map"
        case .flight: "airplane"
        case .tiles: "square.grid.3x3"
        case .bubbles: "circle.hexagongrid"
        }
    }
}

/// What the abstract maps size and colour by.
public enum AlgarveMetric: String, CaseIterable, Identifiable, Sendable {
    case stories = "Stories", mapped = "On the map", fresh = "Agent activity"
    public var id: Self { self }

    public func value(_ town: AlgarveMapTown, now: Date) -> Double {
        switch self {
        case .stories: Double(town.stories)
        case .mapped: Double(town.mapped)
        case .fresh:
            // 1 just now, falling to 0 after a day or with no sign of life.
            town.agentLastSign.map { max(0, 1 - now.timeIntervalSince($0) / 86_400) } ?? 0
        }
    }

    public func label(_ value: Double) -> String {
        switch self {
        case .stories, .mapped: return "\(Int(value))"
        case .fresh:
            guard value > 0 else { return "–" }
            let minutes = Int(((1 - value) * 24 * 60).rounded())
            return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
        }
    }

    var caption: String {
        switch self {
        case .stories: "Local AI stories on each town's site"
        case .mapped: "Organisations on each town's AI map"
        case .fresh: "How long since each town's agent showed a sign of life"
        }
    }
}

/// The style switcher over the four maps.
public struct AlgarveStyledMap: View {
    let towns: [AlgarveMapTown]
    let onOpen: (String) -> Void
    @AppStorage("live.mapStyle") private var styleRaw = AlgarveMapStyle.flight.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(towns: [AlgarveMapTown], onOpen: @escaping (String) -> Void = { _ in }) {
        self.towns = towns
        self.onOpen = onOpen
    }

    private var style: Binding<AlgarveMapStyle> {
        Binding { AlgarveMapStyle(rawValue: styleRaw) ?? .flat } set: { styleRaw = $0.rawValue }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Picker("Map style", selection: style.animation(reduceMotion ? nil : .spring(duration: 0.6))) {
                ForEach(AlgarveMapStyle.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            switch style.wrappedValue {
            case .flat: AlgarveFlatStyle(towns: towns, onOpen: onOpen)
            case .flight: AlgarveFlightMap(towns: towns, onOpen: onOpen)
            case .tiles, .bubbles: AlgarveAbstractMap(towns: towns, bubbles: style.wrappedValue == .bubbles, onOpen: onOpen)
            }
        }
    }
}

/// A town's mark on the real maps: filled when its site is live, a ring while it is researched, its stories inside.
struct TownMapDot: View {
    let town: AlgarveMapTown
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(town.live ? town.accent : Palette.card)
            Circle().strokeBorder(town.accent, lineWidth: 3)
            if town.stories > 0 {
                Text("\(town.stories)").font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(town.live ? Color.white : Palette.ink)
            }
        }
        .frame(width: size, height: size)
        .shadow(radius: 1.5)
        .accessibilityLabel("\(town.name): \(town.live ? "live" : "researching"), \(town.stories) stories")
    }
}

// MARK: - Flat

struct AlgarveFlatStyle: View {
    let towns: [AlgarveMapTown]
    let onOpen: (String) -> Void
    @State private var selected: String?

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.21, longitude: -8.15),
            span: MKCoordinateSpan(latitudeDelta: 0.75, longitudeDelta: 1.75))), selection: $selected) {
            ForEach(towns) { town in
                Annotation(town.name, coordinate: town.coordinate) { TownMapDot(town: town) }
                    .tag(town.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .onChange(of: selected) { _, id in
            if let id { onOpen(id); selected = nil }
        }
    }
}

// MARK: - 3D flight

/// The flight's order: the case-study towns first (Loulé, then Faro), then the rest west to east.
public enum AlgarveTour {
    public static let featured = ["loule", "faro"]

    public static func order(_ towns: [AlgarveMapTown], first: [String] = featured) -> [AlgarveMapTown] {
        let lead = first.compactMap { id in towns.first { $0.id == id } }
        let rest = towns.filter { !first.contains($0.id) }.sorted { $0.longitude < $1.longitude }
        return lead + rest
    }
}

/// The terrain in 3D (satellite imagery with realistic elevation), the camera pitched and flying from town to town,
/// west to east, pausing over each with its agent's latest. Reduce Motion: no tour, step with the buttons.
struct AlgarveFlightMap: View {
    let towns: [AlgarveMapTown]
    let onOpen: (String) -> Void
    @State private var index = 0
    @State private var playing = true
    @State private var position: MapCameraPosition = .camera(AlgarveFlightMap.overview)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let overview = MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 37.05, longitude: -8.15),
                                    distance: 140_000, heading: 0, pitch: 55)

    /// The case studies first, then west to east as the coast runs.
    private var tour: [AlgarveMapTown] { AlgarveTour.order(towns) }

    static func camera(for town: AlgarveMapTown, step: Int) -> MapCamera {
        // Look north over the town from the sea side, turning a little each stop so the hills move.
        MapCamera(centerCoordinate: town.coordinate, distance: 5_500,
                  heading: Double((step * 23) % 60) - 30, pitch: 68)
    }

    var body: some View {
        let tour = tour
        ZStack(alignment: .bottomLeading) {
            Map(position: $position) {
                ForEach(tour) { town in
                    Annotation(town.name, coordinate: town.coordinate) {
                        Button { onOpen(town.id) } label: { TownMapDot(town: town) }.buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls { MapCompass(); MapPitchToggle() }
            if !tour.isEmpty {
                caption(tour[index % tour.count]).padding(Space.m)
            }
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .overlay(alignment: .topTrailing) { controls(count: tour.count).padding(Space.m) }
        .task(id: playing && !reduceMotion) { await run() }
        .accessibilityElement(children: .contain)
    }

    private func run() async {
        guard playing, !reduceMotion, !towns.isEmpty else { return }
        while !Task.isCancelled {
            fly(to: index)
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            index = (index + 1) % max(1, towns.count)
        }
    }

    private func fly(to step: Int) {
        let tour = tour
        guard !tour.isEmpty else { return }
        let camera = Self.camera(for: tour[step % tour.count], step: step)
        if reduceMotion {
            position = .camera(camera)
        } else {
            withAnimation(.easeInOut(duration: 4.5)) { position = .camera(camera) }
        }
    }

    private func controls(count: Int) -> some View {
        HStack(spacing: Space.m) {
            Button { step(-1, count: count) } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous town")
            if !reduceMotion {
                Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }
                    .accessibilityLabel(playing ? "Pause the flight" : "Play the flight")
            }
            Button { step(1, count: count) } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next town")
        }
        .font(.footnote)
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func step(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        playing = false
        index = (index + delta + count) % count
        fly(to: index)
    }

    private func caption(_ town: AlgarveMapTown) -> some View {
        Button { onOpen(town.id) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.s) {
                    Text(town.name).font(.system(.title3, design: .serif, weight: .bold))
                    StatusChip(live: town.live)
                }
                Text("\(town.stories) stories · \(town.mapped) on the AI map").font(.caption.monospacedDigit())
                if let story = town.latestStory {
                    Label(story, systemImage: "newspaper")
                        .font(.system(.footnote, design: .serif, weight: .semibold))
                        .lineLimit(2)
                }
                if let line = town.agentLine {
                    Text(line).font(.caption).italic().lineLimit(2).foregroundStyle(Palette.muted)
                }
                if let agent = town.agent {
                    HStack(spacing: 4) {
                        Text(agent).font(.caption2.monospaced())
                        if let date = town.agentLastSign {
                            Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated)).font(.caption2)
                        }
                    }
                    .foregroundStyle(Palette.muted)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(Space.s)
            .frame(maxWidth: 320, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .id(town.id)
        .transition(.opacity)
        .animation(.easeInOut, value: town.id)
        .accessibilityLabel("Now over \(town.name), \(town.stories) stories. Opens the town.")
    }
}

// MARK: - Tile grid and cartogram

/// The towns as tiles on the region's shape, or as circles near their true places sized by the measure. One view for
/// both, so a style switch slides and grows each town from one form into the other.
struct AlgarveAbstractMap: View {
    let towns: [AlgarveMapTown]
    let bubbles: Bool
    let onOpen: (String) -> Void
    @State private var metric: AlgarveMetric = .stories
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Picker("Size and colour by", selection: $metric.animation(reduceMotion ? nil : .spring(duration: 0.5))) {
                ForEach(AlgarveMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            GeometryReader { proxy in
                let marks = layout(in: proxy.size)
                ZStack(alignment: .topLeading) {
                    if bubbles { sea(proxy.size) }
                    ForEach(marks, id: \.id) { mark in
                        Button { onOpen(mark.id) } label: { tile(mark) }
                            .buttonStyle(.plain)
                            .frame(width: mark.size.width, height: mark.size.height)
                            .position(mark.center)
                            .accessibilityLabel("\(mark.town.name): \(metric.rawValue) \(metric.label(mark.value)), \(mark.town.live ? "live" : "researching")")
                    }
                }
            }
            .frame(height: bubbles ? 260 : 210)
            legend
        }
        .padding(Space.m)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
    }

    struct Mark {
        var id: String { town.id }
        let town: AlgarveMapTown
        let center: CGPoint
        let size: CGSize
        let value: Double
        let intensity: Double
        let round: Bool
    }

    private func layout(in size: CGSize) -> [Mark] {
        let now = Date()
        let values = Dictionary(towns.map { ($0.id, metric.value($0, now: now)) }, uniquingKeysWith: { a, _ in a })
        let top = values.values.max() ?? 0
        func mark(_ town: AlgarveMapTown, center: CGPoint, size: CGSize, round: Bool) -> Mark {
            let value = values[town.id] ?? 0
            return Mark(town: town, center: center, size: size, value: value,
                        intensity: AlgarveCartogram.intensity(value, max: top), round: round)
        }
        let byID = Dictionary(towns.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if bubbles {
            // True proportions, centred in the box.
            let aspect = AlgarveCartogram.aspect
            let w = min(size.width, size.height * aspect), h = w / aspect
            let origin = CGPoint(x: (size.width - w) / 2, y: (size.height - h) / 2)
            let radii = AlgarveCartogram.radii(values, maxRadius: min(w, h) * 0.2, minRadius: 9)
            let start = towns.map { town -> AlgarveCartogram.Bubble in
                let u = AlgarveCartogram.unitPoint(latitude: town.latitude, longitude: town.longitude)
                let p = CGPoint(x: origin.x + u.x * w, y: origin.y + u.y * h)
                return AlgarveCartogram.Bubble(id: town.id, center: p, radius: radii[town.id] ?? 9, home: p)
            }
            let placed = AlgarveCartogram.dorling(start, bounds: CGRect(origin: .zero, size: size))
            return placed.compactMap { bubble in
                byID[bubble.id].map { mark($0, center: bubble.center, size: CGSize(width: bubble.radius * 2, height: bubble.radius * 2), round: true) }
            }
        }
        let cell = min(size.width / CGFloat(AlgarveCartogram.columns), size.height / CGFloat(AlgarveCartogram.rows))
        let gridW = cell * CGFloat(AlgarveCartogram.columns), gridH = cell * CGFloat(AlgarveCartogram.rows)
        let origin = CGPoint(x: (size.width - gridW) / 2, y: (size.height - gridH) / 2)
        return towns.compactMap { town in
            guard let at = AlgarveCartogram.tiles[town.id] else { return nil }
            let center = CGPoint(x: origin.x + (CGFloat(at.col) + 0.5) * cell, y: origin.y + (CGFloat(at.row) + 0.5) * cell)
            return mark(town, center: center, size: CGSize(width: cell - 4, height: cell - 4), round: false)
        }
    }

    @ViewBuilder
    private func tile(_ mark: Mark) -> some View {
        let shape = RoundedRectangle(cornerRadius: mark.round ? max(mark.size.width, 1) / 2 : 8, style: .continuous)
        let base = metric == .fresh ? Palette.green : Palette.blue
        ZStack {
            shape.fill(Palette.paper2)
            shape.fill(base.opacity(0.12 + 0.78 * mark.intensity))
            shape.strokeBorder(mark.town.live ? mark.town.accent : Palette.rule,
                               style: StrokeStyle(lineWidth: mark.town.live ? 2.5 : 1, dash: mark.town.live ? [] : [3, 2]))
            if mark.size.width >= 30 {
                VStack(spacing: 0) {
                    Text(Self.shortName(id: mark.id, name: mark.town.name))
                        .font(.system(size: min(13, mark.size.width / 3.2), weight: .bold))
                    Text(metric.label(mark.value))
                        .font(.system(size: min(11, mark.size.width / 4), weight: .medium).monospacedDigit())
                }
                .foregroundStyle(mark.intensity > 0.55 ? Color.white : Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(2)
            }
        }
        .contentShape(shape)
    }

    /// The names that do not fit a tile, as the region says them.
    static func shortName(id: String, name: String) -> String {
        switch id {
        case "vila-real-de-santo-antonio": "VRSA"
        case "sao-bras-de-alportel": "S. Brás"
        case "vila-do-bispo": "V. Bispo"
        case "castro-marim": "C. Marim"
        default: name
        }
    }

    private func sea(_ size: CGSize) -> some View {
        // The coast is south: a soft band at the bottom says so without drawing a coastline we do not have.
        LinearGradient(colors: [Color.clear, Palette.blue.opacity(0.08)], startPoint: .center, endPoint: .bottom)
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bubbles ? "Each circle sits near its town; its area is the measure." : "Every town the same size, placed to keep the region's shape.")
            Text("\(metric.caption). Solid ring: live site; dashed: still researching. Tap a town to open it.")
        }
        .font(.caption)
        .foregroundStyle(Palette.muted)
    }
}

// MARK: - The maps on their own

/// The Algarve map in all its styles on one screen, hosted in this package with its own town pages. The live
/// newsroom links here.
public struct AlgarveMapsView: View {
    @State private var store = LocalStore.shared
    @State private var opened: String?

    public init() {}

    public var body: some View {
        Page {
            ScreenHeader(kicker: "PrompTugal.news · the Algarve", title: "The towns, four ways",
                         summary: "The 17 places of the Algarve: on the map, in 3D over the terrain, as a grid that keeps the region's shape, and as a cartogram where each town grows with what its agent has found.")
            ProvenanceLabel(provenance: store.placeProvenance, phase: store.phase, readAt: store.placesReadAt)
            AlgarveStyledMap(towns: AlgarveMapTown.fromLocalStore(store)) { opened = $0 }
        }
        .navigationTitle("Algarve maps")
        .navigationDestination(item: $opened) { id in TownView(id: id) }
        .task {
            if !store.placeProvenance.isLive { await store.refreshPlaces() }
            if !store.dashboardProvenance.isLive { await store.refreshDashboard() }
        }
        .refreshable { await store.refreshAll() }
    }
}
