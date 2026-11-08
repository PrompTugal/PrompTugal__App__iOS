import Foundation
import PTCore

/// What is on now and what is next, for the whole venue and for my own program: the data behind the Now screen.
/// Pure (an agenda, my picks and a time go in; a snapshot comes out), so it is tested without a screen. The screen
/// calls `ReaderStore.nowBoard(at:)` from a one-minute timeline and draws the snapshot.
public enum NowBoard {
    /// One session, as the Now screen shows it.
    public struct Entry: Identifiable, Hashable, Sendable {
        public init(id: String, title: String, place: String, start: Date, end: Date, mine: Bool, url: URL?) {
            self.id = id
            self.title = title
            self.place = place
            self.start = start
            self.end = end
            self.mine = mine
            self.url = url
        }

        public let id: String           // the schedule id (the page's slug), the same id the picks use
        public let title: String
        public let place: String
        public let start: Date
        public let end: Date
        public let mine: Bool           // in my program
        public let url: URL?

        public func isLive(at now: Date) -> Bool { start <= now && now < end }

        /// Whole minutes until it starts, never negative; 0 when it has started.
        public func minutesUntilStart(from now: Date) -> Int { max(0, Int(start.timeIntervalSince(now) / 60)) }

        /// Whole minutes left while it runs, never negative.
        public func minutesLeft(at now: Date) -> Int { max(0, Int(end.timeIntervalSince(now) / 60)) }
    }

    /// Where the summit is, for the Now screen's headline when nothing is on.
    public enum Phase: Equatable, Sendable {
        case noAgenda                   // nothing is loaded yet
        case before(Date)               // the summit's first session starts at this time
        case live                       // a session is running now, or more start later today
        case between(Date)              // today's sessions are over; the next one starts at this time
        case ended                      // the summit's last session is over
    }

    /// One stage (or room): what runs there now and what is next.
    public struct Stage: Identifiable, Hashable, Sendable {
        public init(place: String, now: Entry?, next: Entry?) {
            self.place = place
            self.now = now
            self.next = next
        }

        public var id: String { place }
        public let place: String
        public let now: Entry?
        public let next: Entry?
    }

    public struct Snapshot: Equatable, Sendable {
        public init(at: Date, day: String, phase: Phase, venueNow: [Entry], venueNext: [Entry], mineNow: [Entry],
                    mineNext: [Entry], clashes: [DayPlanner.Clash], stages: [Stage]) {
            self.at = at
            self.day = day
            self.phase = phase
            self.venueNow = venueNow
            self.venueNext = venueNext
            self.mineNow = mineNow
            self.mineNext = mineNext
            self.clashes = clashes
            self.stages = stages
        }

        public let at: Date
        public let day: String                      // Lisbon day, "2026-11-10"
        public let phase: Phase
        public let venueNow: [Entry]                // running now, by start
        public let venueNext: [Entry]               // starting within the horizon, soonest first
        public let mineNow: [Entry]
        public let mineNext: [Entry]                // my picks starting within my horizon, soonest first
        public let clashes: [DayPlanner.Clash]      // among my picks that have not ended, soonest first
        public let stages: [Stage]                  // stages with something now or next: busy ones first

        /// The next pick that has not started, if any.
        public var nextMine: Entry? { mineNext.first }
    }

    /// The thirty minutes a session without an end time is taken to last (as the widgets do).
    static let defaultLength: TimeInterval = 30 * 60

    /// - Parameters:
    ///   - nextHorizon: how far ahead the venue's "next" looks.
    ///   - mineHorizon: how far ahead my "next" looks (a whole day by default, so tomorrow's first pick shows tonight).
    ///   - limit: the most entries in each list.
    public static func snapshot(agenda: [Event], picks: [SchedulePick], now: Date,
                                nextHorizon: TimeInterval = 3 * 3600, mineHorizon: TimeInterval = 24 * 3600,
                                limit: Int = 8) -> Snapshot {
        let pickedIDs = Set(picks.map(\.id))
        let venue = agenda.compactMap { entry($0, mine: pickedIDs) }
        // My program comes from the picks' own copy of each event, so it still shows when the agenda has not loaded.
        let mine = picks.compactMap { pick in pick.event.flatMap { entry($0, mine: [pick.id], forcedMine: true) } }

        func soonest(_ a: Entry, _ b: Entry) -> Bool { a.start == b.start ? a.title < b.title : a.start < b.start }
        let venueNow = venue.filter { $0.isLive(at: now) }.sorted(by: soonest)
        let venueNext = Array(venue.filter { $0.start > now && $0.start <= now.addingTimeInterval(nextHorizon) }
            .sorted(by: soonest).prefix(limit))
        let mineNow = mine.filter { $0.isLive(at: now) }.sorted(by: soonest)
        let mineNext = Array(mine.filter { $0.start > now && $0.start <= now.addingTimeInterval(mineHorizon) }
            .sorted(by: soonest).prefix(limit))

        let upcomingMine = mine.filter { $0.end > now && $0.start <= now.addingTimeInterval(mineHorizon) }.sorted(by: soonest)
        let clashes = DayPlanner.clashes(in: upcomingMine.map {
            DayPlanner.Item(id: "pick.\($0.id)", kind: .pick, title: $0.title, start: $0.start, end: $0.end,
                            place: $0.place, eventID: $0.id)
        })

        return Snapshot(at: now, day: Lisbon.day(now), phase: phase(venue, now: now), venueNow: venueNow,
                        venueNext: venueNext, mineNow: mineNow, mineNext: mineNext, clashes: clashes,
                        stages: stages(venue, now: now, horizon: nextHorizon))
    }

    // MARK: Pieces

    /// A session as an entry; nil when its time is not readable or it ends before it starts.
    private static func entry(_ event: Event, mine pickedIDs: Set<String>, forcedMine: Bool = false) -> Entry? {
        guard let start = event.start else { return nil }
        let end = event.end ?? start.addingTimeInterval(defaultLength)
        guard end > start else { return nil }
        let id = ScheduleID.fromPage(event.page) ?? event.page
        return Entry(id: id, title: event.title, place: event.place, start: start, end: end,
                     mine: forcedMine || pickedIDs.contains(id), url: event.url)
    }

    private static func phase(_ entries: [Entry], now: Date) -> Phase {
        guard let first = entries.map(\.start).min(), let last = entries.map(\.end).max() else { return .noAgenda }
        if now < first { return .before(first) }
        if now >= last { return .ended }
        let today = Lisbon.day(now)
        if entries.contains(where: { $0.isLive(at: now) || ($0.start > now && Lisbon.day($0.start) == today) }) { return .live }
        let next = entries.map(\.start).filter { $0 > now }.min() ?? last
        return .between(next)
    }

    private static func stages(_ entries: [Entry], now: Date, horizon: TimeInterval) -> [Stage] {
        let horizonEnd = now.addingTimeInterval(horizon)
        var live: [String: Entry] = [:]
        var next: [String: Entry] = [:]
        for entry in entries where !entry.place.isEmpty {
            if entry.isLive(at: now) {
                if live[entry.place].map({ entry.start < $0.start }) ?? true { live[entry.place] = entry }
            } else if entry.start > now, entry.start <= horizonEnd {
                if next[entry.place].map({ entry.start < $0.start }) ?? true { next[entry.place] = entry }
            }
        }
        return Set(live.keys).union(next.keys).map { Stage(place: $0, now: live[$0], next: next[$0]) }
            .sorted { lhs, rhs in
                if (lhs.now != nil) != (rhs.now != nil) { return lhs.now != nil }
                return lhs.place.localizedStandardCompare(rhs.place) == .orderedAscending
            }
    }
}
