import CoreLocation
import Foundation

// MARK: - One place's site (promptugal.news/data/by-place/<id>.json)

/// One place's site, as its own agent (`place.<id>@PrompTugal.dinis`) writes it: schema
/// https://promptugal.news/data/schemas/by-place.schema.json. Every fact carries its URL and the date it was read.
/// Only `id`, `name`, `kind`, `parent`, `mandate`, `status`, `updated` and `by` are required there, so the rest is optional.
public struct PlaceSite: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let kind: String
    public let parent: String
    public let status: String
    public let updated: String
    public let by: String
    public let mandate: String
    public let gravity: Gravity?
    public let look: Look?
    public let aiNews: [News]
    public let aiMap: [MapEntry]
    public let events: [Event]
    public let sources: [Source]
    public let gaps: [String]
    public let voice: Voice?

    enum CodingKeys: String, CodingKey {
        case id, name, kind, parent, status, updated, by, mandate, gravity, look, events, sources, gaps, voice
        case aiNews = "ai_news", aiMap = "ai_map"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "municipality"
        parent = (try? c.decode(String.self, forKey: .parent)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? "stub"
        updated = (try? c.decode(String.self, forKey: .updated)) ?? ""
        by = (try? c.decode(String.self, forKey: .by)) ?? ""
        mandate = (try? c.decode(String.self, forKey: .mandate)) ?? ""
        gravity = try? c.decode(Gravity.self, forKey: .gravity)
        look = try? c.decode(Look.self, forKey: .look)
        // One bad item must not hide the rest of the place.
        aiNews = c.lenientArray(News.self, forKey: .aiNews)
        aiMap = c.lenientArray(MapEntry.self, forKey: .aiMap)
        events = c.lenientArray(Event.self, forKey: .events)
        sources = c.lenientArray(Source.self, forKey: .sources)
        gaps = (try? c.decode([String].self, forKey: .gaps)) ?? []
        voice = try? c.decode(Voice.self, forKey: .voice)
    }

    public static func == (a: PlaceSite, b: PlaceSite) -> Bool { a.id == b.id && a.updated == b.updated && a.by == b.by }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    public var isLive: Bool { status == "live" }

    public struct Gravity: Decodable, Sendable {
        public let text: String?
        public let sources: [Link]

        enum CodingKeys: String, CodingKey { case text, sources }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try? c.decode(String.self, forKey: .text)
            sources = c.lenientArray(Link.self, forKey: .sources)
        }
    }

    public struct Link: Decodable, Sendable, Hashable {
        public let title: String?
        public let url: String
        public let readOn: String?
        enum CodingKeys: String, CodingKey { case title, url, readOn = "read_on" }
    }

    public struct Look: Decodable, Sendable {
        public let accent: String?
        public let landmark: String?
        public let motif: String?
    }

    public struct Voice: Decodable, Sendable {
        public let lede: String?
        public let mandate: String?
        public let gravity: String?
        public let gapsIntro: String?
        enum CodingKeys: String, CodingKey { case lede, mandate, gravity, gapsIntro = "gaps_intro" }
    }

    /// A local AI story: the source's own headline and link, and how it connects to AI ("the PrompTugal test").
    public struct News: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { url + "|" + title }
        public let title: String
        public let summary: String?
        public let date: String?
        public let publisher: String?
        public let url: String
        public let readOn: String?
        public let aiPath: String?
        public let steps: Int?
        /// Set when the site's rights desk holds the item ("held under R12 ..."). A held story keeps its headline,
        /// summary, outlet, date and source link (Dinis, 25 Nov); its AI path and steps are dropped when decoded, so no
        /// screen, ranking or on-device prompt can show or use them.
        public let hold: String?

        enum CodingKeys: String, CodingKey {
            case title, summary, date, publisher, url, steps, hold, readOn = "read_on", aiPath = "ai_path"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            url = try c.decode(String.self, forKey: .url)
            date = try? c.decode(String.self, forKey: .date)
            publisher = try? c.decode(String.self, forKey: .publisher)
            readOn = try? c.decode(String.self, forKey: .readOn)
            let held = (try? c.decode(String.self, forKey: .hold))?.trimmingCharacters(in: .whitespacesAndNewlines)
            hold = (held?.isEmpty ?? true) ? nil : held
            summary = try? c.decode(String.self, forKey: .summary)
            if hold == nil {
                aiPath = try? c.decode(String.self, forKey: .aiPath)
                steps = try? c.decode(Int.self, forKey: .steps)
            } else {
                aiPath = nil
                steps = nil
            }
        }

        public var isHeld: Bool { hold != nil }

        /// "Read it at Barlavento": for a held story, the way to the full piece.
        public var readItAt: String {
            let outlet = (publisher ?? "").trimmingCharacters(in: .whitespaces)
            if !outlet.isEmpty { return LocalText.string("Read it at \(String(describing: outlet))") }
            return LocalText.string("Read it at \(String(describing: sourceURL?.host() ?? "the source"))")
        }

        /// "direct" or "1 step", "2 steps".
        public var stepsLabel: String? {
            guard let steps else { return nil }
            return steps == 0 ? "direct" : steps == 1 ? "1 step" : "\(steps) steps"
        }

        public var sourceURL: URL? { PlaceSite.safeURL(url) }
    }

    /// An organisation on the place's AI map.
    public struct MapEntry: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { name + "|" + sourceURL }
        public let name: String
        public let type: String?
        public let url: String?
        public let what: String?
        public let sourceURL: String
        public let readOn: String?
        public let aiPath: String?
        public let steps: Int?

        enum CodingKeys: String, CodingKey { case name, type, url, what, steps, sourceURL = "source_url", readOn = "read_on", aiPath = "ai_path" }

        public var source: URL? { PlaceSite.safeURL(sourceURL) }
        public var home: URL? { url.flatMap(PlaceSite.safeURL) }
        public var sourceHost: String { source?.host()?.replacingOccurrences(of: "www.", with: "") ?? sourceURL }
    }

    public struct Event: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { url + "|" + title }
        public let title: String
        public let date: String?
        public let url: String
        public let readOn: String?
        public let aiPath: String?

        enum CodingKeys: String, CodingKey { case title, date, url, readOn = "read_on", aiPath = "ai_path" }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            url = try c.decode(String.self, forKey: .url)
            date = try? c.decode(String.self, forKey: .date)
            readOn = try? c.decode(String.self, forKey: .readOn)
            // The schema allows any value for ai_path on events; keep it only when it is text.
            aiPath = try? c.decode(String.self, forKey: .aiPath)
        }

        public var link: URL? { PlaceSite.safeURL(url) }
    }

    public struct Source: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { url }
        public let name: String
        public let url: String
        public let kind: String?

        public var link: URL? { PlaceSite.safeURL(url) }
    }

    /// Only http(s) links leave the app; anything else in the data is shown as text.
    static func safeURL(_ text: String) -> URL? {
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}

extension KeyedDecodingContainer {
    /// Decodes an array item by item and drops the items that fail.
    func lenientArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        guard let items = try? decode([Lenient<T>].self, forKey: key) else { return [] }
        return items.compactMap(\.value)
    }
}

/// Always decodes, so the array moves on; holds nil when the item did not fit.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

// MARK: - The places the app knows

/// The places of PrompTugal.news by place: Portugal, the Algarve and its first wave of 17 (the 16 municipalities and
/// Quarteira, Dinis's word of 14 November 2026). The coordinates are approximate town centres, for the map only.
public struct PlaceInfo: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    /// The town's agent, by the newsroom's naming.
    public var agent: String { "place.\(id)@PrompTugal.dinis" }
    /// The town's page on promptugal.news.
    public var page: URL { URL(string: "https://promptugal.news/algarve/\(id)/")! }
}

public enum PlaceDirectory {
    public static let country = PlaceInfo(id: "portugal", name: "Portugal", latitude: 39.5, longitude: -8.0)
    public static let region = PlaceInfo(id: "algarve", name: "The Algarve", latitude: 37.17, longitude: -8.15)

    /// The 17 places, west to east as the region's own map lists them in rows; the screens sort as they need.
    public static let towns: [PlaceInfo] = [
        PlaceInfo(id: "faro", name: "Faro", latitude: 37.0194, longitude: -7.9304),
        PlaceInfo(id: "loule", name: "Loulé", latitude: 37.1377, longitude: -8.0197),
        PlaceInfo(id: "quarteira", name: "Quarteira", latitude: 37.0695, longitude: -8.1006),
        PlaceInfo(id: "silves", name: "Silves", latitude: 37.1891, longitude: -8.4386),
        PlaceInfo(id: "tavira", name: "Tavira", latitude: 37.1273, longitude: -7.6506),
        PlaceInfo(id: "vila-real-de-santo-antonio", name: "Vila Real de Santo António", latitude: 37.1946, longitude: -7.4153),
        PlaceInfo(id: "portimao", name: "Portimão", latitude: 37.1386, longitude: -8.5370),
        PlaceInfo(id: "lagos", name: "Lagos", latitude: 37.1028, longitude: -8.6730),
        PlaceInfo(id: "olhao", name: "Olhão", latitude: 37.0260, longitude: -7.8411),
        PlaceInfo(id: "albufeira", name: "Albufeira", latitude: 37.0891, longitude: -8.2479),
        PlaceInfo(id: "lagoa", name: "Lagoa", latitude: 37.1352, longitude: -8.4531),
        PlaceInfo(id: "monchique", name: "Monchique", latitude: 37.3176, longitude: -8.5554),
        PlaceInfo(id: "aljezur", name: "Aljezur", latitude: 37.3190, longitude: -8.8033),
        PlaceInfo(id: "vila-do-bispo", name: "Vila do Bispo", latitude: 37.0825, longitude: -8.9119),
        PlaceInfo(id: "castro-marim", name: "Castro Marim", latitude: 37.2183, longitude: -7.4430),
        PlaceInfo(id: "alcoutim", name: "Alcoutim", latitude: 37.4710, longitude: -7.4710),
        PlaceInfo(id: "sao-bras-de-alportel", name: "São Brás de Alportel", latitude: 37.1528, longitude: -7.8885),
    ]

    public static var all: [PlaceInfo] { [country, region] + towns }

    public static func info(_ id: String) -> PlaceInfo? { all.first { $0.id == id } }
}

// MARK: - Dates

enum PlaceDate {
    /// "2026-11-06" or a longer ISO date; nil when it does not start with a day.
    static func day(_ text: String?) -> Date? {
        guard let text, text.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(text.prefix(10)))
    }
}
