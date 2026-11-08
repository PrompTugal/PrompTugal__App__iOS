import Foundation

/// One person's picks, from wherever they came.
struct TeammatePlan: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        /// This device: my own schedule.
        case me
        /// Read from the teammate's vault (`apps/agenda/picks.json`) with the read key they shared.
        case vault(String)
    }

    var id: String { person }
    let person: String
    let name: String
    let source: Source
    let pickIds: [String]
    let loadedAt: Date
}

/// Overlaps, clashes and meeting slots across the team's plans. Pure: plans and agenda in, answers out.
struct CoordinationAnalysis: Equatable, Sendable {
    struct Together: Identifiable, Equatable, Sendable {
        var id: String { event.id }
        let event: Event
        let people: [String]
    }

    struct Clash: Identifiable, Equatable, Sendable {
        var id: String { "\(person)|\(first.id)|\(second.id)" }
        let person: String
        let first: Event
        let second: Event
    }

    struct MeetSlot: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// Right after a session two or more of us are at, at its place.
            case afterSession(Event)
            /// A gap nobody has a pick in.
            case freeWindow
        }
        var id: String { "\(start.timeIntervalSince1970)-\(place)" }
        let start: Date
        let end: Date
        let place: String
        let people: [String]
        let kind: Kind
    }

    let day: String
    let together: [Together]
    let clashes: [Clash]
    /// person → number of picks on `day`.
    let perPerson: [String: Int]
    /// day → number of people with at least one pick that day, for the day picker.
    let peoplePerDay: [String: Int]
    let meetSlots: [MeetSlot]

    /// - Parameters:
    ///   - standups: times (Lisbon, "HH:mm") of the daily stand-ups, kept free in meeting suggestions.
    ///   - window: the hours (Lisbon) in which to look for free windows.
    static func build(plans: [TeammatePlan], events: [Event], day: String, standups: [String] = ["13:00", "18:00"],
                      standupMinutes: Int = 30, window: (from: String, to: String) = ("09:00", "19:00"),
                      minimumMinutes: Int = 30) -> CoordinationAnalysis {
        let byId = Dictionary(events.map { (PickId.of($0), $0) }, uniquingKeysWith: { first, _ in first })
        var picksOnDay: [String: [Event]] = [:]
        var peoplePerDay: [String: Set<String>] = [:]
        for plan in plans {
            let mine = plan.pickIds.compactMap { byId[PickId.normalise($0)] }
            for event in mine { peoplePerDay[event.date, default: []].insert(plan.person) }
            picksOnDay[plan.person] = mine.filter { $0.date == day }.sorted(by: Event.earlier)
        }

        // Sessions with two or more of us.
        var attendees: [String: (Event, [String])] = [:]
        for (person, events) in picksOnDay {
            for event in events { attendees[event.id, default: (event, [])].1.append(person) }
        }
        let together = attendees.values
            .filter { $0.1.count >= 2 }
            .map { Together(event: $0.0, people: $0.1.sorted()) }
            .sorted { Event.earlier($0.event, $1.event) }

        // Two of one person's picks at the same time.
        var clashes: [Clash] = []
        for (person, events) in picksOnDay {
            for (index, first) in events.enumerated() {
                for second in events[(index + 1)...] where overlaps(first, second) {
                    clashes.append(Clash(person: person, first: first, second: second))
                }
            }
        }
        clashes.sort { ($0.first.time, $0.person) < ($1.first.time, $1.person) }

        // Where to meet: after shared sessions, then free windows.
        var slots = together.compactMap { item -> MeetSlot? in
            guard let end = item.event.end ?? item.event.start else { return nil }
            return MeetSlot(start: end, end: end.addingTimeInterval(15 * 60), place: item.event.place,
                            people: item.people, kind: .afterSession(item.event))
        }
        let busy = picksOnDay.values.flatMap { $0 }.compactMap { event -> (Date, Date)? in
            guard let start = event.start else { return nil }
            return (start, event.end ?? start.addingTimeInterval(30 * 60))
        } + standups.compactMap { clock -> (Date, Date)? in
            guard let start = Lisbon.instant(day: day, clock: clock) else { return nil }
            return (start, start.addingTimeInterval(Double(standupMinutes) * 60))
        }
        if let from = Lisbon.instant(day: day, clock: window.from), let to = Lisbon.instant(day: day, clock: window.to) {
            let everyone = picksOnDay.filter { !$0.value.isEmpty }.keys.sorted()
            for gap in freeWindows(busy: busy, from: from, to: to, minimum: Double(minimumMinutes) * 60).prefix(3) {
                slots.append(MeetSlot(start: gap.0, end: gap.1, place: "", people: everyone, kind: .freeWindow))
            }
        }

        return CoordinationAnalysis(day: day, together: together, clashes: clashes,
                                    perPerson: picksOnDay.mapValues(\.count),
                                    peoplePerDay: peoplePerDay.mapValues(\.count), meetSlots: slots)
    }

    static func overlaps(_ a: Event, _ b: Event) -> Bool {
        guard let aStart = a.start, let bStart = b.start else { return false }
        let aEnd = a.end ?? aStart.addingTimeInterval(30 * 60)
        let bEnd = b.end ?? bStart.addingTimeInterval(30 * 60)
        return aStart < bEnd && bStart < aEnd
    }

    /// Gaps of at least `minimum` seconds between `from` and `to` not covered by any busy interval.
    static func freeWindows(busy: [(Date, Date)], from: Date, to: Date, minimum: TimeInterval) -> [(Date, Date)] {
        var gaps: [(Date, Date)] = []
        var cursor = from
        for (start, end) in busy.sorted(by: { $0.0 < $1.0 }) where end > cursor {
            if start > cursor, start.timeIntervalSince(cursor) >= minimum {
                gaps.append((cursor, min(start, to)))
            }
            cursor = max(cursor, end)
            if cursor >= to { break }
        }
        if to.timeIntervalSince(cursor) >= minimum { gaps.append((cursor, to)) }
        return gaps.filter { $0.1.timeIntervalSince($0.0) >= minimum }
    }

    static func == (lhs: CoordinationAnalysis, rhs: CoordinationAnalysis) -> Bool {
        lhs.day == rhs.day && lhs.together == rhs.together && lhs.clashes == rhs.clashes
            && lhs.perPerson == rhs.perPerson && lhs.meetSlots == rhs.meetSlots
    }
}
