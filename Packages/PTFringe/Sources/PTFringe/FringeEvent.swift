import Foundation
import PTCore

/// What the site says about an event after the storm. Anything the feed does not say, or says in a way this app
/// does not know, is `.unknown`: never a guess.
public enum FringeStatus: String, Sendable, CaseIterable {
    case on, moved, cancelled, online, unknown

    public init(feed value: String?) {
        self = FringeStatus(rawValue: (value ?? "").lowercased()) ?? .unknown
    }

    public var label: String {
        switch self {
        case .on: String(localized: "On", bundle: .module)
        case .moved: String(localized: "Moved", bundle: .module)
        case .cancelled: String(localized: "Cancelled", bundle: .module)
        case .online: String(localized: "Online", bundle: .module)
        case .unknown: String(localized: "Status unknown", bundle: .module)
        }
    }
}

/// One event in the shape of fringe.promptugal.news/api/v1/events.json (and of the bundled seed):
/// `name, kind, organiser, date, start, end, place, join, url, status, storm_note, topics[], read_at, verified`.
/// `start` and `end` may be null. Every field but `name` and `date` is optional on the wire.
public struct FringeEvent: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    public let kind: String
    public let organiser: String
    public let date: String          // "2026-11-12", Lisbon time
    public let start: String?        // "18:30"
    public let end: String?
    public let place: String
    public let join: String          // how to join, in words
    public let url: URL?             // the source page; also where to join when it is public
    public let status: String
    public let stormNote: String
    public let topics: [String]
    public let readAt: String?       // ISO 8601, UTC: when the team read the source
    public let verified: Bool
    public let note: String

    enum CodingKeys: String, CodingKey {
        case name, kind, organiser, date, start, end, place, join, url, status
        case stormNote = "storm_note", topics
        case readAt = "read_at", verified, note
    }

    public init(name: String, kind: String = "other", organiser: String = "", date: String, start: String? = nil,
                end: String? = nil, place: String = "", join: String = "", url: URL? = nil, status: String = "unknown",
                stormNote: String = "", topics: [String] = [], readAt: String? = nil, verified: Bool = false, note: String = "") {
        self.name = name
        self.kind = kind
        self.organiser = organiser
        self.date = date
        self.start = start
        self.end = end
        self.place = place
        self.join = join
        self.url = url
        self.status = status
        self.stormNote = stormNote
        self.topics = topics
        self.readAt = readAt
        self.verified = verified
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        date = try c.decode(String.self, forKey: .date)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "other"
        organiser = (try? c.decodeIfPresent(String.self, forKey: .organiser)) ?? ""
        start = Self.clock(try? c.decodeIfPresent(String.self, forKey: .start))
        end = Self.clock(try? c.decodeIfPresent(String.self, forKey: .end))
        place = (try? c.decodeIfPresent(String.self, forKey: .place)) ?? ""
        join = (try? c.decodeIfPresent(String.self, forKey: .join)) ?? ""
        let rawURL = try? c.decodeIfPresent(String.self, forKey: .url)
        url = rawURL.flatMap { URL(string: $0) }
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "unknown"
        stormNote = (try? c.decodeIfPresent(String.self, forKey: .stormNote)) ?? ""
        topics = (try? c.decodeIfPresent([String].self, forKey: .topics)) ?? []
        readAt = try? c.decodeIfPresent(String.self, forKey: .readAt)
        verified = (try? c.decodeIfPresent(Bool.self, forKey: .verified)) ?? false
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
    }

    /// A clock as "HH:mm", or nil for anything else (null, empty, "TBC").
    static func clock(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), value.count >= 4 else { return nil }
        let parts = value.prefix(5).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    /// Stable across refreshes: the day and the name, lower-cased and hyphenated.
    public var id: String { "\(date)-\(Self.slug(name))" }

    public var statusValue: FringeStatus { FringeStatus(feed: status) }
    public var startDate: Date? { start.flatMap { Lisbon.instant(day: date, clock: $0) } }
    /// The end, or nil when the feed has none.
    public var endDate: Date? { end.flatMap { Lisbon.instant(day: date, clock: $0) } }
    public var timeLabel: String {
        switch (start, end) {
        case let (start?, end?): "\(start)–\(end)"
        case let (start?, nil): String(localized: "from \(start)", bundle: .module)
        default: String(localized: "Time not published", bundle: .module)
        }
    }
    public var readDate: Date? { readAt.flatMap { ISO8601DateFormatter().date(from: $0) } }
    public var isCancelled: Bool { statusValue == .cancelled }

    /// Whether the event can be picked for My plan: it needs a start, and it must not be cancelled.
    public var isPickable: Bool { startDate != nil && !isCancelled }

    public static func slug(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
        var out = ""
        var lastDash = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                out.unicodeScalars.append(scalar)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        if out.hasSuffix("-") { out.removeLast() }
        return String(out.prefix(60))
    }

    /// The event as PTAgenda's picks, clashes and Add to Calendar know it. The page is a made-up
    /// `events/<id>/index.html` so the pick id is this event's id; the source link stays in `url`.
    /// When the feed has a start but no end, the planner is given one hour: for clash maths only, never shown.
    public var planEvent: Event {
        let clock: String
        if let start {
            clock = "\(start)-\(end ?? Self.plusOneHour(start))"
        } else {
            clock = ""
        }
        return Event(date: date, time: clock, title: name, place: place, kind: kind, official: false,
                     page: "events/\(id)/index.html")
    }

    static func plusOneHour(_ clock: String) -> String {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]) else { return clock }
        return "\(String(format: "%02d", min(h + 1, 23))):\(parts[1])"
    }
}
