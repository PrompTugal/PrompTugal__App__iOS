import Foundation

// MARK: - Events in a town (data.promptugal.news/api/v1/events/by-place/<id>.json)

/// Public events on now or starting soon in one place, as schema.org Event records, each with its source URL and the
/// time it was read. An empty list means no source covers the place yet, not that nothing is happening.
public struct TownEventsFeed: Decodable, Sendable {
    public let place: String?
    public let readAt: String?
    public let about: String?
    public let events: [Event]

    enum CodingKeys: String, CodingKey { case place, about, events, readAt = "read_at", dataReadAt = "data_read_at" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        place = try? c.decode(String.self, forKey: .place)
        readAt = (try? c.decode(String.self, forKey: .readAt)) ?? (try? c.decode(String.self, forKey: .dataReadAt))
        about = try? c.decode(String.self, forKey: .about)
        events = c.lenientArray(Event.self, forKey: .events)
    }

    public static func url(for placeID: String) -> URL {
        URL(string: "https://data.promptugal.news/api/v1/events/by-place/\(placeID).json")!
    }

    /// The feed's own read time.
    public var readDate: Date? { NewsroomDate.parse(readAt) }

    /// Events not over yet on `now`'s day (an event with no end is over after its start day), soonest first, each with
    /// a link. Dates are compared as days in Lisbon.
    public func upcoming(now: Date, limit: Int = 6) -> [Event] {
        let today = TownDay.string(now)
        var out: [Event] = []
        for event in events where event.link != nil {
            let last = event.endDate ?? event.startDate
            if let last, TownDay.prefix(last) >= today { out.append(event) }
        }
        out.sort { (TownDay.prefix($0.startDate ?? "")) < (TownDay.prefix($1.startDate ?? "")) }
        return Array(out.prefix(limit))
    }

    public struct Event: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { (url ?? name) + "|" + (startDate ?? "") }
        public let name: String
        public let startDate: String?
        public let endDate: String?
        public let venue: String?
        public let url: String?
        public let source: String?
        public let readAt: String?

        enum CodingKeys: String, CodingKey { case name, startDate, endDate, location, url, source, readAt = "read_at" }
        enum LocationKeys: String, CodingKey { case name }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            startDate = try? c.decode(String.self, forKey: .startDate)
            endDate = try? c.decode(String.self, forKey: .endDate)
            if let location = try? c.nestedContainer(keyedBy: LocationKeys.self, forKey: .location) {
                venue = try? location.decode(String.self, forKey: .name)
            } else {
                venue = try? c.decode(String.self, forKey: .location)
            }
            url = try? c.decode(String.self, forKey: .url)
            source = try? c.decode(String.self, forKey: .source)
            readAt = try? c.decode(String.self, forKey: .readAt)
        }

        /// The event's own page, else the first URL in its source line.
        public var link: URL? {
            if let url, let safe = PlaceSite.safeURL(url) { return safe }
            if let source, let first = source.split(separator: " ").first, let safe = PlaceSite.safeURL(String(first)) {
                return safe
            }
            return nil
        }
    }
}

// MARK: - Council notices (civic.promptugal.news)

/// The 16 Algarve councils' procurement notices still open (civic.promptugal.news/api/v1/use-cases/notices.json),
/// each linked to its notice in the Diário da República.
public struct CivicNotices: Decodable, Sendable {
    public let readOn: String?
    public let stillOpen: [Notice]

    public static let url = URL(string: "https://civic.promptugal.news/api/v1/use-cases/notices.json")!

    enum CodingKeys: String, CodingKey { case summary, stillOpen = "still_open" }
    enum SummaryKeys: String, CodingKey { case readOn = "read_on" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let summary = try? c.nestedContainer(keyedBy: SummaryKeys.self, forKey: .summary) {
            readOn = try? summary.decode(String.self, forKey: .readOn)
        } else {
            readOn = nil
        }
        stillOpen = c.lenientArray(Notice.self, forKey: .stillOpen)
    }

    public var readDate: Date? { NewsroomDate.parse(readOn) }

    /// One council's notices whose deadline is today or later (Lisbon days), soonest deadline first. Exact council id.
    public func open(council: String, now: Date) -> [Notice] {
        let today = TownDay.string(now)
        let mine = stillOpen.filter { $0.council == council && TownDay.prefix($0.deadline ?? "9999") >= today }
        return mine.sorted { ($0.deadline ?? "") < ($1.deadline ?? "") }
    }

    public struct Notice: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { notice }
        public let notice: String
        public let council: String
        public let published: String?
        public let deadline: String?
        public let what: String
        public let basePriceEUR: Double?
        public let diarioDaRepublica: String?

        enum CodingKeys: String, CodingKey {
            case notice, council, published, deadline, what
            case basePriceEUR = "base_price_eur", diarioDaRepublica = "diario_da_republica"
        }

        public var link: URL? { diarioDaRepublica.flatMap { PlaceSite.safeURL($0) } }
    }
}

/// One Algarve council's file (civic.promptugal.news/api/v1/councils/<id>.json): its page and its 2026 contracts.
public struct CivicCouncil: Decodable, Sendable {
    public let id: String
    public let name: String
    public let page: String?
    public let contracts2026: Int?
    public let value2026: Double?
    public let readOn: String?

    enum CodingKeys: String, CodingKey { case id, name, page, sources, contracts2026 = "contracts_2026" }
    enum ContractKeys: String, CodingKey { case contracts, valueEUR = "value_eur" }
    struct SourceRead: Decodable { let readOn: String?; enum CodingKeys: String, CodingKey { case readOn = "read_on" } }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        page = try? c.decode(String.self, forKey: .page)
        if let contracts = try? c.nestedContainer(keyedBy: ContractKeys.self, forKey: .contracts2026) {
            contracts2026 = try? contracts.decode(Int.self, forKey: .contracts)
            value2026 = try? contracts.decode(Double.self, forKey: .valueEUR)
        } else {
            contracts2026 = nil
            value2026 = nil
        }
        let sources = c.lenientArray(SourceRead.self, forKey: .sources)
        readOn = sources.compactMap(\.readOn).max()
    }

    public var pageURL: URL? { page.flatMap { PlaceSite.safeURL($0) } }
    public var readDate: Date? { NewsroomDate.parse(readOn) }

    /// The Algarve's 16 councils, by their civic ids.
    public static let ids: [String] = [
        "albufeira", "alcoutim", "aljezur", "castro-marim", "faro", "lagoa", "lagos", "loule", "monchique", "olhao",
        "portimao", "sao-bras-de-alportel", "silves", "tavira", "vila-do-bispo", "vila-real-de-santo-antonio",
    ]

    /// The council a place belongs to: itself for the 16 municipalities, Loulé for Quarteira, none otherwise.
    public static func council(for placeID: String) -> String? {
        if ids.contains(placeID) { return placeID }
        if placeID == "quarteira" { return "loule" }
        return nil
    }

    public static func url(for councilID: String) -> URL {
        URL(string: "https://civic.promptugal.news/api/v1/councils/\(councilID).json")!
    }
}

/// Days as "yyyy-MM-dd" in Lisbon, so string order is date order.
enum TownDay {
    static func string(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Lisbon")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// The day part of "2026-11-21" or "2026-11-21T19:00:00+00:00".
    static func prefix(_ text: String) -> String { String(text.prefix(10)) }
}
