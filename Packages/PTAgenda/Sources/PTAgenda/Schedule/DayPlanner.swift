import Foundation
import PTCore
import PTWeb

/// "Help me plan my presence": proposes a day from the agenda, the picks and the team's stand-ups, showing clashes
/// and gaps, with walking time between venues. Pure, so it can be tested; `PlannerStore` feeds it.
public enum DayPlanner {
    public struct Item: Identifiable, Hashable, Sendable {
        public init(id: String, kind: Kind, title: String, start: Date, end: Date, place: String, eventID: String? = nil,
                    free: Bool = false) {
            self.free = free
            self.id = id
            self.kind = kind
            self.title = title
            self.start = start
            self.end = end
            self.place = place
            self.eventID = eventID
        }

        public enum Kind: String, Sendable { case pick, standup, proposal }
        public let id: String
        public let kind: Kind
        public let title: String
        public let start: Date
        public let end: Date
        public let place: String
        public var eventID: String?        // schedule id (slug) for picks and proposals
        public let free: Bool              // shows as free (registration, opening night, ...): never part of a clash
    }

    public struct Gap: Hashable, Sendable {
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }

        public let start: Date
        public let end: Date
        public var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    public struct Proposal: Identifiable, Hashable, Sendable {
        public init(item: Item, score: Double, reasons: [String]) {
            self.item = item
            self.score = score
            self.reasons = reasons
        }

        public var id: String { item.id }
        public let item: Item
        public let score: Double
        public let reasons: [String]       // plain words: "Picked for you by the team", "Centre Stage", "Like your picks"
    }

    public struct Clash: Hashable, Sendable {
        public init(first: Item, second: Item, minutes: Int, travel: Bool) {
            self.first = first
            self.second = second
            self.minutes = minutes
            self.travel = travel
        }

        public let first: Item
        public let second: Item
        public let minutes: Int            // overlap, or travel time short, in minutes
        public let travel: Bool            // true when they do not overlap but there is no time to walk between them
    }

    public struct Plan: Sendable {
        public init(day: String, fixed: [Item], clashes: [Clash], gaps: [Gap], proposals: [Proposal], alternatives: [String: [Proposal]]) {
            self.day = day
            self.fixed = fixed
            self.clashes = clashes
            self.gaps = gaps
            self.proposals = proposals
            self.alternatives = alternatives
        }

        public let day: String
        public let fixed: [Item]           // picks and stand-ups, by start
        public let clashes: [Clash]
        public let gaps: [Gap]
        public let proposals: [Proposal]   // the suggested day: at most one per slot, none overlapping
        public let alternatives: [String: [Proposal]]   // by proposal id: other options for the same gap
    }

    public struct Preferences: Sendable {
        public init(dayStart: String = "09:00", dayEnd: String = "19:00", minimumGapMinutes: Int = 20, officialOnly: Bool = false,
                    suggested: [String: String] = [:], teammates: [String: [String]] = [:]) {
            self.dayStart = dayStart
            self.dayEnd = dayEnd
            self.minimumGapMinutes = minimumGapMinutes
            self.officialOnly = officialOnly
            self.suggested = suggested
            self.teammates = teammates
        }

        public var dayStart = "09:00"
        public var dayEnd = "19:00"
        public var minimumGapMinutes = 20
        public var officialOnly = false
        /// The person's own busy or free choice by schedule id; it wins over the feed and the rule (`BusyRule`).
        public var toggled: [String: ShowsAs] = [:]
        /// Event slugs suggested for this person (their command centre's sessions) or that teammates picked.
        public var suggested: [String: String] = [:]      // slug → reason
        public var teammates: [String: [String]] = [:]    // slug → teammates' names
    }

    // MARK: Travel

    /// Rooms inside the summit's venue (MEO Arena and FIL) are a short walk apart; anywhere else is a trip.
    /// places.json has no coordinates, so these are estimates, said as such in the UI.
    public static func travelMinutes(from a: String, to b: String) -> Int {
        if a.isEmpty || b.isEmpty || a.caseInsensitiveCompare(b) == .orderedSame { return 0 }
        switch (isSummitVenue(a), isSummitVenue(b)) {
        case (true, true): return 5
        default: return 25
        }
    }

    public static func isSummitVenue(_ place: String) -> Bool {
        let p = place.lowercased()
        return ["stage", "masterclass", "meetup", "lounge", "meo arena", "fil", "pitch", "summit", "booth", "hall", "pavilion"]
            .contains { p.contains($0) }
    }

    // MARK: Clashes

    /// Overlaps, and back-to-back items in places too far apart. `items` must be sorted by start.
    public static func clashes(in items: [Item]) -> [Clash] {
        var clashes: [Clash] = []
        for (i, a) in items.enumerated() {
            if a.free { continue }
            for b in items[(i + 1)...] where !b.free && b.start < a.end.addingTimeInterval(TimeInterval(travelMinutes(from: a.place, to: b.place) * 60)) {
                let overlap = Int(min(a.end, b.end).timeIntervalSince(b.start) / 60)
                if overlap > 0 {
                    clashes.append(Clash(first: a, second: b, minutes: overlap, travel: false))
                } else {
                    let short = travelMinutes(from: a.place, to: b.place) - Int(b.start.timeIntervalSince(a.end) / 60)
                    if short > 0 { clashes.append(Clash(first: a, second: b, minutes: short, travel: true)) }
                }
            }
        }
        return clashes
    }

    // MARK: Planning

    /// - Parameter titleKeywords: each event's title keywords by schedule id, worked out once per agenda load
    ///   (`keywordIndex(_:)`); without it they are worked out here, which is slower on a 195-item agenda.
    public static func plan(day: String, agenda: [Event], picks: [SchedulePick], standups: [TeamStandup],
                     preferences: Preferences = Preferences(),
                     titleKeywords: [String: Set<String>]? = nil) -> Plan {
        let pickedIDs = Set(picks.map(\.id))
        var fixed: [Item] = picks.compactMap { pick in
            guard let event = pick.event, event.date == day, let start = event.start else { return nil }
            let end = event.end ?? start.addingTimeInterval(30 * 60)
            let fallback = BusyRule.fallback(kind: event.kind, title: event.title, place: event.place, start: start, end: end)
            let shows = preferences.toggled[pick.id] ?? AgendaHub.showsAs(pick.id) ?? fallback
            return Item(id: "pick.\(pick.id)", kind: .pick, title: event.title, start: start,
                        end: end, place: event.place, eventID: pick.id, free: shows == .free)
        }
        fixed += standups.filter { Lisbon.day($0.at) == day }.map {
            Item(id: "standup.\($0.slot)", kind: .standup, title: String(localized: "Team stand-up", bundle: .module), start: $0.at, end: $0.end,
                 place: "", eventID: nil)
        }
        fixed.sort { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }

        let clashes = Self.clashes(in: fixed)
        let busyFixed = fixed.filter { !$0.free }       // a free pick (registration, opening night) does not fill the day

        // Gaps inside the day window, between busy items.
        guard let windowStart = Lisbon.instant(day: day, clock: preferences.dayStart),
              let windowEnd = Lisbon.instant(day: day, clock: preferences.dayEnd), windowStart < windowEnd else {
            return Plan(day: day, fixed: fixed, clashes: clashes, gaps: [], proposals: [], alternatives: [:])
        }
        var gaps: [Gap] = []
        var cursor = windowStart
        for item in busyFixed where item.end > windowStart && item.start < windowEnd {
            if item.start > cursor { gaps.append(Gap(start: cursor, end: item.start)) }
            cursor = max(cursor, item.end)
        }
        if cursor < windowEnd { gaps.append(Gap(start: cursor, end: windowEnd)) }
        gaps = gaps.filter { $0.minutes >= preferences.minimumGapMinutes }

        // Proposals: agenda items that fit in a gap with time to walk in and out.
        let interests = keywords(picks.compactMap { $0.event?.title })
        var proposals: [Proposal] = []
        var alternatives: [String: [Proposal]] = [:]
        for gap in gaps {
            let before = busyFixed.last { $0.end <= gap.start }
            let after = busyFixed.first { $0.start >= gap.end }
            var options: [Proposal] = []
            for event in agenda where event.date == day {
                guard let id = ScheduleID.fromPage(event.page), !pickedIDs.contains(id),
                      let start = event.start, let end = event.end, end > start,
                      !preferences.officialOnly || event.official else { continue }
                let walkIn = TimeInterval(travelMinutes(from: before?.place ?? "", to: event.place) * 60)
                let walkOut = TimeInterval(travelMinutes(from: event.place, to: after?.place ?? "") * 60)
                guard start >= gap.start.addingTimeInterval(before == nil ? 0 : walkIn),
                      end <= gap.end.addingTimeInterval(after == nil ? 0 : -walkOut) else { continue }
                let (score, reasons) = rank(event, id: id, interests: interests, preferences: preferences,
                                            keywords: titleKeywords?[id])
                options.append(Proposal(item: Item(id: "proposal.\(id)", kind: .proposal, title: event.title,
                                                   start: start, end: end, place: event.place, eventID: id),
                                        score: score, reasons: reasons))
            }
            options.sort { $0.score == $1.score ? $0.item.start < $1.item.start : $0.score > $1.score }
            // Fill the gap greedily with the best options that do not overlap each other (walking time included).
            var chosen: [Proposal] = []
            for option in options {
                let fits = chosen.allSatisfy { other in
                    let walk = TimeInterval(travelMinutes(from: other.item.place, to: option.item.place) * 60)
                    return option.item.end.addingTimeInterval(walk) <= other.item.start
                        || other.item.end.addingTimeInterval(walk) <= option.item.start
                }
                if fits { chosen.append(option) }
                if chosen.count == 3 { break }
            }
            for pick in chosen {
                proposals.append(pick)
                alternatives[pick.id] = options.filter { alt in
                    alt.id != pick.id && !chosen.contains { $0.id == alt.id }
                        && alt.item.start < pick.item.end && pick.item.start < alt.item.end
                }.prefix(3).map { $0 }
            }
        }
        proposals.sort { $0.item.start < $1.item.start }
        return Plan(day: day, fixed: fixed, clashes: clashes, gaps: gaps, proposals: proposals, alternatives: alternatives)
    }

    public static func rank(_ event: Event, id: String, interests: Set<String>,
                     preferences: Preferences, keywords known: Set<String>? = nil) -> (Double, [String]) {
        var score = 1.0
        var reasons: [String] = []
        if let why = preferences.suggested[id] { score += 5; reasons.append(why) }
        if let names = preferences.teammates[id], !names.isEmpty {
            score += 2 + Double(names.count) * 0.5
            reasons.append(String(localized: "Also going: \(names.joined(separator: ", "))", bundle: .module))
        }
        let overlap = (known ?? keywords([event.title])).intersection(interests)
        if !overlap.isEmpty {
            score += Double(min(overlap.count, 3))
            reasons.append(String(localized: "Like your picks: \(overlap.sorted().prefix(3).joined(separator: ", "))", bundle: .module))
        }
        if event.place == "Centre Stage" { score += 1; reasons.append("Centre Stage") }
        if event.official { score += 0.5 }
        return (score, reasons)
    }

    private static let stopWords: Set<String> = ["the", "and", "for", "with", "from", "into", "your", "you", "our",
        "how", "what", "why", "who", "are", "can", "will", "this", "that", "hosted", "session", "summit", "web",
        "next", "new", "about", "more", "need", "don", "isn", "its", "it's", "not", "all", "now", "era"]

    public static func keywords(_ titles: [String]) -> Set<String> {
        var words = Set<String>()
        for title in titles {
            for word in title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) where word.count >= 3 {
                let w = String(word)
                if !stopWords.contains(w) { words.insert(w) }
            }
        }
        return words
    }

    /// Title keywords for every agenda event, by schedule id.
    public static func keywordIndex(_ agenda: [Event]) -> [String: Set<String>] {
        var index: [String: Set<String>] = [:]
        for event in agenda {
            if let id = ScheduleID.fromPage(event.page) { index[id] = keywords([event.title]) }
        }
        return index
    }

    /// Forwarder kept so collab's call sites compile until they move to `Lisbon.day` (Q8). Remove after that.
    public static func lisbonDay(_ date: Date) -> String { Lisbon.day(date) }
}
