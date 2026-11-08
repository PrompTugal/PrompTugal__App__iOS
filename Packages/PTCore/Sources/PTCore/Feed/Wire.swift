import Foundation

/// Thin, lenient Decodable models over the public JSON the dashboards read.
/// Every field is optional, so a new or missing field on the website never
/// breaks a screen. When the team session's TeamStore lands, the team models
/// here can be swapped for theirs; the newsroom and graph models stay here.
///
/// Sources (all public, no keys):
/// - web-summit.sgit.ai/me.json, /people/<id>/app/data.json
/// - promptugal.news/api/v1/newsroom/{dashboard,status,stories,decisions,desks}.json
/// - promptugal.news/api/v1/newsletter.json, /api/v1/graph/explorer.json
public enum Wire {}

/// A string that may arrive as a string, a number or an object with a text field.
public struct LooseText: Decodable, Hashable, Sendable {
    public let text: String
    public let who: String?

    public init(_ text: String, who: String? = nil) { self.text = text; self.who = who }

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let string = try? single.decode(String.self) {
            self.init(string)
        } else if let number = try? single.decode(Double.self) {
            self.init(number.formatted())
        } else if let object = try? single.decode([String: LooseScalar].self) {
            let text = ["ask", "text", "what", "title", "line", "subject", "note"]
                .compactMap { object[$0]?.string }.first
                ?? object.values.compactMap(\.string).joined(separator: " · ")
            self.init(text, who: (object["for"] ?? object["from"] ?? object["who"])?.string)
        } else {
            self.init("")
        }
    }
}

/// Any JSON scalar, kept as text.
public struct LooseScalar: Decodable, Hashable, Sendable {
    public let string: String?
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let value = try? single.decode(String.self) { string = value }
        else if let value = try? single.decode(Double.self) { string = value.formatted() }
        else if let value = try? single.decode(Bool.self) { string = value ? "yes" : "no" }
        else { string = nil }
    }
}

/// Parses the dates the sites write: full ISO 8601, with or without seconds or fractions.
public enum WireDate {
    public static func parse(_ text: String?) -> Date? {
        guard var text, !text.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        // "2026-11-07T00:37Z" (no seconds)
        if text.range(of: #"T\d{2}:\d{2}Z$"#, options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: "Z", with: ":00Z")
            return plain.date(from: text)
        }
        // "2026-11-06" (a day)
        if text.count == 10 { return Lisbon.instant(day: text, clock: "00:00") }
        return nil
    }
}
