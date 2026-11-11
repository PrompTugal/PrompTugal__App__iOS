import Foundation

/// Morning, Afternoon and Evening, by start time in Lisbon.
enum DayPart: String, CaseIterable, Identifiable, Sendable {
    case onNow, morning, afternoon, evening, noTime
    var id: String { rawValue }

    var title: String {
        switch self {
        case .onNow: "On now"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .noTime: "Time not given"
        }
    }

    static func of(_ event: FeedEvent) -> DayPart {
        guard let m = event.startMinute else { return .noTime }
        if m < 12 * 60 { return .morning }
        if m < 18 * 60 { return .afternoon }
        return .evening
    }
}

struct DaySection: Identifiable, Sendable {
    let part: DayPart
    let events: [FeedEvent]
    var id: DayPart { part }
}

/// Pure functions behind the three tabs. Tested in Tests/LogicTests.swift.
enum Planner {
    /// Days that have events, in order.
    static func days(of events: [FeedEvent]) -> [Day] {
        Set(events.map(\.date)).filter { !$0.isEmpty }.sorted().map(Day.init(key:))
    }

    static func sorted(_ events: [FeedEvent]) -> [FeedEvent] {
        events.sorted {
            switch ($0.start, $1.start) {
            case let (a?, b?) where a != b: return a < b
            case (nil, _?): return false
            case (_?, nil): return true
            default: return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    /// The sections of the All events list. "On now" comes first and only on today's list.
    static func sections(_ events: [FeedEvent], now: Date, isToday: Bool) -> [DaySection] {
        let sortedEvents = sorted(events)
        let onNow = isToday ? sortedEvents.filter { $0.isOn(at: now) } : []
        let onNowIDs = Set(onNow.map(\.id))
        var out: [DaySection] = []
        if !onNow.isEmpty { out.append(DaySection(part: .onNow, events: onNow)) }
        for part in [DayPart.morning, .afternoon, .evening, .noTime] {
            let list = sortedEvents.filter { !onNowIDs.contains($0.id) && DayPart.of($0) == part }
            if !list.isEmpty { out.append(DaySection(part: part, events: list)) }
        }
        return out
    }

    /// True when the event shares time with one of the saved events (not itself, not cancelled).
    static func clashes(_ event: FeedEvent, with saved: [FeedEvent]) -> Bool {
        guard event.eventStatus != .cancelled else { return false }
        return saved.contains { $0.eventStatus != .cancelled && $0.overlaps(event) }
    }

    /// The next saved event that has not ended: the one on now, or the next to start.
    static func next(of saved: [FeedEvent], now: Date) -> FeedEvent? {
        sorted(saved).first { e in
            guard e.eventStatus != .cancelled, let i = e.interval else { return false }
            return i.end > now
        }
    }

    /// "in 1 h 20 min", "on now", "on Thursday 12 at 17:00"
    static func whenText(_ event: FeedEvent, now: Date) -> String {
        guard let i = event.interval else { return "time not given" }
        if i.start <= now { return "on now" }
        let minutes = Int((i.start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes) min" }
        if minutes < 12 * 60 {
            let h = minutes / 60, m = minutes % 60
            return m == 0 ? "in \(h) h" : "in \(h) h \(m) min"
        }
        return "on \(Day(key: event.date).title) at \(event.startText)"
    }

    // MARK: Calendar

    struct Overlap: Equatable, Sendable {
        let start: Date
        let end: Date
        let count: Int
    }

    /// Times when two or more saved events run at once, merged into stretches.
    static func overlaps(_ events: [FeedEvent]) -> [Overlap] {
        let spans = events.filter { $0.eventStatus != .cancelled }.compactMap { e in e.interval.map { (e.id, $0) } }
        let points = Set(spans.flatMap { [$0.1.start, $0.1.end] }).sorted()
        guard points.count > 1 else { return [] }
        var out: [Overlap] = []
        var runStart: Date?
        var runEnd: Date?
        var runIDs = Set<String>()
        for (a, b) in zip(points, points.dropFirst()) {
            let active = spans.filter { $0.1.start <= a && b <= $0.1.end }.map { $0.0 }
            if active.count >= 2 {
                if runStart == nil { runStart = a }
                runEnd = b
                runIDs.formUnion(active)
            } else if let s = runStart, let e = runEnd {
                out.append(Overlap(start: s, end: e, count: runIDs.count))
                runStart = nil; runEnd = nil; runIDs = []
            }
        }
        if let s = runStart, let e = runEnd { out.append(Overlap(start: s, end: e, count: runIDs.count)) }
        return out
    }

    static func numberWord(_ n: Int) -> String {
        let words = ["None", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
        return n < words.count ? words[n] : "\(n)"
    }

    /// "Thu 12: 3 saved. Two overlap from 18:30 to 19:30."
    static func daySummary(day: Day, saved: [FeedEvent]) -> String {
        guard !saved.isEmpty else { return "\(day.shortTitle): nothing saved yet." }
        var text = "\(day.shortTitle): \(saved.count) saved."
        for o in overlaps(saved) {
            text += " \(numberWord(o.count)) overlap from \(FeedDate.hhmm(o.start)) to \(FeedDate.hhmm(o.end))."
        }
        return text
    }

    /// A column for each event so overlapping blocks sit side by side.
    struct Placement: Equatable, Sendable {
        let column: Int
        let columns: Int
    }

    static func placements(_ events: [FeedEvent]) -> [String: Placement] {
        let list = sorted(events).filter { $0.interval != nil }
        var result: [String: Placement] = [:]
        var cluster: [(id: String, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd: Date?

        func closeCluster() {
            let count = max(columnEnds.count, 1)
            for item in cluster { result[item.id] = Placement(column: item.column, columns: count) }
            cluster = []; columnEnds = []; clusterEnd = nil
        }

        for e in list {
            guard let i = e.interval else { continue }
            if let end = clusterEnd, i.start >= end { closeCluster() }
            if let free = columnEnds.firstIndex(where: { $0 <= i.start }) {
                columnEnds[free] = i.end
                cluster.append((e.id, free))
            } else {
                columnEnds.append(i.end)
                cluster.append((e.id, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd ?? i.end, i.end)
        }
        closeCluster()
        return result
    }

    /// Five calendar colours, given in order of start time. The view pairs each with a word.
    static func colourIndex(of event: FeedEvent, in daySaved: [FeedEvent]) -> Int {
        let order = sorted(daySaved).map(\.id)
        return (order.firstIndex(of: event.id) ?? 0) % 5
    }
}
