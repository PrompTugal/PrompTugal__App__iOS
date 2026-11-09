import Foundation
import PTCore

/// The data behind "My program" (spec PROG-1): the person's picks for one day, in time order, with overlapping picks
/// grouped as a clash, the clashes listed with their overlap, and the free time between sessions. Only a busy pick
/// against a busy pick is a clash (`BusyRule`). Pure: picks, a day and the person's choices go in; the screen draws it.
public struct ProgramModel: Equatable, Sendable {
    public struct Day: Identifiable, Equatable, Sendable {
        public let id: String           // "2026-11-10"
        public let label: String
        public let count: Int           // picks on that day
    }

    /// Two busy picks that clash: they overlap, or the second starts before there is time to walk there
    /// (`travel`). The numbers are `DayPlanner.clashes`, the rule shared with Android and the web.
    public struct ClashPair: Identifiable, Equatable, Sendable {
        public let first: NowModel.Entry        // the one that starts first
        public let second: NowModel.Entry
        public let minutes: Int                 // overlap, or minutes short of the walk when `travel`
        public let travel: Bool
        /// The person chose "I'll split my time": a planned overlap, not an error.
        public let isSplit: Bool
        /// For a split: the second session's start minus the walk, as the shared rule says.
        public let leaveAt: Date?

        public var id: String { DayPlanner.splitKey(first.id, second.id) }

        /// Walking minutes between the two rooms (an estimate, from `DayPlanner.travelMinutes`).
        public var walkMinutes: Int { DayPlanner.travelMinutes(from: first.place, to: second.place) }

        /// The time they share (for an overlap).
        public var overlapStart: Date { max(first.start, second.start) }
        public var overlapEnd: Date { min(first.end, second.end) }

        /// What to show as "leave at": the shared rule's time, but never before the first session starts or
        /// after it ends.
        public var leaveAtForDisplay: Date {
            let leave = leaveAt ?? second.start.addingTimeInterval(-TimeInterval(walkMinutes * 60))
            return min(max(leave, first.start), first.end)
        }
    }

    /// Picks that overlap each other: the person has to choose one, or split their time.
    public struct ClashGroup: Identifiable, Equatable, Sendable {
        public let entries: [NowModel.Entry]
        public let pairs: [ClashPair]
        public var id: String { entries.first?.id ?? "" }

        /// The ids of the other picks in the group: what "Keep this one" removes.
        public func others(than id: String) -> [String] { entries.map(\.id).filter { $0 != id } }

        /// The clashes this session is in (for "clashes with <session>, 10:30 to 10:45").
        public func pairs(with id: String) -> [ClashPair] { pairs.filter { $0.first.id == id || $0.second.id == id } }

        /// True while at least one clash is still to be decided.
        public var needsChoice: Bool { pairs.contains { !$0.isSplit } }
    }

    public enum Row: Identifiable, Equatable, Sendable {
        case session(NowModel.Entry)
        case presence(NowModel.Entry)            // a pick that shows as free (registration, opening night, ...)
        case clash(ClashGroup)
        case free(start: Date, end: Date)

        public var id: String {
            switch self {
            case .session(let entry): return "s-" + entry.id
            case .presence(let entry): return "p-" + entry.id
            case .clash(let group): return "c-" + group.id
            case .free(let start, _): return "f-\(Int(start.timeIntervalSince1970))"
            }
        }

        var start: Date {
            switch self {
            case .session(let entry), .presence(let entry): return entry.start
            case .clash(let group): return group.entries.map(\.start).min() ?? .distantPast
            case .free(let start, _): return start
            }
        }
    }

    public static let summitDays = ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"]

    /// The key a split is kept under: the two schedule ids, sorted.
    public static func splitKey(_ a: String, _ b: String) -> String { DayPlanner.splitKey(a, b) }

    public let days: [Day]
    public let day: String
    public let rows: [Row]
    public let pickCount: Int
    public var isEmpty: Bool { pickCount == 0 }
    /// Picks on the selected day, for "Add to Calendar".
    public let dayEntries: [NowModel.Entry]
    /// Every clash of the day by start, for the tap-to-jump list at the top.
    public let clashes: [ClashPair]
    /// How each pick of the day shows (busy or free), by schedule id.
    public let showsAs: [String: ShowsAs]
    public var unresolvedClashes: [ClashPair] { clashes.filter { !$0.isSplit } }

    /// The clashes a session is in (overlap or too little time to walk), for "clashes with <session>, 10:30 to 10:45".
    public func clashes(with id: String) -> [ClashPair] { clashes.filter { $0.first.id == id || $0.second.id == id } }

    /// - Parameters:
    ///   - toggled: the person's own busy or free choice by schedule id (wins over everything).
    ///   - feed: the events JSON's `shows_as` by schedule id, when it has one.
    ///   - splits: the clashes the person chose to split, by `splitKey`.
    public init(picks: [SchedulePick], day: String, minimumGapMinutes: Int = 30,
                toggled: [String: ShowsAs] = [:], feed: (String) -> ShowsAs? = { _ in nil },
                splits: Set<String> = []) {
        let all = picks.compactMap { pick in
            pick.event.flatMap { NowModel.entry($0, pickedIDs: [pick.id], forced: true) }
        }
        pickCount = picks.count
        self.day = day

        var counts: [String: Int] = [:]
        for entry in all { counts[Lisbon.day(entry.start), default: 0] += 1 }
        let ids = Array(Set(Self.summitDays).union(counts.keys)).sorted()
        days = ids.map { Day(id: $0, label: Self.shortLabel($0), count: counts[$0] ?? 0) }

        let mine = all.filter { Lisbon.day($0.start) == day }.sorted(by: NowModel.soonest)
        dayEntries = mine

        // The pick's own copy of the event carries the feed's `shows_as`; the app's hook is the second source.
        var eventFeed: [String: ShowsAs] = [:]
        for pick in picks { if let value = pick.event?.showsAs.flatMap(ShowsAs.init(rawValue:)) { eventFeed[pick.id] = value } }
        var shows: [String: ShowsAs] = [:]
        for entry in mine {
            shows[entry.id] = BusyRule.resolve(entry, toggled: toggled[entry.id], feed: eventFeed[entry.id] ?? feed(entry.id))
        }
        showsAs = shows
        let busy = mine.filter { shows[$0.id] == .busy }
        let presence = mine.filter { shows[$0.id] == .free }

        // Clusters of overlapping busy picks.
        var clusters: [[NowModel.Entry]] = []
        var clusterEnd = Date.distantPast
        for entry in busy {
            if !clusters.isEmpty, entry.start < clusterEnd {
                clusters[clusters.count - 1].append(entry)
                clusterEnd = max(clusterEnd, entry.end)
            } else {
                clusters.append([entry])
                clusterEnd = entry.end
            }
        }

        // The shared clash rule on the busy picks (sorted by start, then id): overlaps and too-short walks.
        let byID = Dictionary(busy.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let items = busy.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }.map {
            DayPlanner.Item(id: $0.id, kind: .pick, title: $0.title, start: $0.start, end: $0.end, place: $0.place, eventID: $0.id)
        }
        let overlapPairs: [ClashPair] = DayPlanner.clashes(in: items, splits: splits).compactMap { clash in
            guard let first = byID[clash.first.id], let second = byID[clash.second.id] else { return nil }
            return ClashPair(first: first, second: second, minutes: clash.minutes, travel: clash.travel,
                             isSplit: clash.split, leaveAt: clash.leaveAt)
        }
        var rows: [Row] = []
        var previousEnd: Date?
        let gap = TimeInterval(minimumGapMinutes * 60)
        for cluster in clusters {
            let start = cluster.map(\.start).min() ?? .distantPast
            if let previousEnd, start.timeIntervalSince(previousEnd) >= gap {
                rows.append(.free(start: previousEnd, end: start))
            }
            if cluster.count == 1, let only = cluster.first {
                rows.append(.session(only))
            } else {
                let members = Set(cluster.map(\.id))
                let pairs = overlapPairs.filter { !$0.travel && members.contains($0.first.id) && members.contains($0.second.id) }
                rows.append(.clash(ClashGroup(entries: cluster, pairs: pairs)))
            }
            previousEnd = cluster.map(\.end).max()
        }
        // Free picks sit in time order among the rows, and never fill a gap or make a clash.
        for entry in presence {
            let index = rows.firstIndex { $0.start > entry.start } ?? rows.count
            rows.insert(.presence(entry), at: index)
        }
        self.rows = rows
        clashes = overlapPairs.sorted { $0.second.start < $1.second.start }
    }

    /// A short chip label for a day: the weekday and the day number in the person's language ("Tue 10", "ter. 10"),
    /// from a DateFormatter template so the order and punctuation follow the locale. Lisbon time.
    public static func shortLabel(_ day: String, locale: Locale = AppCulture.locale) -> String {
        guard let date = Lisbon.instant(day: day) else { return day }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = Lisbon.zone
        formatter.calendar = Lisbon.calendar
        formatter.setLocalizedDateFormatFromTemplate("EEEd")
        return formatter.string(from: date)
    }

    /// Which day to open on: today during the summit; otherwise the first day with picks (Tuesday when there are
    /// none, the first full day).
    public static func defaultDay(picks: [SchedulePick], now: Date) -> String {
        let today = Lisbon.day(now)
        if summitDays.contains(today) { return today }
        let pickDays = picks.compactMap { $0.start.map { Lisbon.day($0) } }.sorted()
        return pickDays.first ?? "2026-11-10"
    }
}
