import Foundation
import PTCore

/// The data behind the Now screen (spec NOW-1): which phase the summit is in, what is next for the person, what is on
/// now at the venue, what starts within the hour, and what comes tomorrow. Pure: an agenda, the person's picks and a
/// time go in; the screen calls `ReaderStore.nowModel(at:)` from a one-minute timeline and draws the result.
///
/// Rules: times are Lisbon time; a session with no end time lasts 30 minutes (the widgets' rule); the person's own
/// program is built from the picks' own copy of each event, so it shows even before the agenda has loaded.
public struct NowModel: Equatable, Sendable {
    /// The summit's own days. A different range can be passed (tests do).
    public struct Summit: Equatable, Sendable {
        public init(opens: Date, closes: Date) {
            self.opens = opens
            self.closes = closes
        }

        /// Registration opens Monday 9 November 07:30; the last day ends at midnight, so 13 November is "after".
        public static let lisbon2026 = Summit(opens: Lisbon.instant(day: "2026-11-09", clock: "07:30")!,
                                              closes: Lisbon.instant(day: "2026-11-13", clock: "00:00")!)

        public let opens: Date
        public let closes: Date
    }

    public enum Phase: Equatable, Sendable {
        case before         // State A: the summit has not opened
        case during         // State B: a session is running, or more start today
        case between        // State B, between days: today's sessions are over
        case after          // State C
    }

    /// One session.
    public struct Entry: Identifiable, Hashable, Sendable {
        public init(id: String, title: String, place: String, start: Date, end: Date, mine: Bool, official: Bool, url: URL?,
                    kind: String = "") {
            self.kind = kind
            self.id = id
            self.title = title
            self.place = place
            self.start = start
            self.end = end
            self.mine = mine
            self.official = official
            self.url = url
        }

        public let id: String           // the schedule id (the page's slug), the same id the picks use
        public let title: String
        public let place: String
        public let start: Date
        public let end: Date
        public let mine: Bool           // in the person's program
        public let official: Bool
        public let url: URL?
        public let kind: String         // the event's kind: "registration" and "summit" are special on the Now screen

        public func isLive(at now: Date) -> Bool { start <= now && now < end }

        /// Whole minutes until it starts, never negative; 0 once it has started.
        public func minutesUntilStart(from now: Date) -> Int { max(0, Int(start.timeIntervalSince(now) / 60)) }

        /// Whole minutes left while it runs, never negative.
        public func minutesLeft(at now: Date) -> Int { max(0, Int(end.timeIntervalSince(now) / 60)) }

        func overlaps(_ other: Entry) -> Bool { start < other.end && other.start < end }
    }

    /// The person's current pick, or their next one (NOW-1c).
    public struct ForYou: Equatable, Sendable {
        public init(entry: Entry, isNow: Bool, clashesWith: [Entry]) {
            self.entry = entry
            self.isNow = isNow
            self.clashesWith = clashesWith
        }

        public let entry: Entry
        public let isNow: Bool              // running now: the red "Now" dot
        public let clashesWith: [Entry]     // other picks that overlap it
        public var clashes: Bool { !clashesWith.isEmpty }
    }

    /// Time until the summit opens, for "The summit starts in 1 day" (the screen words it).
    public struct Countdown: Equatable, Sendable {
        public enum Unit: Equatable, Sendable { case days, hours, minutes }

        public init(opens: Date, now: Date) {
            self.opens = opens
            let minutes = max(0, Int(opens.timeIntervalSince(now) / 60))
            self.days = minutes / (24 * 60)
            self.hours = (minutes % (24 * 60)) / 60
            self.minutes = minutes % 60
        }

        public let opens: Date
        public let days: Int
        public let hours: Int
        public let minutes: Int

        /// The largest whole unit, for "in 1 day", "in 5 hours" or "in 40 minutes" (never "in 0 minutes").
        public var largest: (value: Int, unit: Unit) {
            if days > 0 { return (days, .days) }
            if hours > 0 { return (hours, .hours) }
            return (max(1, minutes), .minutes)
        }
    }

    public let now: Date
    public let phase: Phase
    public let forYou: ForYou?
    /// Running now, Centre Stage first, then by start; at most `Self.onNowLimit`.
    public let onNow: [Entry]
    /// How many sessions run now in all, for "See all (12)".
    public let onNowCount: Int
    /// Starting within the next 60 minutes, by start; at most `Self.upNextLimit`.
    public let upNext: [Entry]
    /// Between days: the first sessions of the next day with sessions (at most 3); otherwise empty.
    public let tomorrow: [Entry]
    /// Before the summit only.
    public let countdown: Countdown?
    /// Before the summit only: the two earliest official items still to come (registration, opening night).
    public let firstItems: [Entry]
    /// How many sessions the person has picked in all ("Thanks for coming" shows it).
    public let pickCount: Int

    public static let onNowLimit = 5
    public static let upNextLimit = 5
    public static let tomorrowLimit = 3
    public static let upNextMinutes = 60

    public init(events: [Event], picks: [SchedulePick], now: Date, summit: Summit = .lisbon2026) {
        self.now = now
        let pickedIDs = Set(picks.map(\.id))
        let venue = events.compactMap { Self.entry($0, pickedIDs: pickedIDs, forced: false) }
        let mine = picks.compactMap { pick in pick.event.flatMap { Self.entry($0, pickedIDs: [pick.id], forced: true) } }
        pickCount = picks.count

        let phase = Self.determinePhase(venue, now: now, summit: summit)
        self.phase = phase

        // For you: what the person is in now (earliest start if two overlap), else what comes next.
        let live = mine.filter { $0.isLive(at: now) }.sorted(by: Self.soonest)
        let coming = mine.filter { $0.start > now }.sorted(by: Self.soonest)
        if let entry = live.first ?? coming.first {
            forYou = ForYou(entry: entry, isNow: !live.isEmpty,
                            clashesWith: mine.filter { $0.id != entry.id && $0.end > now && $0.overlaps(entry) }.sorted(by: Self.soonest))
        } else {
            forYou = nil
        }

        // Registration runs all day, every day: it is not "on now" or "up next", it only opens the countdown screen.
        let sessions = venue.filter { $0.kind != Self.registrationKind }
        let running = sessions.filter { $0.isLive(at: now) }.sorted { lhs, rhs in
            let (l, r) = (Self.isCentreStage(lhs.place), Self.isCentreStage(rhs.place))
            if l != r { return l }
            return Self.soonest(lhs, rhs)
        }
        onNowCount = running.count
        onNow = Array(running.prefix(Self.onNowLimit))
        upNext = Array(sessions.filter { $0.start > now && $0.start <= now.addingTimeInterval(TimeInterval(Self.upNextMinutes * 60)) }
            .sorted(by: Self.soonest).prefix(Self.upNextLimit))

        if phase == .between, let first = sessions.filter({ $0.start > now }).map(\.start).min() {
            let day = Lisbon.day(first)
            tomorrow = Array(sessions.filter { $0.start > now && Lisbon.day($0.start) == day }
                .sorted(by: Self.soonest).prefix(Self.tomorrowLimit))
        } else {
            tomorrow = []
        }

        if phase == .before {
            countdown = Countdown(opens: summit.opens, now: now)
            // The first registration and the opening night (the first "summit" item), in time order.
            let ahead = venue.filter { $0.start > now }.sorted(by: Self.soonest)
            let picked = [ahead.first { $0.kind == Self.registrationKind }, ahead.first { $0.kind == Self.summitKind }]
                .compactMap { $0 }.sorted(by: Self.soonest)
            firstItems = picked.isEmpty ? Array(ahead.filter(\.official).prefix(2)) : picked
        } else {
            countdown = nil
            firstItems = []
        }
    }

    // MARK: Rules

    /// A session without an end time lasts thirty minutes.
    static let defaultLength: TimeInterval = 30 * 60

    static let registrationKind = "registration"
    static let summitKind = "summit"

    static func soonest(_ a: Entry, _ b: Entry) -> Bool { a.start == b.start ? a.title < b.title : a.start < b.start }

    static func isCentreStage(_ place: String) -> Bool { place.localizedCaseInsensitiveContains("centre stage") }

    /// A session as an entry; nil when its time is not readable or it ends before it starts.
    static func entry(_ event: Event, pickedIDs: Set<String>, forced: Bool) -> Entry? {
        guard let start = event.start else { return nil }
        let end = event.end ?? start.addingTimeInterval(defaultLength)
        guard end > start else { return nil }
        let id = ScheduleID.fromPage(event.page) ?? event.page
        return Entry(id: id, title: event.title, place: event.place, start: start, end: end,
                     mine: forced || pickedIDs.contains(id), official: event.official, url: event.url,
                     kind: event.kind)
    }

    /// Before the summit opens: `.before`; from its close: `.after`; in between: `.during` while a session runs or more
    /// start today (or the agenda is not loaded), else `.between`.
    static func determinePhase(_ entries: [Entry], now: Date, summit: Summit) -> Phase {
        if now < summit.opens { return .before }
        if now >= summit.closes { return .after }
        if entries.isEmpty { return .during }
        let today = Lisbon.day(now)
        let moreToday = entries.contains { $0.isLive(at: now) || ($0.start > now && Lisbon.day($0.start) == today) }
        return moreToday ? .during : .between
    }
}
