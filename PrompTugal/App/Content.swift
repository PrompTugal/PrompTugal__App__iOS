import Foundation

struct Event: Codable, Identifiable, Hashable {
    let date: String
    let time: String
    let title: String
    let place: String
    let kind: String
    let official: Bool
    let page: String

    var id: String { page }
    var url: URL? { URL(string: page, relativeTo: FeedClient.site)?.absoluteURL }
    var detailURL: URL? {
        let parts = page.split(separator: "/")
        guard parts.count == 3, parts[0] == "events", parts[2] == "index.html" else { return nil }
        return FeedClient.site.appendingPathComponent("api/v1/events/\(parts[1]).json")
    }

    var start: Date? { Lisbon.instant(day: date, clock: String(time.prefix(5))) }
    var end: Date? {
        let parts = time.split(separator: "-")
        guard parts.count == 2, let start,
              let end = Lisbon.instant(day: date, clock: String(parts[1])) else { return nil }
        return end < start ? Lisbon.calendar.date(byAdding: .day, value: 1, to: end) : end
    }

    static func earlier(_ lhs: Event, _ rhs: Event) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.time != rhs.time { return lhs.time < rhs.time }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

enum Lisbon {
    static let zone = TimeZone(identifier: "Europe/Lisbon")!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }()

    static func instant(day: String, clock: String = "12:00") -> Date? {
        let date = day.split(separator: "-").compactMap { Int($0) }
        let time = clock.split(separator: ":").compactMap { Int($0) }
        guard date.count == 3, time.count == 2,
              (0..<24).contains(time[0]), (0..<60).contains(time[1]) else { return nil }
        return calendar.date(from: DateComponents(year: date[0], month: date[1], day: date[2],
                                                  hour: time[0], minute: time[1]))
    }

    static func dayLabel(_ day: String) -> String {
        guard let date = instant(day: day) else { return day }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none, in: zone)
    }

    static func timeLabel(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short, in: zone)
    }
}

private extension DateFormatter {
    static func localizedString(from date: Date, dateStyle: Style, timeStyle: Style, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = zone
        return formatter.string(from: date)
    }
}

struct EventDetail: Codable {
    let sourceURL: URL?
    let sessionURL: URL?
    let readAt: String?
    let whereText: String?

    enum CodingKeys: String, CodingKey {
        case sourceURL = "source_url"
        case sessionURL = "session_url"
        case readAt = "read_at"
        case whereText = "where"
    }

    var checkedOn: Date? {
        guard let readAt else { return nil }
        return ISO8601DateFormatter().date(from: readAt)
            ?? ISO8601DateFormatter().date(from: readAt.replacingOccurrences(
                of: #"T(\d{2}:\d{2})Z$"#, with: "T$1:00Z", options: .regularExpression
            ))
    }
}

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let published: Date?
    let url: URL
}

enum FeedClient {
    static let site = URL(string: "https://promptugal.news/")!
    static let fullAgenda = site.appendingPathComponent("events/index.html")
    static let articleIndex = site.appendingPathComponent("articles/index.html")
    static let disclosure = site.appendingPathComponent("about/participant.html")

    private struct AgendaFeed: Decodable { let items: [Event] }
    private struct EventEnvelope: Decodable { let data: EventDetail }

    static func agenda() async throws -> [Event] {
        let data = try await get(site.appendingPathComponent("api/v1/live/agenda.json"))
        return try JSONDecoder().decode(AgendaFeed.self, from: data).items.sorted(by: Event.earlier)
    }

    static func news() async throws -> [Story] {
        let data = try await get(site.appendingPathComponent("feed.xml"))
        return try RSSReader().read(data)
    }

    static func detail(for event: Event) async throws -> EventDetail {
        guard let url = event.detailURL else { throw URLError(.badURL) }
        return try JSONDecoder().decode(EventEnvelope.self, from: await get(url)).data
    }

    private static func get(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
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
