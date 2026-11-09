import Foundation

public struct Event: Codable, Identifiable, Hashable {
    public let date: String
    public let time: String
    public let title: String
    public let place: String
    public let kind: String
    public let official: Bool
    public let page: String
    /// How the session shows on a calendar: "free" or "busy" (the feed's `shows_as`). Nil when the feed does not say,
    /// so older feeds still decode.
    public let showsAs: String?

    public init(date: String, time: String, title: String, place: String, kind: String, official: Bool, page: String,
                showsAs: String? = nil) {
        self.date = date
        self.time = time
        self.title = title
        self.place = place
        self.kind = kind
        self.official = official
        self.page = page
        self.showsAs = showsAs
    }

    private enum CodingKeys: String, CodingKey {
        case date, time, title, place, kind, official, page
        case showsAs = "shows_as"
    }

    public var id: String { page }
    public var url: URL? { URL(string: page, relativeTo: FeedClient.site)?.absoluteURL }
    public var detailURL: URL? {
        let parts = page.split(separator: "/")
        guard parts.count == 3, parts[0] == "events", parts[2] == "index.html" else { return nil }
        return FeedClient.site.appendingPathComponent("api/v1/events/\(parts[1]).json")
    }

    public var start: Date? { Lisbon.instant(day: date, clock: String(time.prefix(5))) }
    public var end: Date? {
        let parts = time.split(separator: "-")
        guard parts.count == 2, let start,
              let end = Lisbon.instant(day: date, clock: String(parts[1])) else { return nil }
        return end < start ? Lisbon.calendar.date(byAdding: .day, value: 1, to: end) : end
    }

    public static func earlier(_ lhs: Event, _ rhs: Event) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.time != rhs.time { return lhs.time < rhs.time }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

public enum Lisbon {
    public static let zone = TimeZone(identifier: "Europe/Lisbon")!
    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }()

    public static func instant(day: String, clock: String = "12:00") -> Date? {
        let date = day.split(separator: "-").compactMap { Int($0) }
        let time = clock.split(separator: ":").compactMap { Int($0) }
        guard date.count == 3, time.count == 2,
              (0..<24).contains(time[0]), (0..<60).contains(time[1]) else { return nil }
        return calendar.date(from: DateComponents(year: date[0], month: date[1], day: date[2],
                                                  hour: time[0], minute: time[1]))
    }

    public static func dayLabel(_ day: String) -> String {
        guard let date = instant(day: day) else { return day }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none, in: zone)
    }

    public static func timeLabel(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short, in: zone)
    }
}

private extension DateFormatter {
    static func localizedString(from date: Date, dateStyle: Style, timeStyle: Style, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = zone
        formatter.locale = AppCulture.locale     // the reader's chosen culture, not the device's
        return formatter.string(from: date)
    }
}

public struct EventDetail: Codable {
    public let sourceURL: URL?
    public let sessionURL: URL?
    public let readAt: String?
    public let whereText: String?

    public init(sourceURL: URL?, sessionURL: URL?, readAt: String?, whereText: String?) {
        self.sourceURL = sourceURL
        self.sessionURL = sessionURL
        self.readAt = readAt
        self.whereText = whereText
    }

    public enum CodingKeys: String, CodingKey {
        case sourceURL = "source_url"
        case sessionURL = "session_url"
        case readAt = "read_at"
        case whereText = "where"
    }

    public var checkedOn: Date? {
        guard let readAt else { return nil }
        return ISO8601DateFormatter().date(from: readAt)
            ?? ISO8601DateFormatter().date(from: readAt.replacingOccurrences(
                of: #"T(\d{2}:\d{2})Z$"#, with: "T$1:00Z", options: .regularExpression
            ))
    }
}

public struct Story: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let summary: String
    public let category: String
    public let published: Date?
    public let url: URL

    public init(id: String, title: String, summary: String, category: String, published: Date?, url: URL) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.published = published
        self.url = url
    }
}

public enum FeedClient {
    public static let site = URL(string: "https://promptugal.news/")!
    public static let fullAgenda = site.appendingPathComponent("events/index.html")
    public static let articleIndex = site.appendingPathComponent("articles/index.html")
    public static let disclosure = site.appendingPathComponent("about/participant.html")

    private struct AgendaFeed: Decodable { let items: [Event] }
    private struct EventEnvelope: Decodable { let data: EventDetail }

    public static func agenda() async throws -> [Event] {
        let data = try await get(site.appendingPathComponent("api/v1/live/agenda.json"), label: "feed.agenda")
        return try JSONDecoder().decode(AgendaFeed.self, from: data).items.sorted(by: Event.earlier)
    }

    public static func news() async throws -> [Story] {
        let data = try await get(site.appendingPathComponent("feed.xml"), label: "feed.news")
        return try RSSReader().read(data)
    }

    public static func detail(for event: Event) async throws -> EventDetail {
        guard let url = event.detailURL else { throw URLError(.badURL) }
        return try JSONDecoder().decode(EventEnvelope.self, from: await get(url, label: "feed.event")).data
    }

    private static func get(_ url: URL, label: String) async throws -> Data {
        try await HTTPClient.shared.get(url, timeout: 15, label: label)
    }
}

private final class RSSReader: NSObject, XMLParserDelegate {
    private let fields: Set<String> = ["title", "description", "link", "guid", "pubDate", "category"]
    private var path: [String] = []
    private var current: [String: String] = [:]
    private var stories: [Story] = []
    private var identifiers: Set<String> = []
    private var sawChannel = false
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }()

    func read(_ data: Data) throws -> [Story] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), sawChannel else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return stories
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes attributeDict: [String: String]) {
        path.append(elementName)
        if path == ["rss", "channel"] { sawChannel = true }
        if path == ["rss", "channel", "item"] { current.removeAll(keepingCapacity: true) }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) { append(string) }
    }

    private func append(_ value: String) {
        guard path.count == 4, path[2] == "item", let field = path.last, fields.contains(field) else { return }
        current[field, default: ""] += value
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        if path == ["rss", "channel", "item"] { appendStory() }
        _ = path.popLast()
    }

    private func appendStory() {
        let values = current.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let title = values["title"], !title.isEmpty, let link = values["link"],
              let url = URL(string: link), url.scheme == "https", url.host == FeedClient.site.host else { return }
        let id = values["guid"].flatMap { $0.isEmpty ? nil : $0 } ?? link
        guard identifiers.insert(id).inserted else { return }
        stories.append(Story(id: id, title: title, summary: values["description"] ?? "",
                             category: values["category"] ?? "",
                             published: values["pubDate"].flatMap { formatter.date(from: $0) }, url: url))
    }
}
