import Foundation

/// The facts and links of one entry, read from its JSON record.
public struct ExploreDetail: Sendable, Hashable {
    public struct Fact: Sendable, Hashable, Identifiable {
        public var label: String
        public var value: String
        public var id: String { label }
    }

    public struct Link: Sendable, Hashable, Identifiable {
        /// What the link says, in words: "speaks at", "hosted by".
        public var verb: String
        /// The site's reference of the other entry, e.g. `event:when-ai-leaves-the-screen`.
        public var ref: String
        public var label: String
        public var id: String { verb + "|" + ref }
    }

    public var title: String
    public var facts: [Fact]
    public var website: URL?
    public var links: [Link]

    /// People who speak at this talk (links into a talk that say "speaks at").
    public var speakers: [Link] { links.filter { $0.verb == "← speaks at" && $0.ref.hasPrefix("person:") } }
    public var otherLinks: [Link] { links.filter { !speakers.contains($0) } }

    /// Fields shown per kind, in order: JSON key, label.
    static let fields: [ExploreKind: [(String, String)]] = [
        .event: [("kind", "Kind"), ("date", "Day"), ("time", "Time"), ("where", "Where"), ("track", "Track")],
        .person: [("role", "Role"), ("organisation", "Organisation")],
        .company: [("what", "What it does"), ("country", "Country"), ("category", "Category"), ("attending_as", "At the summit as")],
        .organisation: [],
        .place: [("kind", "Kind"), ("note", "Note")],
    ]

    public static func decode(_ data: Data, kind: ExploreKind) throws -> ExploreDetail {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        let record = root["data"] as? [String: Any] ?? [:]
        let title = (root["label"] as? String) ?? (record["name"] as? String) ?? (record["title"] as? String) ?? ""
        let facts: [Fact] = (fields[kind] ?? []).compactMap { key, label in
            guard let value = record[key] as? String, !value.isEmpty else { return nil }
            return Fact(label: label, value: value)
        }
        let website = (record["website"] as? String).flatMap { URL(string: $0) }
        var links: [Link] = []
        var seen = Set<String>()
        let all = (root["links"] as? [String: Any]) ?? [:]
        for direction in ["out", "in"] {
            for entry in (all[direction] as? [[String: Any]]) ?? [] {
                guard let verb = entry["verb"] as? String, let label = entry["label"] as? String,
                      let ref = (entry[direction == "out" ? "to" : "from"] as? String),
                      ExploreKind(rawValue: String(ref.prefix { $0 != ":" })) != nil else { continue }
                let link = Link(verb: (direction == "in" ? "← " : "") + verb.replacingOccurrences(of: "_", with: " "),
                                ref: ref, label: label)
                if seen.insert(link.id).inserted { links.append(link) }
            }
        }
        return ExploreDetail(title: title, facts: facts, website: website, links: links)
    }
}
