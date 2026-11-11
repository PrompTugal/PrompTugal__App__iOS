import Foundation

/// The storm block: the headline of the open incident in storm-charles.promptugal.news/api/v1/index.json, with where
/// it comes from and when. This app is not a warning service: it links IPMA and ANEPC.
public struct StormHeadline: Codable, Equatable, Sendable {
    public let incident: String      // the incident's title
    public let text: String          // the headline
    public let source: String
    public let sourceURL: URL?
    public let at: String            // when the source says it was published, as the site words it
    public let builtAt: String?      // when the site built this file (ISO 8601, UTC)
    public let siteURL: URL

    public init(incident: String, text: String, source: String, sourceURL: URL?, at: String, builtAt: String?, siteURL: URL) {
        self.incident = incident
        self.text = text
        self.source = source
        self.sourceURL = sourceURL
        self.at = at
        self.builtAt = builtAt
        self.siteURL = siteURL
    }

    private struct Index: Decodable {
        struct Incident: Decodable {
            struct Headline: Decodable {
                let text: String?
                let source: String?
                let url: String?
                let at: String?
            }
            let title: String?
            let status: String?
            let headline: Headline?
        }
        let incidents: [Incident]?
        let built_at: String?
        let site: String?
    }

    /// The first open incident with a headline, or nil.
    public static func parse(_ data: Data) -> StormHeadline? {
        guard let index = try? JSONDecoder().decode(Index.self, from: data) else { return nil }
        let incident = index.incidents?.first { ($0.status ?? "open") == "open" && ($0.headline?.text ?? "").isEmpty == false }
            ?? index.incidents?.first { ($0.headline?.text ?? "").isEmpty == false }
        guard let incident, let headline = incident.headline, let text = headline.text else { return nil }
        let site = index.site.flatMap { URL(string: $0) } ?? URL(string: "https://storm-charles.promptugal.news/")!
        return StormHeadline(incident: incident.title ?? "", text: text, source: headline.source ?? "",
                             sourceURL: headline.url.flatMap { URL(string: $0) }, at: headline.at ?? "",
                             builtAt: index.built_at, siteURL: site)
    }
}
