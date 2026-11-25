import Foundation

/// What an entry is. The raw value is the type name the site uses in its references (`event:slug`).
public enum ExploreKind: String, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case event, person, company, organisation, place
    /// A published PrompTugal.news article (shown as "Stories").
    case article
    /// An item of library.promptugal.news or videos.promptugal.news: a replay, a talk, a video, an article elsewhere.
    case library

    public var id: String { rawValue }

    /// The kinds of the older talks index (search-docs.json), still read by the shared talk detail that My program
    /// opens. Explore itself no longer offers them.
    public static let browsable: [ExploreKind] = [.event, .person, .company, .place]

    /// The kinds the newsroom's Explore offers: Stories, Companies, Places, Library.
    public static let newsroom: [ExploreKind] = [.article, .company, .place, .library]

    /// The path segment of the site's API: `api/v1/<folder>/<slug>.json`.
    var folder: String {
        switch self {
        case .event: "events"
        case .person: "people"
        case .company: "companies"
        case .organisation: "organisations"
        case .place: "places"
        case .article: "articles"
        case .library: "items"
        }
    }

    public var title: String {
        switch self {
        case .event: String(localized: "Talks", bundle: .module)
        case .person: String(localized: "Speakers", bundle: .module)
        case .company: String(localized: "Companies", bundle: .module)
        case .organisation: String(localized: "Organisations", bundle: .module)
        case .place: String(localized: "Places", bundle: .module)
        case .article: String(localized: "Stories", bundle: .module)
        case .library: String(localized: "Library", bundle: .module)
        }
    }

    public var symbol: String {
        switch self {
        case .event: "calendar"
        case .person: "person"
        case .company: "building.2"
        case .organisation: "person.3"
        case .place: "mappin.and.ellipse"
        case .article: "newspaper"
        case .library: "books.vertical"
        }
    }
}

/// One searchable entry: a story, company, place, library item or video (or, for the shared talk detail, a talk
/// or speaker).
public struct ExploreItem: Codable, Sendable, Hashable, Identifiable {
    /// The site's reference, e.g. `event:opening-night`.
    public var id: String
    public var kind: ExploreKind
    public var title: String
    /// One line under the title: the role and organisation, or a company's one-liner, or the talk's place.
    public var subtitle: String
    /// Everything else that should be searchable.
    public var text: String
    /// Talks only: `2026-11-10` (Lisbon day), `12:00` and `12:45`.
    public var day: String?
    public var start: String?
    public var end: String?
    /// The entry's page: on promptugal.news, library.promptugal.news or videos.promptugal.news.
    public var page: URL?
    /// Newest first: the day it was published, `2026-11-24` (stories, library items, videos).
    public var date: String?
    /// The original the entry points at: a video on YouTube, a talk's replay, an article elsewhere.
    public var link: URL?
    /// Facts known from the list itself, shown on the detail: label and value, in order.
    public var facts: [ExploreFact]?

    public init(id: String, kind: ExploreKind, title: String, subtitle: String = "", text: String = "",
                day: String? = nil, start: String? = nil, end: String? = nil, page: URL? = nil,
                date: String? = nil, link: URL? = nil, facts: [ExploreFact]? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.text = text
        self.day = day
        self.start = start
        self.end = end
        self.page = page
        self.date = date
        self.link = link
        self.facts = facts
    }

    /// The part of the reference after the colon.
    public var slug: String {
        id.split(separator: ":", maxSplits: 1).last.map(String.init) ?? id
    }
}

/// A label and a value, e.g. "Publisher" and "A newspaper".
public struct ExploreFact: Codable, Sendable, Hashable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// Where the entries on screen came from. The screen says it, so a copy never passes for live.
public struct ExploreOrigin: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable {
        /// Read over the network just now.
        case live
        /// At least one part is the last copy this device read, because the network failed.
        case cached
        /// At least one part is the copy built into the app.
        case builtIn
    }

    public var kind: Kind
    /// When it was read (live), or when the oldest stored copy was written (cached).
    public var date: Date?
    /// The built-in copy's day, e.g. "25 Nov 2026".
    public var snapshotDay: String?

    public init(kind: Kind, date: Date? = nil, snapshotDay: String? = nil) {
        self.kind = kind
        self.date = date
        self.snapshotDay = snapshotDay
    }

    /// The worse of two: built-in beats cached beats live; between two copies the older date wins.
    func combined(with other: ExploreOrigin) -> ExploreOrigin {
        func rank(_ k: Kind) -> Int { k == .live ? 0 : (k == .cached ? 1 : 2) }
        if rank(other.kind) != rank(kind) { return rank(other.kind) > rank(kind) ? other : self }
        let date: Date? = switch (self.date, other.date) {
        case let (a?, b?): min(a, b)
        case let (a, b): a ?? b
        }
        return ExploreOrigin(kind: kind, date: date, snapshotDay: snapshotDay ?? other.snapshotDay)
    }
}

/// Every entry the app can search, with the site version it was built from.
public struct ExploreIndex: Codable, Sendable, Hashable {
    public var version: String?
    public var items: [ExploreItem]
    /// Live, this device's copy or the built-in copy. Nil when the source does not say.
    public var origin: ExploreOrigin?

    public init(version: String? = nil, items: [ExploreItem], origin: ExploreOrigin? = nil) {
        self.version = version
        self.items = items
        self.origin = origin
    }

    public func item(ref: String) -> ExploreItem? { items.first { $0.id == ref } }
}

/// Parses the line the site's search index keeps for a talk: `session 2026-11-10 12:00-12:45 <where> <track>`.
enum TalkLine {
    struct Parts: Equatable {
        var kind: String
        var day: String
        var start: String
        var end: String?
        var rest: String
    }

    static func parse(_ text: String) -> Parts? {
        let pattern = #"^(\S+) (\d{4}-\d{2}-\d{2}) (\d{1,2}:\d{2})(?:-(\d{1,2}:\d{2}))? ?(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        return Parts(kind: group(1) ?? "", day: group(2) ?? "", start: group(3) ?? "", end: group(4),
                     rest: (group(5) ?? "").trimmingCharacters(in: .whitespaces))
    }
}

/// Reads the site's files into entries. Pure, tested with fixtures.
public enum ExploreWire {
    struct SearchDocs: Decodable {
        var version: String?
        var docs: [Doc]
        struct Doc: Decodable {
            var id: String
            var url: String?
            var title: String
            var type: String
            var text: String?
        }
    }

    struct PlaceIndex: Decodable {
        var items: [Entry]
        struct Entry: Decodable {
            var id: String
            var label: String
            var page: String?
        }
    }

    /// `search-docs.json` holds the talks, speakers, companies and organisations; `places.json` holds the places.
    public static func index(searchDocs: Data, places: Data?, base: URL) throws -> ExploreIndex {
        let docs = try JSONDecoder().decode(SearchDocs.self, from: searchDocs)
        var items: [ExploreItem] = []
        for doc in docs.docs {
            guard let kind = ExploreKind(rawValue: doc.type) else { continue }
            let page = doc.url.flatMap { URL(string: $0, relativeTo: base)?.absoluteURL }
            let text = doc.text ?? ""
            switch kind {
            case .event:
                if let t = TalkLine.parse(text) {
                    items.append(ExploreItem(id: doc.id, kind: .event, title: doc.title, subtitle: t.rest,
                                             text: t.kind, day: t.day, start: t.start, end: t.end, page: page))
                } else {
                    items.append(ExploreItem(id: doc.id, kind: .event, title: doc.title, text: text, page: page))
                }
            case .person, .company, .organisation:
                items.append(ExploreItem(id: doc.id, kind: kind, title: doc.title, subtitle: text, page: page))
            case .place:
                items.append(ExploreItem(id: doc.id, kind: .place, title: doc.title, subtitle: text, page: page))
            case .article, .library:
                continue
            }
        }
        if let places, let list = try? JSONDecoder().decode(PlaceIndex.self, from: places) {
            let known = Set(items.map(\.id))
            for entry in list.items {
                let ref = "place:\(entry.id)"
                guard !known.contains(ref) else { continue }
                items.append(ExploreItem(id: ref, kind: .place, title: entry.label,
                                         page: entry.page.flatMap { URL(string: $0) }))
            }
        }
        return ExploreIndex(version: docs.version, items: items)
    }
}
