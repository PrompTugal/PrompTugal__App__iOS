import Foundation

/// One event from https://lisbontechfringe.com/api/v1/events.json.
/// The contract only ever adds fields, so every field is optional except the id and name.
struct FeedEvent: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let name: String
    let url: String?
    let readAt: Date?
    /// The start day as the feed gives it, "2026-11-11". Events stay on this day, even past midnight.
    let date: String
    let start: Date?
    let end: Date?
    let kind: String?
    let organiser: String?
    let place: String?
    let join: String?
    let status: String?
    let stormNote: String?
    let topics: [String]
    let cost: String?
    let inLisbon: Bool?
    let neighbourhood: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url, date, start, end, kind, organiser, place, join, status, topics, cost, neighbourhood
        case readAt = "read_at"
        case stormNote = "storm_note"
        case inLisbon = "in_lisbon"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        readAt = FeedDate.parse(try? c.decodeIfPresent(String.self, forKey: .readAt))
        start = FeedDate.parse(try? c.decodeIfPresent(String.self, forKey: .start))
        end = FeedDate.parse(try? c.decodeIfPresent(String.self, forKey: .end))
        let rawDate = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? nil
        date = rawDate ?? start.map { FeedDate.dayString($0) } ?? ""
        let rawID = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil
        id = rawID ?? "\(date)-\(name)"
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        organiser = try? c.decodeIfPresent(String.self, forKey: .organiser)
        place = try? c.decodeIfPresent(String.self, forKey: .place)
        join = try? c.decodeIfPresent(String.self, forKey: .join)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        stormNote = try? c.decodeIfPresent(String.self, forKey: .stormNote)
        topics = ((try? c.decodeIfPresent([String].self, forKey: .topics)) ?? nil) ?? []
        cost = try? c.decodeIfPresent(String.self, forKey: .cost)
        inLisbon = try? c.decodeIfPresent(Bool.self, forKey: .inLisbon)
        neighbourhood = try? c.decodeIfPresent(String.self, forKey: .neighbourhood)
    }

    /// For tests and previews.
    init(id: String, name: String, date: String, start: Date?, end: Date?, kind: String? = "meetup",
         organiser: String? = nil, place: String? = nil, join: String? = nil, status: String? = "on",
         stormNote: String? = nil, topics: [String] = [], cost: String? = nil, inLisbon: Bool? = true,
         neighbourhood: String? = nil, url: String? = nil, readAt: Date? = nil) {
        self.id = id; self.name = name; self.date = date; self.start = start; self.end = end
        self.kind = kind; self.organiser = organiser; self.place = place; self.join = join
        self.status = status; self.stormNote = stormNote; self.topics = topics; self.cost = cost
        self.inLisbon = inLisbon; self.neighbourhood = neighbourhood; self.url = url; self.readAt = readAt
    }
}

/// The whole events.json file. A bad event is skipped, not fatal.
struct EventFeed: Decodable, Sendable {
    let builtAt: Date?
    let events: [FeedEvent]

    enum CodingKeys: String, CodingKey { case events; case builtAt = "built_at" }

    init(builtAt: Date?, events: [FeedEvent]) { self.builtAt = builtAt; self.events = events }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        builtAt = FeedDate.parse(try? c.decodeIfPresent(String.self, forKey: .builtAt))
        events = try c.decode([Lossy<FeedEvent>].self, forKey: .events).compactMap(\.value)
    }

    static func decode(_ data: Data) throws -> EventFeed {
        try JSONDecoder().decode(EventFeed.self, from: data)
    }
}

/// communities.json: used for the short line about a host.
struct CommunityFeed: Decodable, Sendable {
    struct Community: Decodable, Sendable {
        let id: String?
        let name: String?
        let whatText: String?
        let events: [String]

        enum CodingKeys: String, CodingKey { case id, name, what, events }
        enum WhatKeys: String, CodingKey { case text }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            events = ((try? c.decodeIfPresent([String].self, forKey: .events)) ?? nil) ?? []
            if let what = try? c.nestedContainer(keyedBy: WhatKeys.self, forKey: .what) {
                whatText = try? what.decodeIfPresent(String.self, forKey: .text)
            } else {
                whatText = try? c.decodeIfPresent(String.self, forKey: .what)
            }
        }
    }

    let communities: [Community]

    enum CodingKeys: String, CodingKey { case communities }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        communities = ((try? c.decode([Lossy<Community>].self, forKey: .communities)) ?? []).compactMap(\.value)
    }

    /// Event id to the host line, for communities that have one.
    var hostLines: [String: String] {
        var out: [String: String] = [:]
        for community in communities {
            guard let text = community.whatText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { continue }
            for id in community.events where out[id] == nil { out[id] = text }
        }
        return out
    }
}

struct Lossy<T: Decodable & Sendable>: Decodable, Sendable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// Dates and times, always in Lisbon time.
enum FeedDate {
    static let lisbon = TimeZone(identifier: "Europe/Lisbon") ?? .gmt

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = lisbon
        return cal
    }

    static func parse(_ string: String?) -> Date? {
        guard let s = string?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if let d = try? Date(s, strategy: Date.ISO8601FormatStyle()) { return d }
        if let d = try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return d }
        return nil
    }

    static func dayString(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Midnight in Lisbon at the start of a "yyyy-MM-dd" day.
    static func startOfDay(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func hhmm(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static let shortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let longWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let months = ["January", "February", "March", "April", "May", "June", "July",
                         "August", "September", "October", "November", "December"]
}

/// One day of the week strip.
struct Day: Hashable, Identifiable, Sendable {
    let key: String
    var id: String { key }

    var start: Date? { FeedDate.startOfDay(key) }
    private var parts: (weekday: Int, day: Int, month: Int) {
        guard let start else { return (1, 0, 1) }
        let c = FeedDate.calendar.dateComponents([.weekday, .day, .month], from: start)
        return (c.weekday ?? 1, c.day ?? 0, c.month ?? 1)
    }
    /// "Wed"
    var shortWeekday: String { FeedDate.shortWeekdays[(parts.weekday - 1) % 7] }
    /// "Wednesday"
    var longWeekday: String { FeedDate.longWeekdays[(parts.weekday - 1) % 7] }
    /// "11"
    var dayNumber: String { "\(parts.day)" }
    /// "Thursday 12"
    var title: String { "\(longWeekday) \(parts.day)" }
    /// "Thu 12"
    var shortTitle: String { "\(shortWeekday) \(parts.day)" }
    /// "Thursday 12 November"
    var longTitle: String { "\(longWeekday) \(parts.day) \(FeedDate.months[(parts.month - 1) % 12])" }
}
