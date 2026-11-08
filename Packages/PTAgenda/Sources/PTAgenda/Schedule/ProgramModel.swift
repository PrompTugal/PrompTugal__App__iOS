import Foundation
import PTCore

/// The data behind "My program" (spec PROG-1): the person's picks for one day, in time order, with overlapping picks
/// grouped as a clash and the free time between sessions. Pure: picks, a day and a time go in; the screen draws it.
public struct ProgramModel: Equatable, Sendable {
    public struct Day: Identifiable, Equatable, Sendable {
        public let id: String           // "2026-11-10"
        public let label: String
        public let count: Int           // picks on that day
    }

    /// Picks that overlap each other: the person has to choose one.
    public struct ClashGroup: Identifiable, Equatable, Sendable {
        public let entries: [NowModel.Entry]
        public var id: String { entries.first?.id ?? "" }

        /// The ids of the other picks in the group: what "Keep this one" removes.
        public func others(than id: String) -> [String] { entries.map(\.id).filter { $0 != id } }
    }

    public enum Row: Identifiable, Equatable, Sendable {
        case session(NowModel.Entry)
        case clash(ClashGroup)
        case free(start: Date, end: Date)

        public var id: String {
            switch self {
            case .session(let entry): return "s-" + entry.id
            case .clash(let group): return "c-" + group.id
            case .free(let start, _): return "f-\(Int(start.timeIntervalSince1970))"
            }
        }
    }

    public static let summitDays = ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"]

    public let days: [Day]
    public let day: String
    public let rows: [Row]
    public let pickCount: Int
    public var isEmpty: Bool { pickCount == 0 }
    /// Picks on the selected day, for "Add to Calendar".
    public let dayEntries: [NowModel.Entry]

    public init(picks: [SchedulePick], day: String, minimumGapMinutes: Int = 30) {
        let all = picks.compactMap { pick in
            pick.event.flatMap { NowModel.entry($0, pickedIDs: [pick.id], forced: true) }
        }
        pickCount = picks.count
        self.day = day

        var counts: [String: Int] = [:]
        for entry in all { counts[Lisbon.day(entry.start), default: 0] += 1 }
        let ids = Array(Set(Self.summitDays).union(counts.keys)).sorted()
        days = ids.map { Day(id: $0, label: Lisbon.dayLabel($0), count: counts[$0] ?? 0) }

        let mine = all.filter { Lisbon.day($0.start) == day }.sorted(by: NowModel.soonest)
        dayEntries = mine

        var clusters: [[NowModel.Entry]] = []
        var clusterEnd = Date.distantPast
        for entry in mine {
            if !clusters.isEmpty, entry.start < clusterEnd {
                clusters[clusters.count - 1].append(entry)
                clusterEnd = max(clusterEnd, entry.end)
            } else {
                clusters.append([entry])
                clusterEnd = entry.end
            }
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
                rows.append(.clash(ClashGroup(entries: cluster)))
            }
            previousEnd = cluster.map(\.end).max()
        }
        self.rows = rows
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
