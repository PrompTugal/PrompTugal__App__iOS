import Foundation

/// "Help me plan my presence": proposes a day from the agenda, the picks and the team's stand-ups, showing clashes
/// and gaps, with walking time between venues. Pure, so it can be tested; `PlannerStore` feeds it.
enum DayPlanner {
    struct Item: Identifiable, Hashable, Sendable {
        enum Kind: String, Sendable { case pick, standup, proposal }
        let id: String
        let kind: Kind
        let title: String
        let start: Date
        let end: Date
        let place: String
        var eventID: String?        // schedule id (slug) for picks and proposals
    }

    struct Gap: Hashable, Sendable {
        let start: Date
        let end: Date
        var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    struct Proposal: Identifiable, Hashable, Sendable {
        var id: String { item.id }
        let item: Item
        let score: Double
        let reasons: [String]       // plain words: "Picked for you by the team", "Centre Stage", "Like your picks"
    }

    struct Clash: Hashable, Sendable {
        let first: Item
        let second: Item
        let minutes: Int            // overlap, or travel time short, in minutes
        let travel: Bool            // true when they do not overlap but there is no time to walk between them
    }

    struct Plan: Sendable {
        let day: String
        let fixed: [Item]           // picks and stand-ups, by start
        let clashes: [Clash]
        let gaps: [Gap]
        let proposals: [Proposal]   // the suggested day: at most one per slot, none overlapping
        let alternatives: [String: [Proposal]]   // by proposal id: other options for the same gap
    }

    struct Preferences: Sendable {
        var dayStart = "09:00"
        var dayEnd = "19:00"
        var minimumGapMinutes = 20
        var officialOnly = false
        /// Event slugs suggested for this person (their command centre's sessions) or that teammates picked.
        var suggested: [String: String] = [:]      // slug → reason
        var teammates: [String: [String]] = [:]    // slug → teammates' names
    }

    // MARK: Travel

    /// Rooms inside the summit's venue (MEO Arena and FIL) are a short walk apart; anywhere else is a trip.
    /// places.json has no coordinates, so these are estimates, said as such in the UI.
    static func travelMinutes(from a: String, to b: String) -> Int {
        if a.isEmpty || b.isEmpty || a.caseInsensitiveCompare(b) == .orderedSame { return 0 }
        switch (isSummitVenue(a), isSummitVenue(b)) {
        case (true, true): return 5
        default: return 25
        }
    }

    static func isSummitVenue(_ place: String) -> Bool {
        let p = place.lowercased()
        return ["stage", "masterclass", "meetup", "lounge", "meo arena", "fil", "pitch", "summit", "booth", "hall", "pavilion"]
            .contains { p.contains($0) }
    }

    // MARK: Planning

    /// - Parameter titleKeywords: each event's title keywords by schedule id, worked out once per agenda load
    ///   (`keywordIndex(_:)`); without it they are worked out here, which is slower on a 195-item agenda.
    static func plan(day: String, agenda: [Event], picks: [SchedulePick], standups: [TeamStandup],
                     preferences: Preferences = Preferences(),
                     titleKeywords: [String: Set<String>]? = nil) -> Plan {
        let pickedIDs = Set(picks.map(\.id))
        var fixed: [Item] = picks.compactMap { pick in
            guard let event = pick.event, event.date == day, let start = event.start else { return nil }
            return Item(id: "pick.\(pick.id)", kind: .pick, title: event.title, start: start,
                        end: event.end ?? start.addingTimeInterval(30 * 60), place: event.place, eventID: pick.id)
        }
        fixed += standups.filter { lisbonDay($0.at) == day }.map {
            Item(id: "standup.\($0.slot)", kind: .standup, title: "Team stand-up", start: $0.at, end: $0.end,
                 place: "", eventID: nil)
        }
        fixed.sort { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }

        // Clashes: overlaps, and back-to-back items in places too far apart.
        var clashes: [Clash] = []
        for (i, a) in fixed.enumerated() {
            for b in fixed[(i + 1)...] where b.start < a.end.addingTimeInterval(TimeInterval(travelMinutes(from: a.place, to: b.place) * 60)) {
                let overlap = Int(min(a.end, b.end).timeIntervalSince(b.start) / 60)
                if overlap > 0 {
                    clashes.append(Clash(first: a, second: b, minutes: overlap, travel: false))
                } else {
                    let short = travelMinutes(from: a.place, to: b.place) - Int(b.start.timeIntervalSince(a.end) / 60)
                    if short > 0 { clashes.append(Clash(first: a, second: b, minutes: short, travel: true)) }
                }
            }
        }

        // Gaps inside the day window, between busy items.
        guard let windowStart = Lisbon.instant(day: day, clock: preferences.dayStart),
              let windowEnd = Lisbon.instant(day: day, clock: preferences.dayEnd), windowStart < windowEnd else {
            return Plan(day: day, fixed: fixed, clashes: clashes, gaps: [], proposals: [], alternatives: [:])
        }
        var gaps: [Gap] = []
        var cursor = windowStart
        for item in fixed where item.end > windowStart && item.start < windowEnd {
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
            let before = fixed.last { $0.end <= gap.start }
            let after = fixed.first { $0.start >= gap.end }
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

    static func rank(_ event: Event, id: String, interests: Set<String>,
                     preferences: Preferences, keywords known: Set<String>? = nil) -> (Double, [String]) {
        var score = 1.0
        var reasons: [String] = []
        if let why = preferences.suggested[id] { score += 5; reasons.append(why) }
        if let names = preferences.teammates[id], !names.isEmpty {
            score += 2 + Double(names.count) * 0.5
            reasons.append("Also going: \(names.joined(separator: ", "))")
        }
        let overlap = (known ?? keywords([event.title])).intersection(interests)
        if !overlap.isEmpty {
            score += Double(min(overlap.count, 3))
            reasons.append("Like your picks: \(overlap.sorted().prefix(3).joined(separator: ", "))")
        }
        if event.place == "Centre Stage" { score += 1; reasons.append("Centre Stage") }
        if event.official { score += 0.5 }
        return (score, reasons)
    }

    private static let stopWords: Set<String> = ["the", "and", "for", "with", "from", "into", "your", "you", "our",
        "how", "what", "why", "who", "are", "can", "will", "this", "that", "hosted", "session", "summit", "web",
        "next", "new", "about", "more", "need", "don", "isn", "its", "it's", "not", "all", "now", "era"]

    static func keywords(_ titles: [String]) -> Set<String> {
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
    static func keywordIndex(_ agenda: [Event]) -> [String: Set<String>] {
        var index: [String: Set<String>] = [:]
        for event in agenda {
            if let id = ScheduleID.fromPage(event.page) { index[id] = keywords([event.title]) }
        }
        return index
    }

    static func lisbonDay(_ date: Date) -> String {
        let parts = Lisbon.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
