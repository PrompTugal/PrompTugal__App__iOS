import Foundation
import Observation
import PTCore
import SwiftUI

/// Where the news screens read the feed's stories from. The app supplies it (today `ReaderStore`),
/// so PTNews does not depend on the agenda or the team's stores.
@MainActor
public protocol NewsSource: AnyObject, Observable {
    var news: [Story] { get }
    var newsUpdated: Date? { get }
    var newsUnavailable: Bool { get }
    func refresh() async
}

/// Used when an app has not supplied a source: the news screen shows its loading state.
@MainActor @Observable
final class EmptyNewsSource: NewsSource {
    static let shared = EmptyNewsSource()
    var news: [Story] { [] }
    var newsUpdated: Date? { nil }
    var newsUnavailable: Bool { false }
    func refresh() async {}
}

private struct NewsSourceKey: EnvironmentKey {
    static var defaultValue: (any NewsSource)? { nil }
}

extension EnvironmentValues {
    /// The stories feed for the news screens. Set once by the app's root.
    public var newsSource: (any NewsSource)? {
        get { self[NewsSourceKey.self] }
        set { self[NewsSourceKey.self] = newValue }
    }
}

public enum NewsroomAPI {
    public static func url(_ path: String) -> URL { FeedClient.site.appendingPathComponent("api/v1/\(path)") }
}

/// The newsroom feeds the news screens read: newsletter editions, the story board and the graph.
@MainActor @Observable
public final class NewsFeeds {
    public let newsletter = RemoteFeed<Wire.Newsletter>(name: "news/newsletter", url: NewsroomAPI.url("newsletter.json"))
    public let board = RemoteFeed<Wire.StoryBoard>(name: "newsroom/stories", url: NewsroomAPI.url("newsroom/stories.json"))
    /// The whole graph, about 0.9 MB. Loaded only when the graph screen opens.
    public let graph: RemoteFeed<GraphExplorer> = {
        let feed = RemoteFeed<GraphExplorer>(name: "news/graph-explorer", url: NewsroomAPI.url("graph/explorer.json"))
        feed.freshFor = 3600
        return feed
    }()

    public init() {}

    public func refresh(force: Bool = false) async {
        async let a: Void = newsletter.load(force: force)
        async let b: Void = board.load(force: force)
        _ = await (a, b)
    }
}

/// A list row with a title, a line of detail and an icon. The news screens' own copy of the
/// dashboards' `InfoRow` (which stays in the Team app).
struct NewsRow: View {
    let title: String
    var detail: String?
    var symbol: String?
    var tint: Color = Palette.muted

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(Palette.ink)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Palette.muted).lineLimit(3)
                }
            }
            Spacer(minLength: Space.s)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
