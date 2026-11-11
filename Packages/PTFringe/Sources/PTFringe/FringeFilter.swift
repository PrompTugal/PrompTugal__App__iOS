import Foundation
import PTCore

/// The Events tab's three filters. A nil value means "all".
public struct FringeFilter: Equatable, Sendable {
    public var day: String?
    public var kind: String?
    public var topic: String?
    /// Only the events the site says the storm moved.
    public var stormMoved: Bool
    /// Hide the events the site says are not in Lisbon. Not part of `isActive`: the screen starts with it on.
    public var lisbonOnly: Bool

    public init(day: String? = nil, kind: String? = nil, topic: String? = nil, stormMoved: Bool = false, lisbonOnly: Bool = false) {
        self.day = day
        self.kind = kind
        self.topic = topic
        self.stormMoved = stormMoved
        self.lisbonOnly = lisbonOnly
    }

    public var isActive: Bool { day != nil || kind != nil || topic != nil || stormMoved }

    public func apply(_ events: [FringeEvent]) -> [FringeEvent] {
        events.filter { event in
            (day == nil || event.date == day)
                && (kind == nil || event.kind.caseInsensitiveCompare(kind ?? "") == .orderedSame)
                && (topic == nil || event.topics.contains { $0.caseInsensitiveCompare(topic ?? "") == .orderedSame })
                && (!stormMoved || event.movedByStorm)
                && (!lisbonOnly || event.isInLisbon)
        }
    }

    /// A day to jump to: today, tomorrow and the day after (named by its weekday), in Lisbon time.
    public struct QuickDay: Identifiable, Equatable, Sendable {
        public let id: String       // "2026-11-12"
        public let label: String
    }

    public static func quickDays(now: Date, locale: Locale = .current) -> [QuickDay] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = Lisbon.zone
        formatter.locale = locale
        return (0...2).compactMap { offset in
            guard let date = Lisbon.calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let label = switch offset {
            case 0: String(localized: "Today", bundle: .module)
            case 1: String(localized: "Tomorrow", bundle: .module)
            default: formatter.string(from: date).capitalized(with: locale)
            }
            return QuickDay(id: Lisbon.day(date), label: label)
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
