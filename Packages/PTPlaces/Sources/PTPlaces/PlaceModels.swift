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
        at = c.seat("at")
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
    /// PrompTugal.news's own signed articles about the place (api/v1/by-place/<id>.json only).
    public var articles: [PlaceArticle] = []

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
        articles = c.lenientArray("articles")
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

    /// What the town page shows: the stories with a source link, newest first.
    public var newsNewestFirst: [NewsItem] { newsByDate.filter { $0.sourceLink != nil } }

    /// The events, the latest date first; an event whose date does not read goes last, in the file's order.
    public var eventsNewestFirst: [PlaceEvent] {
        events.enumerated().sorted { a, b in
            let da = PlaceDates.parse(String(a.element.date.prefix(10)))
            let db = PlaceDates.parse(String(b.element.date.prefix(10)))
            switch (da, db) {
            case let (x?, y?): return x != y ? x > y : a.offset < b.offset
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }.map(\.element)
    }
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
    /// A licensed photo of the town, once the site serves one: its URL, and its credit line (licence, author).
    public var image: String?
    public var imageCredit: String?

    public init(accent: String, landmark: String = "", motif: String = "", image: String? = nil) {
        self.accent = accent; self.landmark = landmark; self.motif = motif; self.image = image
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        accent = c.string("accent") ?? ""
        landmark = c.string("landmark") ?? ""
        motif = c.string("motif") ?? ""
        if let photo = c.lenient(Photo.self, "image") ?? c.lenient(Photo.self, "photo") {
            image = photo.url
            imageCredit = [photo.author, photo.licence].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        } else {
            image = c.string("image")
        }
    }

    private struct Photo: Decodable {
        var url: String?
        var author: String?
        var licence: String?
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
    public var provenance: Provenance?
    /// Set when the site's rights desk holds the item ("held under R12 ... not to be shown"): the app then shows only
    /// the headline, outlet, date and source link, never the summary or anything drawn from the story.
    public var hold: String?

    public var id: String { url + "|" + title }
    public var isHeld: Bool { !(hold ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

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
        provenance = c.lenient(Provenance.self, "provenance")
        publisher = c.string("publisher") ?? provenance?.publisher ?? ""
        url = c.string("url") ?? provenance?.sourceURL ?? ""
        readOn = c.string("read_on") ?? provenance?.readOn ?? ""
        aiPath = c.string("ai_path") ?? ""
        steps = c.int("steps")
        hold = c.string("hold")
    }

    /// The story's source link as a web URL, or nil (a story without one is not shown).
    public var sourceLink: URL? { PlaceLinks.web(url) }

    /// Who published it: the outlet, else the source's host.
    public var outlet: String { publisher.isEmpty ? (sourceLink?.host() ?? "") : publisher }
}

/// Links the place agents write, kept only when they are web links.
enum PlaceLinks {
    static func web(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http", url.host() != nil else { return nil }
        return url
    }
}

/// Where a story or map entry was read, when, by which agent, and the signed file it lives in.
public struct Provenance: Decodable, Sendable, Equatable, Hashable {
    public var sourceURL: String
    public var readOn: String
    public var readBy: String
    public var file: String
    /// "valid", "unchecked"...
    public var signature: String
    public var siteKey: String
    public var publisher: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        publisher = c.string("publisher")
        sourceURL = c.string("source_url") ?? ""
        readOn = c.string("read_on") ?? ""
        readBy = c.string("read_by") ?? ""
        file = c.string("file") ?? ""
        signature = c.string("signature") ?? ""
        siteKey = c.string("site_key") ?? ""
    }
}

/// One of PrompTugal.news's own articles about a place.
public struct PlaceArticle: Decodable, Sendable, Equatable, Hashable, Identifiable {
    public var title: String
    public var summary: String
    public var author: String
    public var date: String
    public var url: String
    public var signature: String

    public var id: String { url }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = try c.decode(String.self, forKey: AnyKey("title"))
        summary = c.string("summary") ?? ""
        author = c.string("author") ?? ""
        date = c.string("date") ?? ""
        url = c.string("url") ?? ""
        signature = c.string("signature") ?? ""
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
    public var provenance: Provenance?
    /// Public contacts only (published on a public site, above all a public body's), each with the page it came from.
    public var contacts: [PublicContact] = []
    /// Talent that agreed to be listed and says it is looking for work.
    public var lookingForWork = false

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
        provenance = c.lenient(Provenance.self, "provenance")
        contacts = c.lenientArray("contacts")
        if contacts.isEmpty, let one = c.lenient(PublicContact.self, "contact") { contacts = [one] }
        lookingForWork = c.lenient(Bool.self, "looking_for_work") ?? c.lenient(Bool.self, "open_to_work") ?? false
    }
}

/// A contact published on a public website, shown with its source (website CLAUDE.md, Dinis 15 Nov ~23:55).
/// One without a source page is not shown.
public struct PublicContact: Decodable, Sendable, Equatable, Hashable {
    public var label: String
    public var email: String
    public var phone: String
    public var url: String
    public var sourceURL: String
    public var readOn: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        label = c.string("label") ?? c.string("name") ?? ""
        email = c.string("email") ?? ""
        phone = c.string("phone") ?? c.string("tel") ?? ""
        url = c.string("url") ?? c.string("web") ?? ""
        sourceURL = c.string("source_url") ?? c.string("source") ?? ""
        readOn = c.string("read_on") ?? ""
    }

    public var showable: Bool { !sourceURL.isEmpty && !(email.isEmpty && phone.isEmpty && url.isEmpty) }
}

public struct Source: Decodable, Sendable, Equatable, Hashable {
    public var name: String
    public var url: String
    public var kind: String

    /// Local media (Dinis, 15 Nov ~23:55): news organisations, bloggers and editors we send readers to.
    public var isMedia: Bool {
        ["press", "media", "blog", "news", "radio", "tv", "magazine", "newsletter", "podcast"].contains(kind.lowercased())
    }

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

    /// Who runs the event or publishes its page, when the agent wrote it down.
    public var publisher: String = ""
    public var note: String = ""

    public var id: String { title + "|" + date }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        title = try c.decode(String.self, forKey: AnyKey("title"))
        let provenance = c.lenient(Provenance.self, "provenance")
        date = c.string("date") ?? ""
        url = c.string("url") ?? provenance?.sourceURL ?? ""
        readOn = c.string("read_on") ?? provenance?.readOn ?? ""
        aiPath = c.string("ai_path") ?? ""
        publisher = c.string("publisher") ?? c.string("organiser") ?? provenance?.publisher ?? ""
        note = c.string("note") ?? ""
    }

    public var sourceLink: URL? { PlaceLinks.web(url) }

    /// The organiser, else the host of the event's page.
    public var outlet: String { publisher.isEmpty ? (sourceLink?.host() ?? "") : publisher }
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

    /// A seat as [lon, lat] or {"lon", "lat"} (the index changed shape on 15 November).
    func seat(_ key: String) -> [Double]? {
        if let pair = lenient([Double].self, key), pair.count == 2 { return pair }
        if let point = lenient([String: Double].self, key), let lon = point["lon"], let lat = point["lat"] { return [lon, lat] }
        return nil
    }

    func lenientArray<T: Decodable>(_ key: String) -> [T] {
        guard let items = lenient([Maybe<T>].self, key) else { return [] }
        return items.compactMap(\.value)
    }
}
