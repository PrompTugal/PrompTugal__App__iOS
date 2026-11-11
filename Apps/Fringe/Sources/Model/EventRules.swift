import Foundation

/// Which pill an event belongs under, or hidden.
enum EventCategory: Equatable, Sendable {
    case inPerson(nearLisbon: Bool)
    case online
    case hidden
}

/// Status words shown on rows and as the detail banner.
enum EventStatus: Equatable, Sendable {
    case on, moved, cancelled, notConfirmed, online

    var word: String? {
        switch self {
        case .moved: "Moved"
        case .cancelled: "Cancelled"
        case .notConfirmed: "Not confirmed"
        case .on, .online: nil
        }
    }
}

/// Plain rules on top of the feed. All of them are tested in Tests/LogicTests.swift.
extension FeedEvent {
    private static let nearTowns = ["Sintra", "Estoril"]
    private static let farTowns = ["Covilhã", "Covilha", "Mértola", "Mertola", "Santarém", "Santarem"]

    var isOnline: Bool {
        status?.lowercased() == "online" || (place ?? "").lowercased().hasPrefix("online")
    }

    var category: EventCategory {
        if isOnline { return .online }
        let p = place ?? ""
        if Self.farTowns.contains(where: { p.contains($0) }) { return .hidden }
        if Self.nearTowns.contains(where: { p.contains($0) }) { return .inPerson(nearLisbon: true) }
        if inLisbon == true { return .inPerson(nearLisbon: false) }
        if inLisbon == nil, p.contains("Lisboa") || p.contains("Lisbon") { return .inPerson(nearLisbon: false) }
        return .hidden
    }

    var eventStatus: EventStatus {
        switch status?.lowercased() {
        case "moved", "postponed": .moved
        case "cancelled", "canceled": .cancelled
        case "unknown": .notConfirmed
        case "online": .online
        default: .on
        }
    }

    // MARK: Place

    /// Private addresses get no Map button.
    var isPrivateAddress: Bool {
        (place ?? "").lowercased().contains("guests")
    }

    /// The place without notes about where the address came from.
    var cleanPlace: String {
        var p = place ?? ""
        if let semi = p.firstIndex(of: ";") { p = String(p[..<semi]) }
        p = Self.removingParentheticals(in: p) { inner in
            let l = inner.lowercased()
            return l.contains("page") || l.hasPrefix("per ") || l.contains("as shown")
        }
        return p.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    }

    /// The trailing "(Beato)" of a place, when it is a short area name.
    private var placeArea: String? {
        let p = cleanPlace
        guard p.hasSuffix(")"), let open = p.lastIndex(of: "(") else { return nil }
        let inner = String(p[p.index(after: open)..<p.index(before: p.endIndex)])
        return inner.count <= 32 && !inner.lowercased().contains("guests") ? inner : nil
    }

    private var placeWithoutArea: String {
        let p = cleanPlace
        guard placeArea != nil, let open = p.lastIndex(of: "(") else { return p }
        return String(p[..<open]).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    }

    /// Address segments, with repeats removed.
    private var segments: [String] {
        var out: [String] = []
        for s in placeWithoutArea.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !s.isEmpty {
            if out.last != s { out.append(s) }
        }
        return out
    }

    /// The short area on a row: "Beato, Lisboa", "Sintra, near Lisbon", "Online".
    var area: String {
        switch category {
        case .online:
            return "Online"
        case .inPerson(nearLisbon: true):
            let town = Self.nearTowns.first { (place ?? "").contains($0) } ?? "Outside Lisbon"
            return "\(town), near Lisbon"
        default:
            if isPrivateAddress { return "Address given to guests, Lisboa" }
            let name = neighbourhood ?? placeArea ?? segments.first ?? "Lisboa"
            return name.hasSuffix("Lisboa") ? name : "\(name), Lisboa"
        }
    }

    /// Two lines for the Where card.
    var addressLines: (first: String, second: String?) {
        if isOnline {
            let p = cleanPlace
            let how = p.lowercased().hasPrefix("online") ? String(p.dropFirst(6)) : p
            let detail = how.trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
            return ("Online", detail.isEmpty ? nil : detail)
        }
        if isPrivateAddress {
            return ("Address given to guests", area)
        }
        let segs = segments
        let near = neighbourhood ?? placeArea
        guard let last = segs.last else { return (area, nil) }
        if segs.count == 1 { return (last, near.map { "Near \($0)" }) }
        let first = segs.dropLast().joined(separator: ", ")
        return (first, near.map { "\(last), near \($0)" } ?? last)
    }

    /// The text the Show address view shows in large type.
    var fullAddress: String {
        let lines = addressLines
        return [lines.first, lines.second].compactMap { $0 }.joined(separator: "\n")
    }

    /// Apple Maps search on the address. None for private or online places.
    var mapsURL: URL? {
        guard !isOnline, !isPrivateAddress else { return nil }
        let query = placeWithoutArea.isEmpty ? cleanPlace : placeWithoutArea
        guard !query.isEmpty else { return nil }
        var comps = URLComponents(string: "https://maps.apple.com/")
        comps?.queryItems = [URLQueryItem(name: "q", value: query)]
        return comps?.url
    }

    // MARK: Host, type, cost, join

    var hostName: String {
        let raw = (organiser ?? "").trimmingCharacters(in: .whitespaces)
        if raw.isEmpty || raw.lowercased().hasPrefix("unknown") { return "Host not named" }
        let cleaned = Self.removingParentheticals(in: raw) { $0.lowercased().contains("page") }
            .trimmingCharacters(in: .whitespaces)
        return Self.capitalisedFirst(cleaned.isEmpty ? raw : cleaned)
    }

    var kindLabel: String {
        Self.capitalisedFirst(kind?.trimmingCharacters(in: .whitespaces).nonEmpty ?? "Event")
    }

    var costLabel: String? {
        guard let c = cost?.trimmingCharacters(in: .whitespaces), !c.isEmpty,
              c.lowercased() != "not stated", c.lowercased() != "unknown" else { return nil }
        return Self.capitalisedFirst(c)
    }

    /// "Register on the event website" and similar, when the join text says so.
    var joinLine: String? {
        let j = (join ?? "").lowercased()
        if j.contains("no longer public") { return "The event page is no longer public" }
        if j.contains("sold out") { return "Sold out. The event website may have a waiting list" }
        if j.contains("approval") || j.contains("by application") || j.contains("approved") {
            return "The host approves guests. Apply on the event website"
        }
        if j.contains("register") || j.contains("registration") || j.contains("ticket") || j.contains("pass") {
            return "Register on the event website"
        }
        return nil
    }

    var websiteURL: URL? {
        if let u = url, let url = URL(string: u), url.scheme?.hasPrefix("http") == true { return url }
        guard let j = join, let range = j.range(of: #"https?://[^\s]+"#, options: .regularExpression) else { return nil }
        return URL(string: String(j[range]))
    }

    // MARK: Time

    /// Minutes from midnight of the event's start day.
    var startMinute: Int? { minutes(of: start) }
    var endMinute: Int? { minutes(of: end) }

    private func minutes(of date: Date?) -> Int? {
        guard let date, let dayStart = FeedDate.startOfDay(self.date) else { return nil }
        return Int(date.timeIntervalSince(dayStart) / 60)
    }

    /// True when the event ends after midnight of its start day.
    var endsNextDay: Bool { (endMinute ?? 0) > 24 * 60 }

    var startText: String { start.map(FeedDate.hhmm) ?? "Time not given" }

    /// "02:00 +1"
    var endText: String? {
        guard let end else { return nil }
        return FeedDate.hhmm(end) + (endsNextDay ? " +1" : "")
    }

    /// "17:00 to 19:30", or "21:00 to 02:00 +1"
    var timeRange: String {
        guard start != nil else { return "Time not given" }
        guard let endText else { return "From \(startText)" }
        return "\(startText) to \(endText)"
    }

    /// The span used for clashes and On now. An event with no end counts as one hour.
    var interval: DateInterval? {
        guard let start else { return nil }
        let finish = end.flatMap { $0 > start ? $0 : nil } ?? start.addingTimeInterval(3600)
        return DateInterval(start: start, end: finish)
    }

    func isOn(at now: Date) -> Bool {
        guard eventStatus != .cancelled, let i = interval else { return false }
        return i.start <= now && now < i.end
    }

    /// True when the two events share some time. Touching ends do not count.
    func overlaps(_ other: FeedEvent) -> Bool {
        guard id != other.id, let a = interval, let b = other.interval else { return false }
        return a.start < b.end && b.start < a.end
    }

    // MARK: Helpers

    static func capitalisedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    static func removingParentheticals(in s: String, where drop: (String) -> Bool) -> String {
        var out = ""
        var depth = 0
        var current = ""
        for ch in s {
            if ch == "(" {
                if depth == 0 { current = "" } else { current.append(ch) }
                depth += 1
            } else if ch == ")", depth > 0 {
                depth -= 1
                if depth == 0 {
                    if !drop(current) { out += "(\(current))" }
                } else {
                    current.append(ch)
                }
            } else if depth > 0 {
                current.append(ch)
            } else {
                out.append(ch)
            }
        }
        if depth > 0 { out += "(" + current }
        return out.replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: " ,", with: ",")
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
