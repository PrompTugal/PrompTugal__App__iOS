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

/// One event in the shape of lisbontechfringe.com/api/v1/events.json (and of the bundled seed):
/// `name, kind, organiser, date, start, end, place, join, url, status, storm_note, topics[], read_at, verified`.
/// `start` and `end` may be null. Every field but `name` is optional on the wire; a missing date is "" (shown as not published).
public struct FringeEvent: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    public let kind: String
    public let organiser: String
    public let date: String          // "2026-11-12", Lisbon time; "" when the feed has none
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
    /// Added by the site within v1: a stable id, the cost as stated, whether the storm moved the event, the label
    /// (fact, evidence or hypothesis) and what the checker found. All optional.
    public let explicitID: String
    public let cost: String
    public let label: String
    public let stormMoved: Bool?
    public let check: String

    enum CodingKeys: String, CodingKey {
        case name, kind, organiser, date, start, end, place, join, url, status
        case stormNote = "storm_note", topics
        case readAt = "read_at", verified, note
        case explicitID = "id", cost, label, stormMoved = "storm_moved", check
    }

    public init(name: String, kind: String = "other", organiser: String = "", date: String, start: String? = nil,
                end: String? = nil, place: String = "", join: String = "", url: URL? = nil, status: String = "unknown",
                stormNote: String = "", topics: [String] = [], readAt: String? = nil, verified: Bool = false, note: String = "",
                id: String = "", cost: String = "", label: String = "", stormMoved: Bool? = nil, check: String = "") {
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
        self.explicitID = id
        self.cost = cost
        self.label = label
        self.stormMoved = stormMoved
        self.check = check
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let startTime = Self.parseTime(try? c.decodeIfPresent(String.self, forKey: .start))
        let endTime = Self.parseTime(try? c.decodeIfPresent(String.self, forKey: .end))
        // `date` is the day the event starts; when the feed has none, the start's own day (an ISO instant) stands in.
        let givenDate = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        date = givenDate.isEmpty ? (startTime?.day ?? "") : givenDate
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "other"
        organiser = (try? c.decodeIfPresent(String.self, forKey: .organiser)) ?? ""
        start = startTime?.clock
        end = endTime?.clock
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
        explicitID = (try? c.decodeIfPresent(String.self, forKey: .explicitID)) ?? ""
        cost = (try? c.decodeIfPresent(String.self, forKey: .cost)) ?? ""
        label = ((try? c.decodeIfPresent(String.self, forKey: .label)) ?? "").lowercased()
        stormMoved = try? c.decodeIfPresent(Bool.self, forKey: .stormMoved)
        check = (try? c.decodeIfPresent(String.self, forKey: .check)) ?? ""
    }

    /// A start or end as the Lisbon clock (and day, when the value carries one): "18:30", or an ISO 8601 instant such as
    /// "2026-11-11T18:30:00Z" (what events.json serves), converted to Lisbon time. nil for anything else.
    static func parseTime(_ raw: String?) -> (clock: String, day: String?)? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        guard raw.contains("T") else { return clock(raw).map { ($0, nil) } }
        let variants: [ISO8601DateFormatter.Options] = [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]]
        let formatter = ISO8601DateFormatter()
        for options in variants {
            formatter.formatOptions = options
            if let date = formatter.date(from: raw) {
                let parts = Lisbon.calendar.dateComponents([.hour, .minute], from: date)
                return (String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0), Lisbon.day(date))
            }
        }
        // No zone: the day and the clock as written, taken as Lisbon time.
        let pieces = raw.split(separator: "T", maxSplits: 1).map(String.init)
        if pieces.count == 2, let time = clock(pieces[1]) { return (time, pieces[0]) }
        return nil
    }

    /// A clock as "HH:mm", or nil for anything else (null, empty, "TBC").
    static func clock(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), value.count >= 4 else { return nil }
        let parts = value.prefix(5).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    /// The pick key: the site's `id` when it has one, else the day, the name and the start, so it holds across refreshes.
    public var id: String {
        if !explicitID.isEmpty { return Self.pageSafe(explicitID) }
        return "\(date)-\(Self.slug(name))-\((start ?? "").replacingOccurrences(of: ":", with: ""))"
    }

    static func pageSafe(_ text: String) -> String {
        String(text.unicodeScalars.map { scalar -> Character in
            (scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == ".")) ? Character(scalar) : "-"
        })
    }

    /// The site's own label for how sure it is: fact, evidence or hypothesis; nil when it says nothing.
    public var labelText: String? {
        switch label {
        case "fact": String(localized: "Fact", bundle: .module)
        case "evidence": String(localized: "Evidence", bundle: .module)
        case "hypothesis": String(localized: "Hypothesis", bundle: .module)
        default: nil
        }
    }

    public var movedByStorm: Bool { stormMoved == true }

    public var statusValue: FringeStatus { FringeStatus(feed: status) }
    public var startDate: Date? { start.flatMap { Lisbon.instant(day: date, clock: $0) } }
    /// The end, or nil when the feed has none.
    public var endDate: Date? {
        guard let end = end.flatMap({ Lisbon.instant(day: date, clock: $0) }) else { return nil }
        // An event that ends after midnight has an end clock earlier than its start.
        if let start = startDate, end < start { return Lisbon.calendar.date(byAdding: .day, value: 1, to: end) }
        return end
    }
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
