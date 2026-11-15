import Foundation

// The website's by-place data (PrompTugal/PrompTugal__News__Website, data/by-place/), as served:
//   https://promptugal.news/api/v1/by-place/index.json   the places, their status, agent and counts
//   https://promptugal.news/data/by-place/places.json     the list, with each town's seat (`at`: [lon, lat])
//   https://promptugal.news/data/by-place/<id>.json       one place: mandate, gravity, look, news, AI map, events...
// Every decoder here is lenient: a field that is missing or changed shape is dropped, never the whole file,
// because nineteen place agents write these files through the night.

// MARK: - The index

public struct PlaceIndex: Decodable, Sendable, Equatable {
    public var places: [PlaceSummary]

    public init(places: [PlaceSummary]) { self.places = places }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        places = c.lenientArray("places")
    }
}

public struct PlaceSummary: Decodable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var kind: String
    public var parent: String
    public var path: String
    public var agent: String
    public var status: String
    public var updated: String
    public var aiNews: Int
    public var aiMap: Int
    /// The town's seat, [longitude, latitude], from places.json (the index does not carry it).
    public var at: [Double]?

    public init(id: String, name: String, kind: String = "municipality", parent: String = "algarve", path: String = "",
                agent: String = "", status: String = "researching", updated: String = "", aiNews: Int = 0, aiMap: Int = 0,
                at: [Double]? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.parent = parent; self.path = path; self.agent = agent
        self.status = status; self.updated = updated; self.aiNews = aiNews; self.aiMap = aiMap; self.at = at
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = try c.decode(String.self, forKey: AnyKey("id"))
        name = c.string("name") ?? id
        kind = c.string("kind") ?? "municipality"
        parent = c.string("parent") ?? ""
        path = c.string("path") ?? ""
        agent = c.string("agent") ?? ""
        status = c.string("status") ?? "researching"
        updated = c.string("updated") ?? ""
        aiNews = c.int("ai_news") ?? 0
        aiMap = c.int("ai_map") ?? 0
        at = c.lenient([Double].self, "at")
    }

    public var isTown: Bool { kind == "municipality" || kind == "city" }
    public var isLive: Bool { status == "live" }
}

// MARK: - One place

public struct PlaceFile: Decodable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var kind: String
    public var parent: String
    public var status: String
    public var updated: String
    public var by: String
    public var mandate: String
    public var gravity: Gravity?
    public var look: Look?
    public var aiNews: [NewsItem]
    public var aiMap: [MapEntry]
    public var sources: [Source]
    public var events: [PlaceEvent]
    public var gaps: [String]
    public var voice: Voice?
    public var identity: Identity?

    public init(id: String, name: String, kind: String = "municipality", parent: String = "algarve", status: String = "researching",
                updated: String = "", by: String = "", mandate: String = "", gravity: Gravity? = nil, look: Look? = nil,
                aiNews: [NewsItem] = [], aiMap: [MapEntry] = [], sources: [Source] = [], events: [PlaceEvent] = [],
                gaps: [String] = [], voice: Voice? = nil, identity: Identity? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.parent = parent; self.status = status; self.updated = updated
        self.by = by; self.mandate = mandate; self.gravity = gravity; self.look = look; self.aiNews = aiNews; self.aiMap = aiMap
        self.sources = sources; self.events = events; self.gaps = gaps; self.voice = voice; self.identity = identity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = try c.decode(String.self, forKey: AnyKey("id"))
        name = c.string("name") ?? id
        kind = c.string("kind") ?? "municipality"
        parent = c.string("parent") ?? ""
        status = c.string("status") ?? "researching"
        updated = c.string("updated") ?? ""
        by = c.string("by") ?? ""
        mandate = c.string("mandate") ?? ""
        gravity = c.lenient(Gravity.self, "gravity")
        look = c.lenient(Look.self, "look")
        aiNews = c.lenientArray("ai_news")
        aiMap = c.lenientArray("ai_map")
        sources = c.lenientArray("sources")
        events = c.lenientArray("events")
        gaps = c.lenientArray("gaps")
        voice = c.lenient(Voice.self, "voice")
        identity = c.lenient(Identity.self, "identity")
    }

    /// The news, the closest to AI first (fewest steps), then the newest.
    public var newsByWeight: [NewsItem] {
        aiNews.sorted { a, b in
            if (a.steps ?? 9) != (b.steps ?? 9) { return (a.steps ?? 9) < (b.steps ?? 9) }
            return a.date > b.date
        }
    }

    /// The news, newest first.
    public var newsByDate: [NewsItem] { aiNews.sorted { $0.date > $1.date } }
}

public struct Gravity: Decodable, Sendable, Equatable {
    public var text: String
    public var sources: [GravitySource]

    public init(text: String, sources: [GravitySource] = []) { self.text = text; self.sources = sources }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        text = c.string("text") ?? ""
        sources = c.lenientArray("sources")
    }
}

public struct GravitySource: Decodable, Sendable, Equatable, Hashable {
    public var title: String
    public var url: String
    public var readOn: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = c.string("title") ?? ""
        url = c.string("url") ?? ""
        readOn = c.string("read_on") ?? ""
    }
}

public struct Look: Decodable, Sendable, Equatable {
    /// "#9A3412".
    public var accent: String
    public var landmark: String
    public var motif: String
    /// A licensed photo of the town, once the site serves one (asked of dev.places@ and designer.places@).
    public var image: String?

    public init(accent: String, landmark: String = "", motif: String = "", image: String? = nil) {
        self.accent = accent; self.landmark = landmark; self.motif = motif; self.image = image
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        accent = c.string("accent") ?? ""
        landmark = c.string("landmark") ?? ""
        motif = c.string("motif") ?? ""
        image = c.string("image") ?? c.string("photo")
    }
}

public struct NewsItem: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var title: String
    public var summary: String
    /// "2026-07-28" (sorts as text).
    public var date: String
    public var publisher: String
    public var url: String
    public var readOn: String
    public var aiPath: String
    /// Steps from AI in the graph: 0 is about AI itself (the PrompTugal test allows up to 3).
    public var steps: Int?

    public var id: String { url + "|" + title }

    public init(title: String, summary: String = "", date: String = "", publisher: String = "", url: String = "",
                readOn: String = "", aiPath: String = "", steps: Int? = nil) {
        self.title = title; self.summary = summary; self.date = date; self.publisher = publisher; self.url = url
        self.readOn = readOn; self.aiPath = aiPath; self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = try c.decode(String.self, forKey: AnyKey("title"))
        summary = c.string("summary") ?? ""
        date = c.string("date") ?? ""
        publisher = c.string("publisher") ?? ""
        url = c.string("url") ?? ""
        readOn = c.string("read_on") ?? ""
        aiPath = c.string("ai_path") ?? ""
        steps = c.int("steps")
    }
}

public struct MapEntry: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var name: String
    /// company, institution, event, programme... (free text from the place agent).
    public var type: String
    public var url: String
    public var what: String
    public var sourceURL: String
    public var readOn: String
    public var aiPath: String
    public var steps: Int?

    public var id: String { name + "|" + type }

    public init(name: String, type: String = "company", url: String = "", what: String = "", sourceURL: String = "",
                readOn: String = "", aiPath: String = "", steps: Int? = nil) {
        self.name = name; self.type = type; self.url = url; self.what = what; self.sourceURL = sourceURL
        self.readOn = readOn; self.aiPath = aiPath; self.steps = steps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        name = try c.decode(String.self, forKey: AnyKey("name"))
        type = c.string("type") ?? "entity"
        url = c.string("url") ?? ""
        what = c.string("what") ?? ""
        sourceURL = c.string("source_url") ?? ""
        readOn = c.string("read_on") ?? ""
        aiPath = c.string("ai_path") ?? ""
        steps = c.int("steps")
    }
}

public struct Source: Decodable, Sendable, Equatable, Hashable {
    public var name: String
    public var url: String
    public var kind: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        name = c.string("name") ?? ""
        url = c.string("url") ?? ""
        kind = c.string("kind") ?? ""
    }
}

public struct PlaceEvent: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var title: String
    /// "2026-11-27" or "2026-11-27 to 2026-11-28".
    public var date: String
    public var url: String
    public var readOn: String
    public var aiPath: String

    public var id: String { title + "|" + date }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = try c.decode(String.self, forKey: AnyKey("title"))
        date = c.string("date") ?? ""
        url = c.string("url") ?? ""
        readOn = c.string("read_on") ?? ""
        aiPath = c.string("ai_path") ?? ""
    }
}

/// The page rewritten in an exaggerated local Algarvio voice, facts unchanged (a clearly labelled toggle).
public struct Voice: Decodable, Sendable, Equatable {
    public var lede: String
    public var mandate: String
    public var gravity: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        lede = c.string("lede") ?? ""
        mandate = c.string("mandate") ?? ""
        gravity = c.string("gravity") ?? ""
    }
}

public struct Identity: Decodable, Sendable, Equatable {
    public var keyID: String
    public var signedBy: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        keyID = c.string("key_id") ?? ""
        signedBy = c.string("signed_by") ?? ""
    }
}

// MARK: - Lenient decoding

struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Decodes one element, or nothing, so a bad element does not sink the array.
private struct Maybe<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

extension KeyedDecodingContainer where Key == AnyKey {
    func lenient<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        (try? decodeIfPresent(T.self, forKey: AnyKey(key))) ?? nil
    }

    func string(_ key: String) -> String? {
        if let s = lenient(String.self, key) { return s }
        if let i = lenient(Int.self, key) { return String(i) }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let i = lenient(Int.self, key) { return i }
        if let s = lenient(String.self, key) { return Int(s) }
        return nil
    }

    func lenientArray<T: Decodable>(_ key: String) -> [T] {
        guard let items = lenient([Maybe<T>].self, key) else { return [] }
        return items.compactMap(\.value)
    }
}
