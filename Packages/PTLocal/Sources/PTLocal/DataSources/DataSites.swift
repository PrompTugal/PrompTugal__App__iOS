import Foundation

/// One of the public PrompTugal.news sites the app can show as a data source: what it covers, where it lives and the
/// one small feed the app reads to count its items and learn when it last read its data.
public struct DataSite: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let covers: String
    public let site: URL
    /// The feed read for the count and read time; nil when the site is read through data.promptugal.news's catalogue
    /// or publishes pages only.
    public let feed: URL?

    /// The 13 sites, in the order the screen shows them.
    public static let all: [DataSite] = [
        DataSite(id: "news", name: "promptugal.news",
                 covers: "The newsroom: articles, stories, companies and events, place by place, each with its source.",
                 site: URL(string: "https://promptugal.news")!,
                 feed: URL(string: "https://promptugal.news/api/v1/since.json")!),
        DataSite(id: "data", name: "data.promptugal.news",
                 covers: "The raw public data behind every site, collected by code: weather, events, contracts, flights, cameras, signals, cyber.",
                 site: URL(string: "https://data.promptugal.news")!,
                 feed: DataIndex.url),
        DataSite(id: "weather", name: "weather.promptugal.news",
                 covers: "IPMA warnings, forecasts, fire risk, sea and UV, and MeteoAlarm. Not a warning service: follow IPMA and ANEPC.",
                 site: URL(string: "https://weather.promptugal.news")!, feed: nil),
        DataSite(id: "events", name: "events.promptugal.news",
                 covers: "Official events from councils, theatres and venues, place by place.",
                 site: URL(string: "https://events.promptugal.news")!, feed: nil),
        DataSite(id: "civic", name: "civic.promptugal.news",
                 covers: "The 16 Algarve councils: public contracts, procurement notices and where each publishes its papers.",
                 site: URL(string: "https://civic.promptugal.news")!,
                 feed: URL(string: "https://civic.promptugal.news/api/v1/councils.json")!),
        DataSite(id: "live", name: "live.promptugal.news",
                 covers: "Public cameras by place: what each shows and the operator's own link.",
                 site: URL(string: "https://live.promptugal.news")!,
                 feed: URL(string: "https://live.promptugal.news/api/v1/places/index.json")!),
        DataSite(id: "bulletins", name: "bulletins.promptugal.news",
                 covers: "Short teletext-style bulletins written by agents from the data, every fact sourced.",
                 site: URL(string: "https://bulletins.promptugal.news")!,
                 feed: URL(string: "https://bulletins.promptugal.news/api/v1/index.json")!),
        DataSite(id: "signals", name: "signals.promptugal.news",
                 covers: "Public posts by organisations, by link, topic and place.",
                 site: URL(string: "https://signals.promptugal.news")!, feed: nil),
        DataSite(id: "cyber", name: "cyber.promptugal.news",
                 covers: "A weekly pulse of known-exploited and new vulnerabilities.",
                 site: URL(string: "https://cyber.promptugal.news")!,
                 feed: URL(string: "https://cyber.promptugal.news/api/v1/pulse/index.json")!),
        DataSite(id: "library", name: "library.promptugal.news",
                 covers: "Talks, replays and articles, catalogued with their publishers.",
                 site: URL(string: "https://library.promptugal.news")!,
                 feed: URL(string: "https://library.promptugal.news/api/v1/items/index.json")!),
        DataSite(id: "videos", name: "videos.promptugal.news",
                 covers: "Videos, summit replays among them, with their platforms.",
                 site: URL(string: "https://videos.promptugal.news")!,
                 feed: URL(string: "https://videos.promptugal.news/api/v1/videos/index.json")!),
        DataSite(id: "startups", name: "startups.promptugal.news",
                 covers: "Startups and their funding: incubators, programmes, rounds, grants and investors, place by place.",
                 site: URL(string: "https://startups.promptugal.news")!, feed: nil),
        DataSite(id: "travel", name: "travel.promptugal.news",
                 covers: "Travel in the Algarve: flights at Faro, getting around, disruptions, weather and sea for visitors.",
                 site: URL(string: "https://travel.promptugal.news")!,
                 feed: URL(string: "https://travel.promptugal.news/api/v1/manifest.json")!),
    ]
}

/// What the app learnt about a site from its feed: how many items, of what, and when the site read its data.
public struct SiteReading: Sendable, Equatable {
    public var count: Int?
    public var unit: String
    public var readAt: Date?
    public var note: String?

    public init(count: Int?, unit: String, readAt: Date?, note: String? = nil) {
        self.count = count
        self.unit = unit
        self.readAt = readAt
        self.note = note
    }

    /// "593 events", or the unit alone when there is no count.
    public var countText: String? {
        guard let count else { return nil }
        return "\(count) \(unit)"
    }
}

/// data.promptugal.news's catalogue (/api/v1/index.json): its sources, each with cadence, status and read time.
public struct DataIndex: Decodable, Sendable {
    public let version: String?
    public let builtAt: String?
    public let sources: [Source]

    public static let url = URL(string: "https://data.promptugal.news/api/v1/index.json")!

    enum CodingKeys: String, CodingKey { case version, sources, builtAt = "built_at" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try? c.decode(String.self, forKey: .version)
        builtAt = try? c.decode(String.self, forKey: .builtAt)
        sources = c.lenientArray(Source.self, forKey: .sources)
    }

    public struct Source: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        public let publisher: String?
        public let cadence: String?
        public let readAt: String?
        public let status: String?
        public let headline: String?
        public let page: String?

        enum CodingKeys: String, CodingKey { case id, title, publisher, cadence, status, headline, page, readAt = "read_at" }

        public var readDate: Date? { NewsroomDate.parse(readAt) }
        public var pageURL: URL? { page.flatMap { PlaceSite.safeURL($0) } }
        public var isArchived: Bool { status == "archived" }
    }

    /// Exact ids only: "ipma-uv" is one source, "ipma" is not a prefix match.
    public func source(_ id: String) -> Source? { sources.first { $0.id == id } }

    /// The weather sources: IPMA's feeds and MeteoAlarm.
    public var weatherSources: [Source] {
        sources.filter { $0.id.hasPrefix("ipma-") || $0.id == "meteoalarm-pt" }
    }

    /// The newest read among the live sources (archived ones are left out).
    public var newestRead: Date? {
        sources.filter { !$0.isArchived }.compactMap(\.readDate).max()
    }
}

/// Reads each site's feed into a `SiteReading`. Pure: the store hands it bytes, the tests hand it fixtures.
public enum DataSiteProbe {
    /// For a site with its own feed.
    public static func reading(site id: String, data: Data) -> SiteReading? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        switch id {
        case "news":
            let days = json["days"] as? Int
            let unit = days.map { "items in the last \($0) days" } ?? "items"
            return SiteReading(count: count(json["items"]), unit: unit, readAt: date(json["built"]))
        case "data":
            return SiteReading(count: count(json["sources"]), unit: "sources", readAt: newest(json["sources"], key: "read_at"))
        case "civic":
            return SiteReading(count: count(json["councils"]), unit: "councils", readAt: newest(json["sources"], key: "read_on"))
        case "live":
            let cameras = firstNumber(json["register_state"] as? String)
            return SiteReading(count: cameras ?? count(json["places"]), unit: cameras == nil ? "places" : "cameras",
                               readAt: date(json["read_at"]))
        case "bulletins":
            return SiteReading(count: count(json["bulletins"]), unit: "bulletins", readAt: date(json["made"]))
        case "cyber":
            return SiteReading(count: count(json["series"]), unit: "weekly series", readAt: date(json["updated"]))
        case "library":
            let total = (json["count"] as? Int) ?? count(json["items"])
            return SiteReading(count: total, unit: "items", readAt: nil, note: "The catalogue gives no read time.")
        case "videos":
            let total = (json["count"] as? Int) ?? count(json["videos"])
            return SiteReading(count: total, unit: "videos", readAt: date(json["updated"]))
        case "travel":
            return SiteReading(count: count(json["places"]), unit: "places", readAt: date(json["read_at"]))
        default:
            return nil
        }
    }

    /// For a site read through data.promptugal.news's catalogue.
    public static func reading(site id: String, index: DataIndex) -> SiteReading? {
        switch id {
        case "weather":
            let feeds = index.weatherSources
            guard !feeds.isEmpty else { return nil }
            let warnings = index.source("ipma-warnings")?.headline
            return SiteReading(count: feeds.count, unit: "IPMA and MeteoAlarm feeds",
                               readAt: feeds.compactMap(\.readDate).max(), note: warnings.map { "IPMA: \($0)" })
        case "events":
            return fromSource(index.source("events-pt"), unit: "events")
        case "signals":
            return fromSource(index.source("social"), unit: "posts")
        default:
            return nil
        }
    }

    private static func fromSource(_ source: DataIndex.Source?, unit: String) -> SiteReading? {
        guard let source else { return nil }
        let note = source.status == "ok" ? nil : source.status.map { "Last read: \($0)" }
        return SiteReading(count: firstNumber(source.headline), unit: unit, readAt: source.readDate, note: note)
    }

    static func count(_ value: Any?) -> Int? { (value as? [Any])?.count }

    static func date(_ value: Any?) -> Date? { NewsroomDate.parse(value as? String) }

    static func newest(_ value: Any?, key: String) -> Date? {
        guard let items = value as? [[String: Any]] else { return nil }
        return items.compactMap { NewsroomDate.parse($0[key] as? String) }.max()
    }

    /// The first whole number in "593 events" or "read (913 cameras kept, 0 skipped)".
    static func firstNumber(_ text: String?) -> Int? {
        guard let text else { return nil }
        var digits = ""
        for character in text {
            if character.isASCII, character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }
}
