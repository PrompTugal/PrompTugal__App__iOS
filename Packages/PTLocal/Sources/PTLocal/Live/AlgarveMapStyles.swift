import MapKit
import PTCore
import SwiftUI

/// The Algarve map, in switchable styles: the flat map, a 3D flight over the terrain from town to town, a tile grid
/// that keeps the region's shape with every town the same size, and a cartogram where each town's circle grows with
/// what its agent has found. The abstract two share one view, so switching between them morphs town by town.
enum AlgarveMapStyle: String, CaseIterable, Identifiable {
    case flat = "Map", flight = "3D", tiles = "Grid", bubbles = "Cartogram"
    var id: Self { self }
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
enum AlgarveMetric: String, CaseIterable, Identifiable {
    case stories = "Stories", mapped = "On the map", fresh = "Agent activity"
    var id: Self { self }

    func value(_ site: PlaceSite?, agent: NewsroomDashboard.Agent?, now: Date) -> Double {
        switch self {
        case .stories: Double(site?.aiNews.count ?? 0)
        case .mapped: Double(site?.aiMap.count ?? 0)
        case .fresh:
            // Hours of quiet turned into a score: 1 just now, 0 after a day or with no sign of life.
            agent?.lastSign(now: now).map { max(0, 1 - now.timeIntervalSince($0) / 86_400) } ?? 0
        }
    }

    func label(_ value: Double) -> String {
        switch self {
        case .stories, .mapped: "\(Int(value))"
        case .fresh: value > 0 ? "\(Int((1 - value) * 24 * 60)) min" : "–"
        }
    }

    var caption: String {
        switch self {
        case .stories: "Local AI stories on each town's site"
        case .mapped: "Organisations on each town's AI map"
        case .fresh: "How recently each town's agent showed a sign of life (minutes ago)"
        }
    }
}

/// The map card on the Algarve page: a style switcher over the four maps.
struct AlgarveMap: View {
    let store: LocalStore
    @AppStorage("local.mapStyle") private var styleRaw = AlgarveMapStyle.flat.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: Binding<AlgarveMapStyle> {
        Binding { AlgarveMapStyle(rawValue: styleRaw) ?? .flat } set: { styleRaw = $0.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Picker("Map style", selection: style.animation(reduceMotion ? nil : .spring(duration: 0.6))) {
                ForEach(AlgarveMapStyle.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            switch style.wrappedValue {
            case .flat: AlgarveFlatMap(store: store)
            case .flight: AlgarveFlightMap(store: store)
            case .tiles, .bubbles: AlgarveAbstractMap(store: store, bubbles: style.wrappedValue == .bubbles)
            }
        }
    }
}

// MARK: - 3D flight

/// The terrain in 3D (satellite imagery with realistic elevation), the camera pitched and flying from town to town,
/// west to east, pausing over each with its agent's latest. Reduce Motion: no tour, step with the buttons.
struct AlgarveFlightMap: View {
    let store: LocalStore
    @State private var index = 0
    @State private var playing = true
    @State private var position: MapCameraPosition = .camera(AlgarveFlightMap.overview)
    @State private var opened: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// West to east, as the coast runs.
    static let tour: [PlaceInfo] = PlaceDirectory.towns.sorted { $0.longitude < $1.longitude }

    static let overview = MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 37.05, longitude: -8.15),
                                    distance: 140_000, heading: 0, pitch: 55)

    static func camera(for town: PlaceInfo, step: Int) -> MapCamera {
        // Look north over the town from the sea side, turning a little each stop so the hills move.
        MapCamera(centerCoordinate: town.coordinate, distance: 5_500,
                  heading: Double((step * 23) % 60) - 30, pitch: 68)
    }

    var body: some View {
        let town = Self.tour[index % Self.tour.count]
        let site = store.site(town.id)
        Card(padding: 0) {
            ZStack(alignment: .bottomLeading) {
                Map(position: $position) {
                    ForEach(Self.tour) { info in
                        let s = store.site(info.id)
                        Annotation(info.name, coordinate: info.coordinate) {
                            Button { opened = info.id } label: {
                                PlaceDot(accent: Color(hex: s?.look?.accent), live: s?.isLive == true, stories: s?.aiNews.count ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .mapControls { MapCompass(); MapPitchToggle() }
                caption(town: town, site: site)
                    .padding(Space.m)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        }
        .overlay(alignment: .topTrailing) { controls.padding(Space.m) }
        .navigationDestination(item: $opened) { id in TownView(id: id) }
        .task(id: playing && !reduceMotion) { await tour() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("3D flight over the Algarve, now over \(town.name)")
    }

    private func tour() async {
        guard playing, !reduceMotion else { return }
        while !Task.isCancelled {
            fly(to: index)
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            index = (index + 1) % Self.tour.count
        }
    }

    private func fly(to step: Int) {
        let camera = Self.camera(for: Self.tour[step % Self.tour.count], step: step)
        if reduceMotion {
            position = .camera(camera)
        } else {
            withAnimation(.easeInOut(duration: 4.5)) { position = .camera(camera) }
        }
    }

    private var controls: some View {
        HStack(spacing: Space.s) {
            Button { step(-1) } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous town")
            if !reduceMotion {
                Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }
                    .accessibilityLabel(playing ? "Pause the flight" : "Play the flight")
            }
            Button { step(1) } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next town")
        }
        .font(.footnote)
        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func step(_ delta: Int) {
        playing = false
        index = (index + delta + Self.tour.count) % Self.tour.count
        fly(to: index)
    }

    private func caption(town: PlaceInfo, site: PlaceSite?) -> some View {
        let agent = store.dashboard?.agent(forPlace: town.id)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.s) {
                Text(town.name).font(.headline)
                StatusChip(live: site?.isLive == true)
            }
            Text("\(site?.aiNews.count ?? 0) stories · \(site?.aiMap.count ?? 0) on the AI map")
                .font(.caption.monospacedDigit())
            if let agent {
                HStack(spacing: 4) {
                    StatusDot(status: agent.status)
                    Text(agent.handle).font(.caption2.monospaced())
                    if let date = agent.lastSign(now: .now) {
                        Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated)).font(.caption2)
                    }
                }
            } else if let landmark = site?.look?.landmark {
                Text(landmark).font(.caption2)
            }
        }
        .padding(Space.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .id(town.id)
        .transition(.opacity)
        .animation(.easeInOut, value: town.id)
    }
}

// MARK: - Tile grid and cartogram

/// The towns as tiles on the region's shape, or as circles at their true places sized by the metric. One view for
/// both, so a style switch slides and grows each town from one form into the other.
struct AlgarveAbstractMap: View {
    let store: LocalStore
    let bubbles: Bool
    @State private var metric: AlgarveMetric = .stories
    @State private var opened: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Card {
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
                            Button { opened = mark.id } label: { tile(mark) }
                                .buttonStyle(.plain)
                                .frame(width: mark.size.width, height: mark.size.height)
                                .position(mark.center)
                                .accessibilityLabel("\(mark.name): \(metric.rawValue) \(metric.label(mark.value)), \(mark.live ? "live" : "researching")")
                        }
                    }
                }
                .frame(height: bubbles ? 250 : 200)
                legend
            }
        }
        .navigationDestination(item: $opened) { id in TownView(id: id) }
    }

    struct Mark {
        let id: String
        let name: String
        let center: CGPoint
        let size: CGSize
        let value: Double
        let intensity: Double
        let live: Bool
        let accent: Color
        let round: Bool
    }

    private func values(now: Date) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: PlaceDirectory.towns.map { info in
            (info.id, metric.value(store.site(info.id), agent: store.dashboard?.agent(forPlace: info.id), now: now))
        })
    }

    private func layout(in size: CGSize) -> [Mark] {
        let now = Date()
        let values = values(now: now)
        let top = values.values.max() ?? 0
        func mark(_ info: PlaceInfo, center: CGPoint, size: CGSize, round: Bool) -> Mark {
            let site = store.site(info.id)
            let value = values[info.id] ?? 0
            return Mark(id: info.id, name: info.name, center: center, size: size, value: value,
                        intensity: AlgarveCartogram.intensity(value, max: top), live: site?.isLive == true,
                        accent: Color(hex: site?.look?.accent), round: round)
        }
        if bubbles {
            // True proportions, centred in the box.
            let aspect = AlgarveCartogram.aspect
            let w = min(size.width, size.height * aspect), h = w / aspect
            let origin = CGPoint(x: (size.width - w) / 2, y: (size.height - h) / 2)
            let radii = AlgarveCartogram.radii(values, maxRadius: min(w, h) * 0.2, minRadius: 9)
            let start = PlaceDirectory.towns.map { info -> AlgarveCartogram.Bubble in
                let u = AlgarveCartogram.unitPoint(latitude: info.latitude, longitude: info.longitude)
                let p = CGPoint(x: origin.x + u.x * w, y: origin.y + u.y * h)
                return AlgarveCartogram.Bubble(id: info.id, center: p, radius: radii[info.id] ?? 9, home: p)
            }
            let placed = AlgarveCartogram.dorling(start, bounds: CGRect(origin: .zero, size: size))
            return placed.compactMap { bubble in
                guard let info = PlaceDirectory.info(bubble.id) else { return nil }
                return mark(info, center: bubble.center, size: CGSize(width: bubble.radius * 2, height: bubble.radius * 2), round: true)
            }
        }
        let cell = min(size.width / CGFloat(AlgarveCartogram.columns), size.height / CGFloat(AlgarveCartogram.rows))
        let gridW = cell * CGFloat(AlgarveCartogram.columns), gridH = cell * CGFloat(AlgarveCartogram.rows)
        let origin = CGPoint(x: (size.width - gridW) / 2, y: (size.height - gridH) / 2)
        return PlaceDirectory.towns.compactMap { info in
            guard let at = AlgarveCartogram.tiles[info.id] else { return nil }
            let center = CGPoint(x: origin.x + (CGFloat(at.col) + 0.5) * cell, y: origin.y + (CGFloat(at.row) + 0.5) * cell)
            return mark(info, center: center, size: CGSize(width: cell - 4, height: cell - 4), round: false)
        }
    }

    @ViewBuilder
    private func tile(_ mark: Mark) -> some View {
        let shape = RoundedRectangle(cornerRadius: mark.round ? max(mark.size.width, 1) / 2 : 8, style: .continuous)
        let base = metric == .fresh ? Palette.green : Palette.blue
        ZStack {
            shape.fill(Palette.paper2)
            shape.fill(base.opacity(0.12 + 0.78 * mark.intensity))
            shape.strokeBorder(mark.live ? mark.accent : Palette.rule, style: StrokeStyle(lineWidth: mark.live ? 2.5 : 1, dash: mark.live ? [] : [3, 2]))
            if mark.size.width >= 30 {
                VStack(spacing: 0) {
                    Text(Self.shortName(id: mark.id, name: mark.name)).font(.system(size: min(13, mark.size.width / 3.2), weight: .bold))
                    Text(metric.label(mark.value)).font(.system(size: min(11, mark.size.width / 4), weight: .medium).monospacedDigit())
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
            Text(bubbles ? "Each circle sits near its town; its area is the \(metric.rawValue.lowercased())." : "Every town the same size, placed to keep the region's shape.")
            Text("\(metric.caption). Solid ring: live site; dashed: still researching. Tap a town to open it.")
        }
        .font(.caption)
        .foregroundStyle(Palette.muted)
    }
}
