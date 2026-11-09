import PTAgenda
import PTCore
import PTLanes
import SwiftUI

// The redesign's shared pieces (Indi's brief v7, stages 2 to 4): places ("I'm at"), the day timeline, meetups.
// Places are words a person chooses, never GPS. They are shared with the team as sealed "location" messages in the
// team group (WS-203 messaging), so the server never sees them; until messaging is on, a place stays on this iPhone.

// MARK: Places

enum TeamPlace: String, CaseIterable, Identifiable, Codable {
    case stand, talk, hall, meeting, hotel, town, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stand: "At the stand"
        case .talk: "At a talk"
        case .hall: "In a hall"
        case .meeting: "In a meeting"
        case .hotel: "At the hotel"
        case .town: "In town"
        case .off: "Off"
        }
    }
    var short: String {
        switch self {
        case .stand: "Stand"
        case .talk: "Talk"
        case .hall: "Hall"
        case .meeting: "Meeting"
        case .hotel: "Hotel"
        case .town: "Town"
        case .off: "Off"
        }
    }
    var symbol: String {
        switch self {
        case .stand: "storefront"
        case .talk: "mic"
        case .hall: "building.2"
        case .meeting: "person.2"
        case .hotel: "bed.double"
        case .town: "map"
        case .off: "moon.zzz"
        }
    }
    var colour: Color {
        switch self {
        case .stand: Palette.green
        case .talk: Palette.blue
        case .hall: Palette.amber
        case .meeting: Palette.red
        case .hotel: .purple
        case .town: .teal
        case .off: Palette.muted
        }
    }
    /// The places shown as "I'm at" buttons (a meeting is set from Plan, not by hand).
    static let choosable: [TeamPlace] = [.stand, .talk, .hall, .hotel, .town, .off]
}

struct PlaceLine: Codable, Equatable {
    var place: TeamPlace
    var until: Date
    var at: Date
    var isFresh: Bool { Date.now.timeIntervalSince(at) < 3 * 3600 && until > .now }
    var isStale: Bool { Date.now.timeIntervalSince(at) > 12 * 3600 }
}

/// My place, and the team's places from the team group's location messages.
@MainActor @Observable
final class PlaceShare {
    static let shared = PlaceShare()
    private(set) var mine: PlaceLine?
    var lastShareNote: String?
    private let key = "place.mine.v1"

    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let m = try? JSONDecoder().decode(PlaceLine.self, from: d) { mine = m }
    }

    static let lengths: [(String, TimeInterval)] = [("30 min", 1_800), ("1 h", 3_600), ("2 h", 7_200), ("Rest of day", 0)]

    func set(_ place: TeamPlace, for seconds: TimeInterval, me: String?) {
        let until = seconds > 0 ? Date.now.addingTimeInterval(seconds) : Calendar.current.startOfDay(for: .now).addingTimeInterval(23 * 3600 + 59 * 60)
        let line = PlaceLine(place: place, until: until, at: .now)
        mine = line
        if let d = try? JSONEncoder().encode(line) { UserDefaults.standard.set(d, forKey: key) }
        guard let me else { return }
        let store = MessagesHub.store(for: me)
        guard store.isSwitchedOn else {
            lastShareNote = "Saved on this iPhone. The team sees it once messaging is switched on."
            return
        }
        Task {
            if store.directory == nil { await store.refreshDirectory() }
            let team = store.directory?.groups["team"] ?? []
            do {
                try await store.send(text: "\(place.rawValue)|\(MessageTime.now(until))", to: team, group: "team", kind: "location")
                lastShareNote = "The team now sees you: \(place.label.lowercased())."
            } catch {
                lastShareNote = "Saved here, not shared: \(error.localizedDescription)"
            }
        }
    }

    /// The latest place of each person, from "location" messages in the team group.
    func team(from store: MessageStore) -> [String: PlaceLine] {
        var out: [String: PlaceLine] = [:]
        for m in store.messages(in: MessageThread.group("team")) {
            guard case .chat(let c) = m, c.kind == "location" else { continue }
            let parts = c.text.split(separator: "|").map(String.init)
            guard let place = parts.first.flatMap(TeamPlace.init(rawValue:)),
                  let at = MessageTime.date(c.at) else { continue }
            let until = parts.count > 1 ? (MessageTime.date(parts[1]) ?? at.addingTimeInterval(3_600)) : at.addingTimeInterval(3_600)
            if (out[c.from]?.at ?? .distantPast) < at { out[c.from] = PlaceLine(place: place, until: until, at: at) }
        }
        return out
    }
}

/// "I'm at": a place, then how long. Two taps.
struct PlaceCard: View {
    let me: String?
    @State private var share = PlaceShare.shared
    @State private var length: TimeInterval = 3_600

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("I'M AT").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
            FlowRow {
                ForEach(TeamPlace.choosable) { p in
                    let on = share.mine?.place == p && (share.mine?.until ?? .distantPast) > .now
                    Button { share.set(p, for: length, me: me) } label: {
                        Label(p.short, systemImage: p.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, Space.m).frame(minHeight: 44)
                            .foregroundStyle(p.colour)
                            .background(p.colour.opacity(on ? 0.22 : 0.10), in: Capsule())
                            .overlay(Capsule().stroke(on ? p.colour : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("I'm \(p.label.lowercased())")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            HStack(spacing: Space.s) {
                ForEach(PlaceShare.lengths.indices, id: \.self) { i in
                    let (name, seconds) = PlaceShare.lengths[i]
                    Button(name) {
                        length = seconds
                        if let p = share.mine?.place { share.set(p, for: seconds, me: me) }
                    }
                    .font(.footnote.weight(length == seconds ? .bold : .regular))
                    .padding(.horizontal, Space.s).frame(minHeight: 36)
                    .background(length == seconds ? Palette.ink.opacity(0.12) : Palette.paper2, in: Capsule())
                    .buttonStyle(.plain)
                }
            }
            if let m = share.mine, m.until > .now {
                Text("\(m.place.label) until \(m.until.formatted(date: .omitted, time: .shortened))").font(Typo.meta).foregroundStyle(Palette.muted)
            }
            if let note = share.lastShareNote { Text(note).font(Typo.meta).foregroundStyle(Palette.muted) }
        }
        .padding(Space.l)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// A simple wrapping row of buttons.
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing; row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}

// MARK: Meetups (kept on this iPhone; told to the team by messaging and WhatsApp)

struct Meetup: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var what: String
    var place: String
    var start: Date
    var people: [String]
    var text: String { "\(what) at \(place), \(start.formatted(date: .omitted, time: .shortened))\(people.isEmpty ? "" : ". With " + people.joined(separator: ", "))." }
}

@MainActor @Observable
final class MeetupStore {
    static let shared = MeetupStore()
    private(set) var all: [Meetup] = []
    private let key = "meetups.v1"
    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let m = try? JSONDecoder().decode([Meetup].self, from: d) { all = m }
    }
    func add(_ m: Meetup) {
        all.append(m)
        all.removeAll { $0.start < Date.now.addingTimeInterval(-7 * 86_400) }
        if let d = try? JSONEncoder().encode(all) { UserDefaults.standard.set(d, forKey: key) }
    }
}

// MARK: The day as a timeline

struct DayRow: Identifiable {
    enum Kind { case standup, pick, meetup }
    let id: String
    let start: Date
    let title: String
    let detail: String
    let kind: Kind
    var url: URL? = nil

    var kindLabel: String { switch kind { case .standup: "Team"; case .pick: "Web Summit"; case .meetup: "Meetup" } }
    var colour: Color { switch kind { case .standup: Palette.red; case .pick: Palette.blue; case .meetup: .purple } }
}

enum DayRows {
    static let summitDays = ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"]

    @MainActor
    static func rows(day: String, schedule: ScheduleStore, team: (any AgendaTeamSource)?, planner: PlannerStore, me: String?) -> [DayRow] {
        var rows: [DayRow] = schedule.picks.compactMap { pick in
            guard let start = pick.start, Lisbon.day(start) == day else { return nil }
            let going = planner.teammates(for: pick.id)
            let detail = [pick.event?.place ?? "", going.isEmpty ? "" : "With \(going.joined(separator: ", "))"].filter { !$0.isEmpty }.joined(separator: " · ")
            return DayRow(id: "pick.\(pick.id)", start: start, title: pick.title, detail: detail, kind: .pick, url: pick.url)
        }
        if let me {
            rows += (team?.upcomingStandups(after: Date.now.addingTimeInterval(-24 * 3600)) ?? []).filter { Lisbon.day($0.at) == day }.map {
                DayRow(id: "standup.\($0.slot)", start: $0.at, title: "Team stand-up", detail: "Decide, not report · your briefing", kind: .standup, url: $0.briefingURL(for: me))
            }
        }
        rows += MeetupStore.shared.all.filter { Lisbon.day($0.start) == day }.map {
            DayRow(id: "meetup.\($0.id)", start: $0.start, title: $0.what, detail: [$0.place, $0.people.joined(separator: ", ")].filter { !$0.isEmpty }.joined(separator: " · "), kind: .meetup)
        }
        return rows.sorted { $0.start < $1.start }
    }

    static func shortLabel(_ day: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Europe/Lisbon")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day) else { return day }
        f.dateFormat = "EEE d"
        return f.string(from: d)
    }
}

/// A vertical line of the day's items, with a "Now" marker where it belongs.
struct DayTimeline: View {
    let rows: [DayRow]
    var nowLine: String? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty && nowLine == nil {
                Text("Nothing planned yet. Add a meetup or pick sessions.").font(Typo.meta).foregroundStyle(Palette.muted).padding(Space.l)
            }
            let now = Date.now
            let before = rows.filter { $0.start < now }, after = rows.filter { $0.start >= now }
            ForEach(before) { row($0, past: true) }
            if let nowLine {
                item(time: now.formatted(date: .omitted, time: .shortened), title: "Now", detail: nowLine, colour: Palette.red, filled: true, past: false, kind: nil)
            }
            ForEach(after) { row($0, past: false) }
        }
        .padding(.vertical, Space.s)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
    }

    func row(_ r: DayRow, past: Bool) -> some View {
        Button { if let u = r.url { openURL(u) } } label: {
            item(time: r.start.formatted(date: .omitted, time: .shortened), title: r.title, detail: r.detail, colour: r.colour, filled: false, past: past, kind: r.kindLabel)
        }
        .buttonStyle(.plain)
        .disabled(r.url == nil)
    }

    func item(time: String, title: String, detail: String, colour: Color, filled: Bool, past: Bool, kind: String?) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(spacing: 0) {
                Circle().fill(filled ? colour : Palette.card).overlay(Circle().stroke(colour, lineWidth: 3)).frame(width: 14, height: 14).padding(.top, 4)
                Rectangle().fill(Palette.rule).frame(width: 2).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(time).font(.subheadline.weight(.semibold)).monospacedDigit()
                    Text(title).font(.subheadline.weight(filled ? .bold : .regular)).lineLimit(2)
                }
                HStack(spacing: 4) {
                    if let kind { Text(kind).font(.caption.weight(.semibold)).foregroundStyle(colour) }
                    if !detail.isEmpty { Text((kind == nil ? "" : "· ") + detail).font(.caption).foregroundStyle(Palette.muted).lineLimit(2) }
                }
            }
            .padding(.bottom, Space.m)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
        .opacity(past ? 0.55 : 1)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// A teammate's circle: initials in their colour, with a dot for their place.
struct PlaceFace: View {
    let name: String
    let colour: String
    let place: PlaceLine?
    var size: CGFloat = 52

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Avatar(initials: name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased(),
                   colour: Color(teamHex: colour) ?? Palette.amber, size: size)
            if let p = place, !p.isStale {
                Circle().fill(p.place.colour).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Palette.card, lineWidth: 2))
                    .opacity(p.isFresh ? 1 : 0.4)
            }
        }
    }
}
