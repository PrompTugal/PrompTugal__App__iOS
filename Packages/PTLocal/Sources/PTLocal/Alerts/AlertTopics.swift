import Foundation

/// One local notification the app may post: what it says, where it opens, and the id that stops it twice.
public struct AlertCandidate: Sendable, Equatable, Identifiable {
    public let id: String
    public let topic: String
    public let title: String
    public let body: String
    public let link: URL?

    public init(id: String, topic: String, title: String, body: String, link: URL?) {
        self.id = id
        self.topic = topic
        self.title = title
        self.body = body
        self.link = link
    }
}

/// A kind of alert the reader can turn on. New topics are added by writing one more type and listing it in
/// `AlertTopics.all`: each reads one public file, the same for every reader, and picks what concerns the reader's
/// followed places on the phone, so nothing about the reader leaves it.
public protocol AlertTopic: Sendable {
    var id: String { get }
    var title: String { get }
    var summary: String { get }
    /// The public file read for this topic (one URL for every reader).
    var feed: URL { get }
    /// What in the file concerns these places now.
    func candidates(from data: Data, followed: [String], now: Date) -> [AlertCandidate]
}

public enum AlertTopics {
    /// Every topic, in the order the settings screen lists them.
    public static let all: [any AlertTopic] = [TownStoriesAlert(), IPMAWarningsAlert()]

    public static func topic(_ id: String) -> (any AlertTopic)? { all.first { $0.id == id } }
}

/// The places a reader follows, as PTPlaces keeps them ("Pick my town"): ids joined by commas under
/// `places.followed` (PTPlaces' `PlaceFollows.key`; read here, never written).
public enum FollowedPlaces {
    public static let key = "places.followed"

    public static func ids(_ raw: String?) -> [String] {
        (raw ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func current(_ defaults: UserDefaults = .standard) -> [String] {
        ids(defaults.string(forKey: key))
    }
}

// MARK: - New stories in followed towns

/// New stories for the followed places, from promptugal.news's since.json (one file for every reader). A story
/// counts for a place when it is that place's, or the place is in its rings. Each opens its source.
public struct TownStoriesAlert: AlertTopic {
    public let id = "town-stories"
    public var title: String { LocalText.string("New stories in my towns") }
    public var summary: String { LocalText.string("A notification when a town you follow has a new story, with its headline and source.") }
    public let feed = URL(string: "https://promptugal.news/api/v1/since.json")!

    public init() {}

    struct Since: Decodable {
        let items: [Item]
        enum CodingKeys: String, CodingKey { case items }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            items = c.lenientArray(Item.self, forKey: .items)
        }
    }

    struct Item: Decodable {
        let title: String
        let url: String
        let place: String?
        let rings: [String]?
        let publisher: String?
    }

    public func candidates(from data: Data, followed: [String], now: Date) -> [AlertCandidate] {
        guard !followed.isEmpty, let since = try? JSONDecoder().decode(Since.self, from: data) else { return [] }
        let wanted = Set(followed)
        var out: [AlertCandidate] = []
        for item in since.items {
            guard let link = PlaceSite.safeURL(item.url) else { continue }
            var places: [String] = []
            if let place = item.place { places.append(place) }
            places.append(contentsOf: item.rings ?? [])
            guard let match = places.first(where: { wanted.contains($0) }) else { continue }
            let name = PlaceDirectory.info(match)?.name ?? match.capitalized
            let outlet = item.publisher.map { " (\($0))" } ?? ""
            out.append(AlertCandidate(id: "story|" + item.url, topic: id,
                                      title: LocalText.string("New in \(name)"),
                                      body: item.title + outlet, link: link))
        }
        return out
    }
}

// MARK: - IPMA warnings for followed places

/// IPMA weather warnings (yellow and above) for the districts of the followed places. Only the warning's type, level
/// and area are shown, never IPMA's text, and each opens IPMA's warnings page.
public struct IPMAWarningsAlert: AlertTopic {
    public let id = "ipma-warnings"
    public var title: String { LocalText.string("IPMA weather warnings") }
    public var summary: String { LocalText.string("A notification when IPMA issues a yellow, orange or red warning for the district of a place you follow. Opens IPMA for the details.") }
    public let feed = IPMA.warningsURL
    public static let page = URL(string: "https://www.ipma.pt/pt/otempo/prev-sam/")!

    public init() {}

    /// IPMA's warning area for a place: the Algarve and its towns are Faro district; the district capitals their own.
    public static func area(for placeID: String) -> String? {
        if placeID == PlaceDirectory.region.id || PlaceDirectory.towns.contains(where: { $0.id == placeID }) {
            return IPMA.algarveArea
        }
        return districtAreas[placeID]
    }

    static let districtAreas: [String: String] = [
        "aveiro": "AVR", "beja": "BJA", "braga": "BRG", "braganca": "BGC", "castelo-branco": "CBO", "coimbra": "CBR",
        "evora": "EVR", "faro": "FAR", "guarda": "GDA", "leiria": "LRA", "lisboa": "LSB", "portalegre": "PTG",
        "porto": "PTO", "santarem": "STM", "setubal": "STB", "viana-do-castelo": "VCT", "vila-real": "VRL", "viseu": "VIS",
    ]

    static let areaNames: [String: String] = [
        "AVR": "Aveiro", "BJA": "Beja", "BRG": "Braga", "BGC": "Bragança", "CBO": "Castelo Branco", "CBR": "Coimbra",
        "EVR": "Évora", "FAR": "Faro", "GDA": "Guarda", "LRA": "Leiria", "LSB": "Lisboa", "PTG": "Portalegre",
        "PTO": "Porto", "STM": "Santarém", "STB": "Setúbal", "VCT": "Viana do Castelo", "VRL": "Vila Real", "VIS": "Viseu",
    ]

    public func candidates(from data: Data, followed: [String], now: Date) -> [AlertCandidate] {
        let areas = Set(followed.compactMap { Self.area(for: $0) })
        guard !areas.isEmpty, let all = try? JSONDecoder().decode([IPMA.Warning].self, from: data) else { return [] }
        var out: [AlertCandidate] = []
        for area in areas.sorted() {
            for warning in IPMA.activeWarnings(all, area: area, now: now) {
                let district = Self.areaNames[area] ?? area
                let level = LocalText.string(Self.levelKey(warning.level))
                let kind = LocalText.warningType(warning.type)
                out.append(AlertCandidate(id: "ipma|" + warning.id + "|" + warning.levelID, topic: id,
                                          title: LocalText.string("IPMA: \(level) warning, \(district) district"),
                                          body: LocalText.string("\(kind). Open IPMA for the details."),
                                          link: Self.page))
            }
        }
        return out
    }

    static func levelKey(_ level: IPMA.Level) -> String.LocalizationValue {
        switch level {
        case .green: "Green"
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .red: "Red"
        }
    }
}

extension IPMA.Level {
    /// The level as IPMA names it in the reader's language ("Orange", "Laranja").
    var localized: String { LocalText.string(IPMAWarningsAlert.levelKey(self)) }
}
