import Foundation

public enum FeedFormat: String, Codable, Sendable, Hashable {
    /// RSS 2.0 (`<rss><channel><item>`), with `media:content` or an image `enclosure` for the picture.
    case rss
    /// Atom 1.0 (`<feed><entry>`).
    case atom
    /// JSON Feed 1.1 (`{"items":[{id,url,title,content_text,date_published,image,tags}]}`).
    case jsonFeed
    /// promptugal.news `api/v1/newsletter.json` (`{"editions":[{date,edition,title,summary,page}]}`).
    case promptugalNewsletter
}

/// A feed to follow.
public struct LiveFeed: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let url: URL
    public let format: FeedFormat
    /// Hosts the feed itself may be fetched from. Default: the host of `url`. Links inside entries are not fetched.
    public let allowedHosts: Set<String>
    /// Items kept per feed (the newest).
    public let limit: Int

    public init(id: String, title: String, url: URL, format: FeedFormat, allowedHosts: Set<String>? = nil, limit: Int = 100) {
        self.id = id
        self.title = title
        self.url = url
        self.format = format
        self.allowedHosts = allowedHosts ?? Set([url.host()].compactMap { $0 })
        self.limit = max(1, min(limit, 500))
    }

    /// The articles of promptugal.news (RSS 2.0, 40 items, about 30 KB).
    public static let promptugalArticles = LiveFeed(id: "promptugal.articles", title: "PrompTugal.news",
                                                    url: URL(string: "https://promptugal.news/feed.xml")!, format: .rss)
    /// The morning and evening editions of the newsletter (JSON).
    public static let promptugalNewsletter = LiveFeed(id: "promptugal.newsletter", title: "PrompTugal.news newsletter",
                                                      url: URL(string: "https://promptugal.news/api/v1/newsletter.json")!,
                                                      format: .promptugalNewsletter)
}

public enum FeedLimits {
    public static let maxBytes = 2 * 1024 * 1024
    public static let maxItems = 500
    public static let maxTitle = 200
    public static let maxSummary = 600
}

public enum FeedError: Error, LocalizedError, Equatable {
    case notAFeed
    case tooLarge
    case unsafeFeedURL
    case badStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .notAFeed: "The feed could not be read."
        case .tooLarge: "The feed is too large."
        case .unsafeFeedURL: "The feed address is not allowed."
        case .badStatus(let code): "The feed answered with status \(code)."
        }
    }
}

/// Turns feed bytes into items. Untrusted input: text comes out as plain text, links as https, sizes are capped.
public enum FeedParser {
    public static func parse(_ data: Data, feed: LiveFeed) throws -> [FeedItem] {
        guard data.count <= FeedLimits.maxBytes else { throw FeedError.tooLarge }
        switch feed.format {
        case .rss, .atom: return try parseXML(data, feed: feed)
        case .jsonFeed: return try parseJSONFeed(data, feed: feed)
        case .promptugalNewsletter: return try parseNewsletter(data, feed: feed)
        }
    }

    /// Builds an item from raw strings, or nil when it has no usable title or id.
    static func makeItem(feed: LiveFeed, id: String, title: String, summary: String, link: String, image: String,
                         date: Date?, category: String) -> FeedItem? {
        let cleanTitle = FeedText.plain(title, limit: FeedLimits.maxTitle)
        let url = FeedText.safeURL(link, base: feed.url)
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (url?.absoluteString ?? "") : id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !key.isEmpty, key.count <= 2_048 else { return nil }
        let cleanCategory = FeedText.plain(category, limit: 60)
        return FeedItem(id: key, feed: feed.id, title: cleanTitle, summary: FeedText.plain(summary, limit: FeedLimits.maxSummary),
                        url: url, imageURL: FeedText.safeURL(image, base: feed.url), published: date,
                        category: cleanCategory.isEmpty ? nil : cleanCategory)
    }

    // MARK: RSS and Atom

    private static func parseXML(_ data: Data, feed: LiveFeed) throws -> [FeedItem] {
        let reader = XMLItemReader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        let finished = parser.parse()
        // An abort after enough items is not an error; anything else without items is not a feed.
        guard finished || reader.reachedLimit || !reader.items.isEmpty else { throw FeedError.notAFeed }
        guard reader.sawFeedRoot else { throw FeedError.notAFeed }
        return reader.items.compactMap {
            makeItem(feed: feed, id: $0.id, title: $0.title, summary: $0.summary.isEmpty ? $0.content : $0.summary,
                     link: $0.link.isEmpty ? $0.atomLink : $0.link, image: $0.image,
                     date: FeedText.date($0.published.isEmpty ? $0.updated : $0.published), category: $0.category)
        }
    }

    fileprivate struct RawItem {
        var id = "", title = "", link = "", atomLink = "", summary = "", content = ""
        var published = "", updated = "", category = "", image = ""
    }

    fileprivate final class XMLItemReader: NSObject, XMLParserDelegate {
        var items: [RawItem] = []
        var sawFeedRoot = false
        var reachedLimit = false
        private var current: RawItem?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String]) {
            text = ""
            if name == "rss" || name == "feed" { sawFeedRoot = true }
            switch name {
            case "item", "entry":
                current = RawItem()
            case "link":
                if current != nil, let href = attributes["href"], (attributes["rel"] ?? "alternate") == "alternate", current?.atomLink.isEmpty == true {
                    current?.atomLink = href
                }
            case "media:content", "media:thumbnail", "enclosure":
                guard current?.image.isEmpty == true, let url = attributes["url"] else { return }
                let medium = attributes["medium"], type = attributes["type"]
                let looksLikeImage = (type?.hasPrefix("image/") ?? false) || medium == "image" || name == "media:thumbnail"
                    || (type == nil && medium == nil && name == "media:content")
                if looksLikeImage { current?.image = url }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if text.count < 20_000 { text += string }
        }

        func parser(_ parser: XMLParser, foundCDATA data: Data) {
            if text.count < 20_000 { text += String(decoding: data, as: UTF8.self) }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            defer { text = "" }
            guard current != nil else { return }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch name {
            case "item", "entry":
                if let finished = current { items.append(finished) }
                current = nil
                if items.count >= FeedLimits.maxItems {
                    reachedLimit = true
                    parser.abortParsing()
                }
            case "title": if current?.title.isEmpty == true { current?.title = value }
            case "link": if current?.link.isEmpty == true { current?.link = value }
            case "guid", "id": if current?.id.isEmpty == true { current?.id = value }
            case "pubDate", "published", "dc:date": if current?.published.isEmpty == true { current?.published = value }
            case "updated": if current?.updated.isEmpty == true { current?.updated = value }
            case "description", "summary": if current?.summary.isEmpty == true { current?.summary = value }
            case "content", "content:encoded": if current?.content.isEmpty == true { current?.content = value }
            case "category": if current?.category.isEmpty == true { current?.category = value }
            default: break
            }
        }
    }

    // MARK: JSON Feed

    private struct JSONFeedDocument: Decodable {
        struct Item: Decodable {
            var id: String?
            var url: String?
            var title: String?
            var summary: String?
            var content_text: String?
            var content_html: String?
            var image: String?
            var date_published: String?
            var date_modified: String?
            var tags: [String]?

            private enum CodingKeys: String, CodingKey {
                case id, url, title, summary, content_text, content_html, image, date_published, date_modified, tags
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                // `id` may be a string or a number; any field of the wrong type is ignored instead of failing the feed.
                if let text = try? c.decodeIfPresent(String.self, forKey: .id) { id = text }
                else if let number = try? c.decodeIfPresent(Int.self, forKey: .id) { id = String(number) }
                url = try? c.decodeIfPresent(String.self, forKey: .url)
                title = try? c.decodeIfPresent(String.self, forKey: .title)
                summary = try? c.decodeIfPresent(String.self, forKey: .summary)
                content_text = try? c.decodeIfPresent(String.self, forKey: .content_text)
                content_html = try? c.decodeIfPresent(String.self, forKey: .content_html)
                image = try? c.decodeIfPresent(String.self, forKey: .image)
                date_published = try? c.decodeIfPresent(String.self, forKey: .date_published)
                date_modified = try? c.decodeIfPresent(String.self, forKey: .date_modified)
                tags = try? c.decodeIfPresent([String].self, forKey: .tags)
            }
        }

        struct Lossy: Decodable {
            let value: Item?
            init(from decoder: Decoder) throws { value = try? Item(from: decoder) }
        }

        var items: [Lossy]
    }

    private static func parseJSONFeed(_ data: Data, feed: LiveFeed) throws -> [FeedItem] {
        guard let document = try? JSONDecoder().decode(JSONFeedDocument.self, from: data) else { throw FeedError.notAFeed }
        return document.items.prefix(FeedLimits.maxItems).compactMap { $0.value }.compactMap { item in
            makeItem(feed: feed, id: item.id ?? "", title: item.title ?? "",
                     summary: item.summary ?? item.content_text ?? item.content_html ?? "", link: item.url ?? "",
                     image: item.image ?? "", date: FeedText.date(item.date_published ?? item.date_modified ?? ""),
                     category: item.tags?.first ?? "")
        }
    }

    // MARK: promptugal.news newsletter

    private struct NewsletterDocument: Decodable {
        struct Edition: Decodable {
            var date: String?
            var edition: String?
            var title: String?
            var summary: String?
            var page: String?

            private enum CodingKeys: String, CodingKey { case date, edition, title, summary, page }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                date = try? c.decodeIfPresent(String.self, forKey: .date)
                edition = try? c.decodeIfPresent(String.self, forKey: .edition)
                title = try? c.decodeIfPresent(String.self, forKey: .title)
                summary = try? c.decodeIfPresent(String.self, forKey: .summary)
                page = try? c.decodeIfPresent(String.self, forKey: .page)
            }
        }

        struct Lossy: Decodable {
            let value: Edition?
            init(from decoder: Decoder) throws { value = try? Edition(from: decoder) }
        }

        var editions: [Lossy]
    }

    /// The morning edition is dated 07:00 UTC and the evening edition 18:00 UTC of its day (Lisbon is on UTC in November).
    private static func parseNewsletter(_ data: Data, feed: LiveFeed) throws -> [FeedItem] {
        guard let document = try? JSONDecoder().decode(NewsletterDocument.self, from: data) else { throw FeedError.notAFeed }
        return document.editions.prefix(FeedLimits.maxItems).compactMap { $0.value }.compactMap { edition in
            let hour = edition.edition == "evening" ? "18:00:00Z" : "07:00:00Z"
            let date = edition.date.flatMap { FeedText.date("\($0)T\(hour)") }
            return makeItem(feed: feed, id: edition.page ?? "", title: edition.title ?? "", summary: edition.summary ?? "",
                            link: edition.page ?? "", image: "", date: date, category: "Newsletter")
        }
    }
}
