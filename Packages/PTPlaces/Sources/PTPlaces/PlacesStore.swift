import Foundation
import Observation
import PTCore

/// Everything the places screens read, fetched from promptugal.news and cached on disk (RemoteFeed), so the
/// magazine opens offline after one good load.
@MainActor @Observable
public final class PlacesStore {
    public static let shared = PlacesStore()

    public static let site = URL(string: "https://promptugal.news/")!
    public static let indexURL = URL(string: "https://promptugal.news/api/v1/by-place/index.json")!
    public static let listURL = URL(string: "https://promptugal.news/data/by-place/places.json")!
    /// conductor-report/v1 for the by-place team, once dev.places@ serves it (asked; 404 until then).
    public static let agentsURL = URL(string: "https://promptugal.news/api/v1/by-place/agents.json")!
    /// Every agent's status in one file (the Team app's Agents dashboard reads it too).
    public static let dashboardURL = URL(string: "https://promptugal.news/api/v1/newsroom/dashboard.json")!

    /// JSON first (Dinis, 15 Nov): the place under /api/v1/, the same shape as data/by-place/<id>.json plus provenance and articles.
    public static func placeURL(_ id: String) -> URL { site.appendingPathComponent("api/v1/by-place/\(id).json") }
    public static func statusURL(_ role: String) -> URL { site.appendingPathComponent("board/team/\(role)/status.json") }
    public static func pageURL(_ place: PlaceSummary) -> URL {
        place.path.isEmpty ? site : site.appendingPathComponent(place.path)
    }

    public let index = RemoteFeed<PlaceIndex>(name: "places.index", url: PlacesStore.indexURL)
    public let list = RemoteFeed<PlaceIndex>(name: "places.list", url: PlacesStore.listURL)
    public let teamReport = RemoteFeed<AgentsReport>(name: "places.agents", url: PlacesStore.agentsURL)
    public let dashboard = RemoteFeed<NewsroomDashboard>(name: "places.dashboard", url: PlacesStore.dashboardURL)
    public private(set) var files: [String: RemoteFeed<PlaceFile>] = [:]
    public private(set) var statuses: [String: RemoteFeed<AgentStatus>] = [:]

    public init() {
        index.freshFor = 300
        list.freshFor = 3_600
        teamReport.freshFor = 300
        dashboard.freshFor = 120
    }

    /// The places in the website's order, with each town's seat merged in from places.json.
    public var places: [PlaceSummary] {
        let seats = Dictionary((list.value?.places ?? []).map { ($0.id, $0.at) }, uniquingKeysWith: { a, _ in a })
        let base = index.value?.places ?? list.value?.places ?? []
        return base.map { place in
            var place = place
            if place.at == nil { place.at = seats[place.id] ?? nil }
            if place.at == nil { place.at = PlaceGeo.fallback[place.id] }
            return place
        }
    }

    public var towns: [PlaceSummary] { places.filter(\.isTown) }
    public func place(_ id: String) -> PlaceSummary? { places.first { $0.id == id } }
    public func children(of id: String) -> [PlaceSummary] { places.filter { $0.parent == id } }
    public func file(_ id: String) -> PlaceFile? { files[id]?.value }

    public var phase: LoadPhase { index.value == nil && list.value != nil ? list.phase : index.phase }

    /// The whole magazine: the index, the list, every place file, in parallel.
    public func load(force: Bool = false) async {
        async let a: Void = index.load(force: force)
        async let b: Void = list.load(force: force)
        async let c: Void = dashboard.load(force: force)
        _ = await (a, b, c)
        await withTaskGroup(of: Void.self) { group in
            for place in places {
                let placeFeed = feed(for: place.id)
                group.addTask { await placeFeed.load(force: force) }
            }
        }
    }

    public func loadPlace(_ id: String, force: Bool = false) async {
        await feed(for: id).load(force: force)
    }

    public func feed(for id: String) -> RemoteFeed<PlaceFile> {
        if let feed = files[id] { return feed }
        let feed = RemoteFeed<PlaceFile>(name: "places.\(id)", url: Self.placeURL(id))
        feed.freshFor = 300
        files[id] = feed
        return feed
    }

    // MARK: Agents

    /// The agents behind a place: the served conductor-report/v1 if there is one, else built from status files.
    public func agentsReport(for place: PlaceSummary) -> AgentsReport? {
        if let served = teamReport.value, !served.agents(for: place.id).isEmpty {
            var report = served
            report.agents = served.agents(for: place.id)
            return report
        }
        let fromDashboard = dashboard.value?.byRole ?? [:]
        let found = PlaceAgents.roles(for: place).reduce(into: [String: AgentStatus]()) { result, role in
            if let status = fromDashboard[role] ?? statuses[role]?.value { result[role] = status }
        }
        return found.isEmpty ? nil : PlaceAgents.report(place: place, statuses: found)
    }

    public func loadAgents(for place: PlaceSummary, force: Bool = false) async {
        async let report: Void = teamReport.load(force: force)
        async let board: Void = dashboard.load(force: force)
        _ = await (report, board)
        if let served = teamReport.value, !served.agents(for: place.id).isEmpty { return }
        if let board = dashboard.value?.byRole, board["place.\(place.id)"] != nil { return }
        await withTaskGroup(of: Void.self) { group in
            for role in PlaceAgents.roles(for: place) {
                let statusFeed = status(for: role)
                group.addTask { await statusFeed.load(force: force) }
            }
        }
    }

    /// How many agents work on the by-place sites, from the team list (place-agents) and the shared roles found.
    public var agentCount: Int {
        if let board = dashboard.value { return board.agents.count }
        return places.filter { !$0.agent.isEmpty }.count + PlaceAgents.sharedRoles.filter { statuses[$0]?.value != nil }.count
    }

    /// A place agent's record from the dashboard (state, updated), for the home's faces.
    public func placeAgentStatus(_ place: PlaceSummary) -> AgentStatus? {
        dashboard.value?.byRole["place.\(place.id)"]
    }

    private func status(for role: String) -> RemoteFeed<AgentStatus> {
        if let feed = statuses[role] { return feed }
        let feed = RemoteFeed<AgentStatus>(name: "agent.\(role)", url: Self.statusURL(role))
        feed.freshFor = 120
        statuses[role] = feed
        return feed
    }

    // MARK: Across places

    /// Every story from every town, newest first, with its town.
    public func latestAcrossTowns(limit: Int = 20) -> [(place: PlaceSummary, item: NewsItem)] {
        var seen = Set<String>()
        var all: [(place: PlaceSummary, item: NewsItem)] = []
        for place in towns {
            for item in file(place.id)?.aiNews ?? [] where !seen.contains(item.url.isEmpty ? item.title : item.url) {
                seen.insert(item.url.isEmpty ? item.title : item.url)
                all.append((place, item))
            }
        }
        return Array(all.sorted { $0.item.date > $1.item.date }.prefix(limit))
    }
}

/// Seats for places that places.json does not give a point to (the country and the region).
public enum PlaceGeo {
    public static let fallback: [String: [Double]] = [
        "portugal": [-8.2, 39.6],
        "algarve": [-8.15, 37.17],
    ]

    /// The Algarve's span, for the region map.
    public static let algarveCenter: [Double] = [-8.15, 37.2]
}
