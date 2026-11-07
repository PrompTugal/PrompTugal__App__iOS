import Foundation
import Observation

/// All the public feeds the dashboards read, in one place, put in the environment by the shell.
@MainActor @Observable
final class DashboardData {
    /// The team member this device belongs to. Set in Settings. The team session's
    /// identity store replaces this once it lands.
    static let meKey = "team.me"

    let team = RemoteFeed<Wire.Me>(name: "team/me", url: TeamSite.base.appendingPathComponent("me.json"))
    let dashboard = RemoteFeed<Wire.NewsroomDashboard>(name: "newsroom/dashboard", url: NewsroomAPI.url("newsroom/dashboard.json"))
    let status = RemoteFeed<Wire.NewsroomStatus>(name: "newsroom/status", url: NewsroomAPI.url("newsroom/status.json"))
    let board = RemoteFeed<Wire.StoryBoard>(name: "newsroom/stories", url: NewsroomAPI.url("newsroom/stories.json"))
    let decisions = RemoteFeed<Wire.Decisions>(name: "newsroom/decisions", url: NewsroomAPI.url("newsroom/decisions.json"))
    let desks = RemoteFeed<Wire.Desks>(name: "newsroom/desks", url: NewsroomAPI.url("newsroom/desks.json"))
    let newsletter = RemoteFeed<Wire.Newsletter>(name: "news/newsletter", url: NewsroomAPI.url("newsletter.json"))

    /// The whole graph, about 0.9 MB. Loaded only when the graph screen opens.
    let graph: RemoteFeed<GraphExplorer> = {
        let feed = RemoteFeed<GraphExplorer>(name: "news/graph-explorer", url: NewsroomAPI.url("graph/explorer.json"))
        feed.freshFor = 3600
        return feed
    }()

    @ObservationIgnored private var centres: [String: RemoteFeed<Wire.CommandCentre>] = [:]

    /// The command centre feed for one person, created on first use.
    func commandCentre(_ id: String) -> RemoteFeed<Wire.CommandCentre> {
        if let feed = centres[id] { return feed }
        let feed = RemoteFeed<Wire.CommandCentre>(
            name: "team/cc-\(id)", url: TeamSite.base.appendingPathComponent("people/\(id)/app/data.json"))
        centres[id] = feed
        return feed
    }

    func person(_ id: String) -> Wire.Person? { team.value?.people?[id] }

    /// Every feed, for the Storage and Network panels.
    var feedSummaries: [(name: String, url: URL, updated: Date?, bytes: Int, phase: LoadPhase)] {
        var rows: [(String, URL, Date?, Int, LoadPhase)] = [
            (team.name, team.url, team.updated, team.bytes, team.phase),
            (dashboard.name, dashboard.url, dashboard.updated, dashboard.bytes, dashboard.phase),
            (status.name, status.url, status.updated, status.bytes, status.phase),
            (board.name, board.url, board.updated, board.bytes, board.phase),
            (decisions.name, decisions.url, decisions.updated, decisions.bytes, decisions.phase),
            (desks.name, desks.url, desks.updated, desks.bytes, desks.phase),
            (newsletter.name, newsletter.url, newsletter.updated, newsletter.bytes, newsletter.phase),
            (graph.name, graph.url, graph.updated, graph.bytes, graph.phase),
        ]
        for feed in centres.values.sorted(by: { $0.name < $1.name }) {
            rows.append((feed.name, feed.url, feed.updated, feed.bytes, feed.phase))
        }
        return rows.map { (name: $0.0, url: $0.1, updated: $0.2, bytes: $0.3, phase: $0.4) }
    }

    func refreshTeam(force: Bool = false) async {
        await team.load(force: force)
    }

    func refreshNewsroom(force: Bool = false) async {
        async let a: Void = dashboard.load(force: force)
        async let b: Void = status.load(force: force)
        async let c: Void = board.load(force: force)
        async let d: Void = decisions.load(force: force)
        async let e: Void = desks.load(force: force)
        _ = await (a, b, c, d, e)
    }

    func refreshAll(force: Bool = false) async {
        async let a: Void = refreshTeam(force: force)
        async let b: Void = refreshNewsroom(force: force)
        async let c: Void = newsletter.load(force: force)
        _ = await (a, b, c)
    }
}

enum NewsroomAPI {
    static func url(_ path: String) -> URL { FeedClient.site.appendingPathComponent("api/v1/\(path)") }
}
