import Foundation
import CoreGraphics
import SwiftUI
import PTCore

/// The summit venue as a stylised map: outlines of the halls, the arena and the landmarks, from OpenStreetMap
/// (© OpenStreetMap contributors, ODbL 1.0), simplified into a 1000 by 861 frame (`Resources/venues/venue-map.json`,
/// see `SOURCE` there). No coordinates of the person and no CoreLocation: the map only places the sessions they picked.
public struct VenueMap: Sendable {
    public struct Frame: Decodable, Sendable {
        public let width: Double
        public let height: Double
    }

    public struct Area: Decodable, Identifiable, Sendable {
        public let id: String               // "osm-821784762"
        public let label: String            // "MEO Arena"
        public let kind: String             // site, hall, arena, landmark, station
        public let d: String                // SVG path in frame units: M, L and Z only
        public let c: [Double]              // the label point
        public let osm: String?

        public var labelPoint: CGPoint { CGPoint(x: c.first ?? 0, y: c.last ?? 0) }
    }

    public struct Street: Decodable, Sendable {
        public let name: String
        public let short: String?
        public let d: String
    }

    public let frame: Frame
    public let areas: [Area]
    public let streets: [Street]
    public let river: String

    private struct File: Decodable {
        let frame: Frame
        let areas: [Area]
        let streets: [Street]
        let river: String
    }

    public static let attribution = "© OpenStreetMap contributors"
    public static let attributionURL = URL(string: "https://www.openstreetmap.org/copyright")!

    public static func decode(_ data: Data) throws -> VenueMap {
        let file = try JSONDecoder().decode(File.self, from: data)
        return VenueMap(frame: file.frame, areas: file.areas, streets: file.streets, river: file.river)
    }

    /// The map built into the app; nil only if the resource is missing.
    public static let shared: VenueMap? = {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "venue-map", withExtension: "json", subdirectory: "venues")
                ?? bundle.url(forResource: "venue-map", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }()

    // MARK: Places on the map

    /// The area an event is in. The earliest area named in `where` and `place` wins ("Masterclass 1, MEO Arena and
    /// FIL" is the arena); with no area named, Centre Stage is the arena and any other room of the summit is the
    /// venue site (FIL), because the agenda does not say which hall. Nil for anywhere else (the airport, a bar).
    public func area(forPlace place: String, where whereText: String? = nil) -> Area? {
        let text = [whereText, place].compactMap { $0 }.joined(separator: ", ").lowercased()
        var best: (area: Area, at: Int)?
        for area in areas {
            guard let at = Self.firstWordMatch(of: area.label.lowercased(), in: text) else { continue }
            if best == nil || at < best!.at { best = (area, at) }
        }
        if let best { return best.area }
        if text.contains("centre stage") { return areas.first { $0.label == "MEO Arena" } }
        if DayPlanner.isSummitVenue(text) { return areas.first { $0.kind == "site" } }
        return nil
    }

    /// Where `needle` first appears in `text` as a whole word (so "fil" is not "film"); nil if it does not.
    static func firstWordMatch(of needle: String, in text: String) -> Int? {
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: needle) + "(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return match.range.location
    }
}

/// An SVG path as the map uses it: absolute M, L and Z only.
public enum SVGPathData {
    public enum Command: Equatable, Sendable {
        case move(CGPoint), line(CGPoint), close
    }

    public static func commands(_ d: String) -> [Command] {
        var commands: [Command] = []
        var command: Character?
        var numbers: [Double] = []
        var buffer = ""

        func flushNumber() {
            if let value = Double(buffer) { numbers.append(value) }
            buffer = ""
        }
        func flushCommand() {
            flushNumber()
            defer { numbers = [] }
            switch command {
            case "M": if numbers.count >= 2 { commands.append(.move(CGPoint(x: numbers[0], y: numbers[1]))) }
            case "L": if numbers.count >= 2 { commands.append(.line(CGPoint(x: numbers[0], y: numbers[1]))) }
            case "Z": commands.append(.close)
            default: break
            }
        }

        for char in d {
            if char.isLetter {
                flushCommand()
                command = char
            } else if char == "-" {
                flushNumber()
                buffer.append(char)
            } else if char.isNumber || char == "." {
                buffer.append(char)
            } else {
                flushNumber()
            }
        }
        flushCommand()
        return commands
    }

    public static func path(_ d: String) -> Path {
        var path = Path()
        for command in commands(d) {
            switch command {
            case .move(let p): path.move(to: p)
            case .line(let p): path.addLine(to: p)
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

/// What the map shows for the day's picks: which area each is in, and the walks of `WhereToBe` between areas. Pure.
public struct VenueMapModel: Equatable, Sendable {
    public struct Pin: Identifiable, Equatable, Sendable {
        public let areaID: String
        public let label: String
        public let point: CGPoint
        public let entries: [NowModel.Entry]
        /// True when one of them is where the person is now or must be in the next 20 minutes.
        public let isActive: Bool
        public var id: String { areaID }
    }

    public struct Walk: Identifiable, Equatable, Sendable {
        public let fromAreaID: String
        public let toAreaID: String
        public let minutes: Int
        public let toTitle: String
        public var id: String { fromAreaID + ">" + toAreaID + ">" + toTitle }
    }

    public let pins: [Pin]
    public let unplaced: [NowModel.Entry]     // picks that are not on the map (the airport, a bar in town)
    public let walks: [Walk]

    public init(map: VenueMap, picks: [SchedulePick], now: Date, toggled: [String: ShowsAs] = [:],
                feed: (String) -> ShowsAs? = { _ in nil }) {
        let today = Lisbon.day(now)
        let entries = picks.compactMap { pick -> NowModel.Entry? in
            guard let event = pick.event, event.date == today else { return nil }
            return NowModel.entry(event, pickedIDs: [pick.id], forced: true)
        }.sorted(by: NowModel.soonest)
        let whereToBe = WhereToBe(picks: picks, now: now, toggled: toggled, feed: feed)
        let activeIDs = Set(([whereToBe.current].compactMap { $0 } + whereToBe.legs.map(\.entry)).map(\.id))

        var byArea: [String: [NowModel.Entry]] = [:]
        var unplaced: [NowModel.Entry] = []
        for entry in entries {
            if let area = map.area(forPlace: entry.place) { byArea[area.id, default: []].append(entry) } else { unplaced.append(entry) }
        }
        self.unplaced = unplaced
        pins = map.areas.compactMap { area in
            guard let list = byArea[area.id] else { return nil }
            return Pin(areaID: area.id, label: area.label, point: area.labelPoint, entries: list,
                       isActive: list.contains { activeIDs.contains($0.id) })
        }
        walks = whereToBe.legs.compactMap { leg in
            guard let from = leg.from, let a = map.area(forPlace: from.place), let b = map.area(forPlace: leg.entry.place),
                  a.id != b.id else { return nil }
            return Walk(fromAreaID: a.id, toAreaID: b.id, minutes: leg.walkMinutes, toTitle: leg.entry.title)
        }
    }
}

/// The venue map with today's picks on it, the walks to the next places, the "where I need to be" card, and the
/// same information as a list (for VoiceOver). Needs the `ScheduleStore` in the environment.
public struct VenueMapView: View {
    public init() {}

    @Environment(ScheduleStore.self) private var schedule
    @State private var choices = PlanChoices.shared

    public var body: some View {
        TimelineView(.everyMinute) { _ in
            let now = AgendaClock.now
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    WhereToBeCard()
                    if let map = VenueMap.shared {
                        let model = VenueMapModel(map: map, picks: schedule.picks, now: now, toggled: choices.toggled,
                                                  feed: AgendaHub.showsAs)
                        mapView(map, model)
                        list(model)
                    }
                }
                .padding(Space.m)
            }
        }
        .navigationTitle(String(localized: "Venue map", bundle: .module))
    }

    private func mapView(_ map: VenueMap, _ model: VenueMapModel) -> some View {
        let aspect = map.frame.width / map.frame.height
        let pins = Dictionary(uniqueKeysWithValues: model.pins.map { ($0.areaID, $0) })
        let centres = Dictionary(uniqueKeysWithValues: map.areas.map { ($0.id, $0.labelPoint) })
        return VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { proxy in
                let scale = proxy.size.width / map.frame.width
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        context.scaleBy(x: scale, y: scale)
                        context.fill(SVGPathData.path(map.river), with: .color(.blue.opacity(0.12)))
                        for street in map.streets {
                            context.stroke(SVGPathData.path(street.d), with: .color(Palette.muted.opacity(0.5)), lineWidth: 1.5)
                        }
                        for area in map.areas {
                            let path = SVGPathData.path(area.d)
                            let pin = pins[area.id]
                            context.fill(path, with: .color(pin == nil ? Palette.card : Palette.red.opacity(pin?.isActive == true ? 0.35 : 0.18)))
                            context.stroke(path, with: .color(Palette.muted), lineWidth: 1.2)
                        }
                        for walk in model.walks {
                            guard let a = centres[walk.fromAreaID], let b = centres[walk.toAreaID] else { continue }
                            var line = Path()
                            line.move(to: a)
                            line.addLine(to: b)
                            context.stroke(line, with: .color(Palette.red), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        }
                    }
                    ForEach(map.areas) { area in
                        Text(area.label).font(.caption2.bold()).foregroundStyle(Palette.ink)
                            .position(x: area.labelPoint.x * scale, y: area.labelPoint.y * scale)
                    }
                    ForEach(model.pins) { pin in
                        Text("\(pin.entries.count)").font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Circle().fill(Palette.red))
                            .position(x: pin.point.x * scale, y: pin.point.y * scale - 16)
                    }
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .accessibilityHidden(true)             // the list below says the same
            Link(VenueMap.attribution, destination: VenueMap.attributionURL).font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private func list(_ model: VenueMapModel) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(model.pins) { pin in
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.label).font(.headline).foregroundStyle(Palette.ink)
                    ForEach(pin.entries) { entry in
                        Text("\(clock(entry.start)) · \(entry.title)").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if !model.unplaced.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Not on the map", bundle: .module)).font(.headline).foregroundStyle(Palette.ink)
                    ForEach(model.unplaced) { entry in
                        Text("\(clock(entry.start)) · \(entry.title) · \(entry.place)").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if model.pins.isEmpty && model.unplaced.isEmpty {
                Text(String(localized: "No picks for today yet.", bundle: .module)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func clock(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Lisbon.zone))
    }
}
