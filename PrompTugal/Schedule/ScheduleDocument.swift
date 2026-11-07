import Foundation

/// The website's schedule, `localStorage['nr.schedule.v1']` on promptugal.news, unchanged on the wire:
///
///     { "v": 1, "picks": [ { "id": "ai-doom-or-boom", "at": "2026-11-08T03:12:45.120Z" } ] }
///
/// Read from `assets/schedule/schedule.js` (site v0.1.414):
/// - `id` is the event's slug only: the `<slug>` of `events/<slug>/index.html`, with no `events/` prefix.
/// - `at` is written by the website as `new Date().toISOString()`. Contracts §3 says Unix milliseconds,
///   so both are accepted when reading. The app always writes the website's ISO form.
/// - The website ignores any other key, and keeps unknown keys when it rewrites the document.
struct ScheduleDocument: Codable, Equatable, Sendable {
    static let storageKey = "nr.schedule.v1"
    static let changeEvent = "nr:schedule"

    var v: Int = 1
    var picks: [WirePick]

    init(picks: [WirePick] = []) { self.picks = picks }

    struct WirePick: Codable, Equatable, Sendable {
        let id: String
        let at: Date

        init(id: String, at: Date) {
            self.id = id
            self.at = at
        }

        private enum CodingKeys: String, CodingKey { case id, at }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            if let millis = try? container.decode(Double.self, forKey: .at) {
                at = Date(timeIntervalSince1970: millis / 1000)
            } else if let text = try? container.decode(String.self, forKey: .at), let date = ScheduleTime.parse(text) {
                at = date
            } else {
                // A pick with no readable time still counts; it is treated as the oldest possible pick.
                at = .distantPast
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(ScheduleTime.format(at), forKey: .at)
        }
    }

    /// Lenient decoding of what a page or a vault holds. Returns nil when it is not a v1 schedule,
    /// the same test the website applies (`s.v === 1 && Array.isArray(s.picks)`).
    static func decode(_ data: Data) -> ScheduleDocument? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (raw["v"] as? NSNumber)?.intValue == 1,
              let list = raw["picks"] as? [Any] else { return nil }
        let decoder = JSONDecoder()
        var picks: [WirePick] = []
        var seen = Set<String>()
        for entry in list {
            guard JSONSerialization.isValidJSONObject(entry),
                  let item = try? JSONSerialization.data(withJSONObject: entry),
                  let pick = try? decoder.decode(WirePick.self, from: item),
                  ScheduleID.isValid(pick.id), seen.insert(pick.id).inserted else { continue }
            picks.append(pick)
        }
        return ScheduleDocument(picks: picks)
    }

    static func decode(_ text: String) -> ScheduleDocument? {
        decode(Data(text.utf8))
    }

    func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return (try? encoder.encode(self)) ?? Data(#"{"v":1,"picks":[]}"#.utf8)
    }

    var json: String { String(decoding: encoded(), as: UTF8.self) }
}

/// Pick ids, as the website makes them.
enum ScheduleID {
    /// The pattern the website uses: `(?:^|\/)events\/([^/]+)\/index\.html$`.
    static func fromPage(_ page: String) -> String? {
        let path = page.split(separator: "?").first.map(String.init) ?? page
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, parts[parts.count - 1] == "index.html", parts[parts.count - 3] == "events" else {
            return nil
        }
        let slug = parts[parts.count - 2]
        return slug.isEmpty ? nil : slug
    }

    static func page(for id: String) -> String { "events/\(id)/index.html" }

    /// A slug as the website's regex would capture it: not empty, no slash, short enough to be sane.
    static func isValid(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 200 && !id.contains("/") && id.trimmingCharacters(in: .whitespacesAndNewlines) == id
    }
}

/// The ISO 8601 form JavaScript's `toISOString()` writes: UTC, milliseconds, `Z`.
enum ScheduleTime {
    /// Exactly `toISOString()`'s form. Built from whole milliseconds (rounded), so a time read from the website is
    /// written back character for character, whatever binary rounding the `Date` picked up on the way.
    static func format(_ date: Date) -> String {
        guard date != .distantPast else { return "1970-01-01T00:00:00.000Z" }
        let millis = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let seconds = millis >= 0 ? millis / 1000 : (millis - 999) / 1000
        let fraction = Int(millis - seconds * 1000)
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                       from: Date(timeIntervalSince1970: TimeInterval(seconds)))
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", parts.year ?? 1970, parts.month ?? 1,
                      parts.day ?? 1, parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, fraction)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Also reads the team site's short form, "2026-11-06T22:29Z" (no seconds).
    static func parse(_ text: String) -> Date? {
        if let date = withFractional.date(from: text) ?? plain.date(from: text) { return date }
        if text.count == 17, text.hasSuffix("Z"), text.dropFirst(10).first == "T" {
            return plain.date(from: String(text.dropLast()) + ":00Z")
        }
        return nil
    }

    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
