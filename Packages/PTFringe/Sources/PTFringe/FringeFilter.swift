import Foundation
import PTCore

/// The Events tab's three filters. A nil value means "all".
public struct FringeFilter: Equatable, Sendable {
    public var day: String?
    public var kind: String?
    public var topic: String?

    public init(day: String? = nil, kind: String? = nil, topic: String? = nil) {
        self.day = day
        self.kind = kind
        self.topic = topic
    }

    public var isActive: Bool { day != nil || kind != nil || topic != nil }

    public func apply(_ events: [FringeEvent]) -> [FringeEvent] {
        events.filter { event in
            (day == nil || event.date == day)
                && (kind == nil || event.kind.caseInsensitiveCompare(kind ?? "") == .orderedSame)
                && (topic == nil || event.topics.contains { $0.caseInsensitiveCompare(topic ?? "") == .orderedSame })
        }
    }

    public static func days(in events: [FringeEvent]) -> [String] { Array(Set(events.map(\.date).filter { !$0.isEmpty })).sorted() }
    public static func kinds(in events: [FringeEvent]) -> [String] {
        Array(Set(events.map { $0.kind.lowercased() }.filter { !$0.isEmpty })).sorted()
    }
    public static func topics(in events: [FringeEvent]) -> [String] {
        Array(Set(events.flatMap(\.topics).map { $0.lowercased() })).sorted()
    }

    /// "Thu 12 Nov" for a day id.
    public static func dayLabel(_ day: String) -> String {
        day.isEmpty ? String(localized: "Date not published", bundle: .module) : Lisbon.dayLabel(day)
    }

    public static func kindLabel(_ kind: String) -> String {
        switch kind.lowercased() {
        case "unconference": String(localized: "Unconference", bundle: .module)
        case "meetup": String(localized: "Meetup", bundle: .module)
        case "side event", "side_event", "side-event": String(localized: "Side event", bundle: .module)
        case "party": String(localized: "Party", bundle: .module)
        case "workshop": String(localized: "Workshop", bundle: .module)
        case "online": String(localized: "Online", bundle: .module)
        case "community": String(localized: "Community", bundle: .module)
        case "talk": String(localized: "Talk", bundle: .module)
        case "run": String(localized: "Run", bundle: .module)
        default: kind.prefix(1).uppercased() + kind.dropFirst()
        }
    }
}

/// What is on now and what is next, from the events and a clock. Cancelled events are never "on" or "next".
public struct FringeNow: Equatable, Sendable {
    public let onNow: [FringeEvent]
    public let next: [FringeEvent]      // later today, soonest first
    public let untimed: [FringeEvent]   // today, no start published
    public let day: String

    public init(events: [FringeEvent], now: Date) {
        let day = Lisbon.day(now)
        self.day = day
        let live = events.filter { !$0.isCancelled }
        onNow = live.filter { event in
            guard let start = event.startDate, start <= now else { return false }
            // Without an end the event counts as on for three hours, for this list only.
            let end = event.endDate ?? start.addingTimeInterval(3 * 3600)
            return now < end
        }
        next = live.filter { ($0.startDate ?? .distantPast) > now && $0.date == day }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        untimed = live.filter { $0.date == day && $0.startDate == nil }
    }
}
