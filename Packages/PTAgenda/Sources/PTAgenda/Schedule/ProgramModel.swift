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

    /// Two busy picks that overlap, with the time they share.
    public struct ClashPair: Identifiable, Equatable, Sendable {
        public let first: NowModel.Entry        // the one that starts first
        public let second: NowModel.Entry
        public let overlapStart: Date
        public let overlapEnd: Date
        /// The person chose "I'll split my time": a planned overlap, not an error.
        public let isSplit: Bool

        public var id: String { ProgramModel.splitKey(first.id, second.id) }

        /// Walking minutes between the two rooms (an estimate, from `DayPlanner.travelMinutes`).
        public var walkMinutes: Int { DayPlanner.travelMinutes(from: first.place, to: second.place) }

        /// When to leave the first session to arrive at the second as it starts; never before the first starts or
        /// after it ends.
        public var leaveAt: Date {
            let leave = second.start.addingTimeInterval(-TimeInterval(walkMinutes * 60))
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
    public static func splitKey(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "|") }

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

        var shows: [String: ShowsAs] = [:]
        for entry in mine { shows[entry.id] = BusyRule.resolve(entry, toggled: toggled[entry.id], feed: feed(entry.id)) }
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

        var allPairs: [ClashPair] = []
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
                var pairs: [ClashPair] = []
                for (i, a) in cluster.enumerated() {
                    for b in cluster[(i + 1)...] where a.start < b.end && b.start < a.end {
                        pairs.append(ClashPair(first: a, second: b, overlapStart: max(a.start, b.start),
                                               overlapEnd: min(a.end, b.end),
                                               isSplit: splits.contains(Self.splitKey(a.id, b.id))))
                    }
                }
                allPairs += pairs
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
        clashes = allPairs.sorted { $0.overlapStart < $1.overlapStart }
    }

    /// A short chip label for a day: the weekday and the day number in the person's language ("Tue 10", "ter. 10"),
    /// from a DateFormatter template so the order and punctuation follow the locale. Lisbon time.
    public static func shortLabel(_ day: String, locale: Locale = .current) -> String {
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
