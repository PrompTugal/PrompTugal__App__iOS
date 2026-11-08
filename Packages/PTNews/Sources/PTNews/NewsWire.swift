import Foundation
import PTCore

/// The news models: the newsroom's story board and the newsletter editions.
/// They moved with the news screens; the Team dashboards read the board too.
extension Wire {
    public struct StoryBoard: Decodable, Sendable {
        public let built: String?
        public let columns: [Column]?
        public let stories: [BoardStory]?
    }

    public struct Column: Decodable, Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String?
        public let count: Int?
    }

    public struct BoardStory: Decodable, Identifiable, Sendable {
        public let id: String
        public let title: String?
        public let column: String?
        public let beat: String?
        public let desk: String?
        public let assignee: String?
        public let needs: LooseText?
        public let next: String?
        public let sources: Int?
        public let page: String?

        public var url: URL? { page.flatMap { URL(string: $0, relativeTo: FeedClient.site)?.absoluteURL } }
    }

    public struct Newsletter: Decodable, Sendable {
        public let editions: [Edition]?
    }

    public struct Edition: Decodable, Identifiable, Sendable {
        public let date: String?
        public let edition: String?
        public let title: String?
        public let summary: String?
        public let authored: Bool?
        public let page: String?
        public let email: String?

        public var id: String { page ?? "\(date ?? "")-\(edition ?? "")" }
        public var pageURL: URL? { page.flatMap(URL.init(string:)) }
        public var emailURL: URL? { email.flatMap(URL.init(string:)) }
    }
}
