import Foundation

/// One community in the shape of lisbontechfringe.com/api/v1/communities.json: `id, name, what{text, quoted_from,
/// read_at}, join, links[{label, url}], events[ids], sources[{url, read_at, what}], label`. Read leniently: every field
/// but `name` may be missing or null, and only https links are kept.
public struct FringeCommunity: Identifiable, Hashable, Sendable {
    public struct Link: Hashable, Sendable {
        public let label: String
        public let url: URL
    }

    public struct Source: Hashable, Sendable {
        public let url: URL?
        public let readAt: String?
        public let what: String
    }

    public let id: String
    public let name: String
    /// What the community says it is, quoted from its own public page (never written by us).
    public let about: String
    public let aboutSource: URL?
    public let aboutReadAt: String?
    public let join: String
    public let links: [Link]
    public let eventIDs: [String]
    public let sources: [Source]
    public let label: String

    /// How to join, or nil when the feed says "unknown" or nothing.
    public var joinText: String? {
        let text = join.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text.lowercased() == "unknown" ? nil : text
    }

    public init(id: String, name: String, about: String = "", aboutSource: URL? = nil, aboutReadAt: String? = nil, join: String = "",
                links: [Link] = [], eventIDs: [String] = [], sources: [Source] = [], label: String = "") {
        self.id = id
        self.name = name
        self.about = about
        self.aboutSource = aboutSource
        self.aboutReadAt = aboutReadAt
        self.join = join
        self.links = links
        self.eventIDs = eventIDs
        self.sources = sources
        self.label = label
    }

    static func https(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Reads the communities file in any of the shapes the site may use: `{"communities": [...]}`, `{"items": [...]}` or a
/// bare array. A community without a name is skipped; the rest are kept, sorted by name.
public enum FringeCommunityFeed {
    private struct Wire: Decodable {
        struct What: Decodable {
            let text: String?
            let quoted_from: String?
            let read_at: String?
        }
        struct LinkWire: Decodable { let label: String?; let url: String? }
        struct SourceWire: Decodable { let url: String?; let read_at: String?; let what: String? }

        let id: String?
        let name: String?
        let what: What?
        let whatText: String?
        let join: String?
        let links: [LinkWire]?
        let events: [String]?
        let sources: [SourceWire]?
        let label: String?

        enum CodingKeys: String, CodingKey { case id, name, what, join, links, events, sources, label }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            name = try? c.decodeIfPresent(String.self, forKey: .name)
            let object = try? c.decodeIfPresent(What.self, forKey: .what)
            what = object
            // `what` may also arrive as a plain string.
            whatText = object == nil ? (try? c.decodeIfPresent(String.self, forKey: .what)) : nil
            join = try? c.decodeIfPresent(String.self, forKey: .join)
            links = try? c.decodeIfPresent([LinkWire].self, forKey: .links)
            events = try? c.decodeIfPresent([String].self, forKey: .events)
            sources = try? c.decodeIfPresent([SourceWire].self, forKey: .sources)
            label = try? c.decodeIfPresent(String.self, forKey: .label)
        }

        var community: FringeCommunity? {
            guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            let links = (self.links ?? []).compactMap { link -> FringeCommunity.Link? in
                guard let url = FringeCommunity.https(link.url) else { return nil }
                let label = link.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return FringeCommunity.Link(label: label.isEmpty ? (url.host ?? url.absoluteString) : label, url: url)
            }
            let sources = (self.sources ?? []).map {
                FringeCommunity.Source(url: FringeCommunity.https($0.url), readAt: $0.read_at, what: $0.what ?? "")
            }
            let key = (id ?? "").isEmpty ? FringeEvent.slug(name) : id ?? ""
            return FringeCommunity(id: key, name: name, about: what?.text ?? whatText ?? "",
                                   aboutSource: FringeCommunity.https(what?.quoted_from), aboutReadAt: what?.read_at,
                                   join: join ?? "", links: links, eventIDs: events ?? [], sources: sources, label: label ?? "")
        }
    }

    private struct Lenient: Decodable {
        let community: FringeCommunity?
        init(from decoder: Decoder) throws { community = (try? Wire(from: decoder))?.community }
    }

    private struct Wrapped: Decodable {
        let communities: [Lenient]?
        let items: [Lenient]?
    }

    public static func communities(from data: Data) throws -> [FringeCommunity] {
        let decoder = JSONDecoder()
        let lenient: [Lenient]
        if let wrapped = try? decoder.decode(Wrapped.self, from: data), let list = wrapped.communities ?? wrapped.items {
            lenient = list
        } else {
            lenient = try decoder.decode([Lenient].self, from: data)
        }
        return lenient.compactMap(\.community).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
