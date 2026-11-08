import Foundation

// What the readers take from the registered sources (`ContentSources`, `LiveFeeds`) when they have them. Both are filled by
// PTSync at launch and kept on the device, so a reader has something to show before its own request answers, and with no
// network. Nothing here touches the network; with no source registered every call answers nil or empty, and the reader
// does what it did before.

extension Story {
    /// A feed entry as a story. Nil unless it has a title and a link on promptugal.news over https, the same rule the
    /// app's own RSS reader applies.
    public init?(_ item: FeedItem) {
        guard !item.title.isEmpty, let url = item.url, url.scheme == "https", url.host() == FeedClient.site.host() else { return nil }
        self.init(id: item.id, title: item.title, summary: item.summary, category: item.category ?? "",
                  published: item.published, url: url)
    }
}

public enum LiveContent {
    /// The id of the site the public app follows (`ContentSources.source(for:)`).
    public static let siteID = "promptugal.news"
    /// The id of the articles feed (`LiveFeeds.source?.items(in:)`).
    public static let articlesFeedID = "promptugal.articles"
    public static let agendaPath = "api/v1/live/agenda.json"

    private struct AgendaFile: Decodable { let items: [Event] }

    /// The newest articles the device holds, as stories. Empty when no feed source is registered or it has none.
    public static func stories(limit: Int = 40) -> [Story] {
        guard let source = LiveFeeds.source else { return [] }
        var seen = Set<String>()
        let stories = source.items(in: articlesFeedID).compactMap { Story($0) }.filter { seen.insert($0.id).inserted }
        return Array(stories.prefix(limit))
    }

    /// The agenda from the synced files, sorted, or nil when no source is registered or it holds no readable agenda.
    public static func agenda() -> [Event]? {
        guard let data = ContentSources.source(for: siteID)?.data(at: agendaPath),
              let file = try? JSONDecoder().decode(AgendaFile.self, from: data), !file.items.isEmpty else { return nil }
        return file.items.sorted(by: Event.earlier)
    }
}
