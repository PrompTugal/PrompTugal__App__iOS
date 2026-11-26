import Foundation

// conductor-report/v1 (briefs/2026-11-15__going-local/conductor-report-v1.md): the shared file the command
// centre reads. This is the reader side only, for the agents behind each place. When conductor.a.ios@'s PTAgents
// package lands, this type moves there and PTPlaces depends on it; the shape is the same.
//
// Where a place's report comes from, in order:
//   1. https://promptugal.news/api/v1/by-place/agents.json, a conductor-report/v1 with `newsroom` per agent
//      (asked of dev.places@; not served yet);
//   2. else built here from the record the website already serves: api/v1/newsroom/dashboard.json (every agent's
//      status in one file), else board/team/<role>/status.json, for the place agent, its parent place, and the
//      by-place team. Nothing is invented: a role with no record is left out.

public struct AgentsReport: Codable, Sendable, Equatable {
    public var v: Int
    public var made: String
    public var conductor: String
    public var agents: [ReportAgent]
    public var links: [ReportLink]
    public var messages: [ReportMessage]
    public var nextSteps: [String]?

    public init(v: Int = 1, made: String, conductor: String, agents: [ReportAgent], links: [ReportLink] = [],
                messages: [ReportMessage] = [], nextSteps: [String]? = nil) {
        self.v = v; self.made = made; self.conductor = conductor; self.agents = agents; self.links = links
        self.messages = messages; self.nextSteps = nextSteps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        v = c.int("v") ?? 1
        made = c.string("made") ?? ""
        conductor = c.string("conductor") ?? ""
        agents = c.lenientArray("agents")
        links = c.lenientArray("links")
        messages = c.lenientArray("messages")
        nextSteps = c.lenient([String].self, "nextSteps")
    }

    /// The agents that work on one place: its own newsroom, then the shared team.
    public func agents(for place: String) -> [ReportAgent] {
        agents.filter { $0.newsroom == place || $0.newsroom == nil || $0.newsroom == "*" }
    }
}

public struct ReportAgent: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// conductor | session | subagent
    public var kind: String
    public var role: String
    /// working | waiting | blocked | idle | done
    public var status: String
    public var doing: String
    public var waitingFor: String?
    public var parent: String?
    public var lastActive: String?
    public var lane: String?
    // Proposed PrompTugal additions (readers ignore unknown fields).
    public var account: String?
    public var newsroom: String?
    public var newsroomRole: String?
    public var policy: String?
    /// What it has done, newest last (from status.json `done`; not in v1, harmless to add).
    public var done: [String]?
    public var next: [String]?
    public var commits: [AgentCommit]?

    public init(id: String, name: String, kind: String = "session", role: String = "", status: String = "working",
                doing: String = "", waitingFor: String? = nil, parent: String? = nil, lastActive: String? = nil,
                lane: String? = nil, account: String? = nil, newsroom: String? = nil, newsroomRole: String? = nil,
                policy: String? = nil, done: [String]? = nil, next: [String]? = nil, commits: [AgentCommit]? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.role = role; self.status = status; self.doing = doing
        self.waitingFor = waitingFor; self.parent = parent; self.lastActive = lastActive; self.lane = lane
        self.account = account; self.newsroom = newsroom; self.newsroomRole = newsroomRole; self.policy = policy
        self.done = done; self.next = next; self.commits = commits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = try c.decode(String.self, forKey: AnyKey("id"))
        name = c.string("name") ?? id
        kind = c.string("kind") ?? "session"
        role = c.string("role") ?? ""
        status = c.string("status") ?? "idle"
        doing = c.string("doing") ?? ""
        waitingFor = c.string("waitingFor")
        parent = c.string("parent")
        lastActive = c.string("lastActive")
        lane = c.string("lane")
        account = c.string("account")
        newsroom = c.string("newsroom")
        newsroomRole = c.string("newsroomRole")
        policy = c.string("policy")
        done = c.lenient([String].self, "done")
        next = c.lenient([String].self, "next")
        commits = c.lenient([AgentCommit].self, "commits")
    }

    /// "place.loule" from "place.loule@PrompTugal.dinis".
    public var handle: String { id.split(separator: "@").first.map(String.init) ?? id }
}

public struct ReportLink: Codable, Sendable, Equatable, Hashable {
    public var from: String
    public var to: String
    public var label: String

    public init(from: String, to: String, label: String) { self.from = from; self.to = to; self.label = label }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        from = c.string("from") ?? ""
        to = c.string("to") ?? ""
        label = c.string("label") ?? ""
    }
}

public struct ReportMessage: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var agent: String
    public var from: String
    public var at: String
    public var text: String

    public init(id: String, agent: String, from: String, at: String, text: String) {
        self.id = id; self.agent = agent; self.from = from; self.at = at; self.text = text
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.string("id") ?? UUID().uuidString
        agent = c.string("agent") ?? ""
        from = c.string("from") ?? ""
        at = c.string("at") ?? ""
        text = c.string("text") ?? ""
    }
}

// MARK: - The record the website already serves

/// api/v1/newsroom/dashboard.json: every agent's status in one file (57 agents on 16 Nov), the same fields as status.json.
public struct NewsroomDashboard: Decodable, Sendable, Equatable {
    public var built: String
    public var agents: [AgentStatus]

    public init(built: String = "", agents: [AgentStatus]) { self.built = built; self.agents = agents }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        built = c.string("built") ?? ""
        agents = c.lenientArray("agents")
    }

    /// The agents by role ("place.loule", "dev.places").
    public var byRole: [String: AgentStatus] {
        Dictionary(agents.map { ($0.role, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

/// board/team/<role>/status.json on promptugal.news, and each entry of the newsroom dashboard.
public struct AgentStatus: Decodable, Sendable, Equatable {
    public var agent: String
    /// "place.loule"; from the dashboard, or derived from the agent id.
    public var role: String
    public var focus: String
    public var state: String
    public var updated: String
    public var done: [String]
    public var next: [String]
    public var asks: [String]
    public var debrief: String?
    /// Its latest commits on this place (api/v1/by-place/<id>/agents.json only).
    public var commits: [AgentCommit] = []

    public init(agent: String, focus: String = "", state: String = "", updated: String = "", done: [String] = [],
                next: [String] = [], asks: [String] = [], debrief: String? = nil) {
        self.agent = agent; self.focus = focus; self.state = state; self.updated = updated; self.done = done
        self.next = next; self.asks = asks; self.debrief = debrief
        self.role = agent.split(separator: "@").first.map(String.init) ?? agent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        agent = try c.decode(String.self, forKey: AnyKey("agent"))
        role = c.string("role") ?? (agent.split(separator: "@").first.map(String.init) ?? agent)
        focus = c.string("focus") ?? ""
        state = c.string("state") ?? ""
        updated = c.string("updated") ?? ""
        done = c.lenientArray("done")
        next = c.lenientArray("next")
        asks = c.lenientArray("asks")
        debrief = c.string("debrief")
        commits = c.lenientArray("commits")
    }
}

public struct AgentCommit: Codable, Sendable, Equatable, Hashable {
    public var hash: String
    public var date: String
    public var subject: String
    public var url: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        hash = c.string("hash") ?? ""
        date = c.string("date") ?? ""
        subject = c.string("subject") ?? ""
        url = c.string("url") ?? ""
    }
}

/// api/v1/by-place/<id>/agents.json (dev.places@): the place's own agent, then the shared agents, from the record.
/// Its `role` says place or shared, so each entry's role is taken from its agent id instead.
public struct PlaceAgentsFile: Decodable, Sendable, Equatable {
    public var place: String
    public var agents: [AgentStatus]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        place = c.string("place") ?? ""
        agents = (c.lenientArray("agents") as [AgentStatus]).map { status in
            var status = status
            status.role = status.agent.split(separator: "@").first.map(String.init) ?? status.agent
            return status
        }
    }

    public var byRole: [String: AgentStatus] {
        Dictionary(agents.map { ($0.role, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

/// Builds a conductor-report/v1 for one place from status files. Pure, so it is tested.
public enum PlaceAgents {
    /// The by-place team that works on every place (their status files, where they exist).
    public static let sharedRoles = ["conductor", "dev.places", "designer.places", "viz.places", "data.places", "detective.places",
                                     "ios.places", "datasci.places", "ontologist", "abp"]

    /// What each shared role does for a place, in a few words (from the briefs; shown beside the record).
    public static let roleLabels: [String: String] = [
        "conductor": "starts and watches the agents",
        "datasci.places": "serves the data and the API",
        "dev.places": "builds the page",
        "designer.places": "designs the look",
        "viz.places": "draws the newsroom",
        "data.places": "makes it queryable",
        "detective.places": "connects the dots",
        "ios.places": "puts it in the app",
        "ontologist": "keeps the graph",
        "abp": "writes the policies",
    ]

    /// The status files to read for a place: its own agent, its parent place, then the shared team.
    public static func roles(for place: PlaceSummary) -> [String] {
        var roles = ["place.\(place.id)"]
        if !place.parent.isEmpty { roles.append("place.\(place.parent)") }
        return roles + sharedRoles
    }

    public static func report(place: PlaceSummary, statuses: [String: AgentStatus], made: Date = .now) -> AgentsReport {
        let own = "place.\(place.id)"
        let parent = place.parent.isEmpty ? nil : "place.\(place.parent)"
        var agents: [ReportAgent] = []
        var links: [ReportLink] = []
        for role in roles(for: place) {
            guard let status = statuses[role] else { continue }
            let agentRole: String
            let newsroomRole: String
            if role == own {
                agentRole = status.focus.isEmpty ? String(localized: "The place agent: researches and writes \(place.name)", bundle: .module) : status.focus
                newsroomRole = "place"
            } else if role == parent {
                agentRole = status.focus
                newsroomRole = "regional"
            } else {
                agentRole = roleLabels[role] ?? status.focus
                newsroomRole = role
            }
            agents.append(ReportAgent(
                id: status.agent, name: role, kind: "session", role: agentRole, status: statusWord(status),
                doing: status.state, waitingFor: status.asks.first, parent: role == own ? parent.flatMap { statuses[$0]?.agent } : nil,
                lastActive: status.updated, newsroom: role == own ? place.id : (role == parent ? place.parent : nil),
                newsroomRole: newsroomRole, done: status.done, next: status.next, commits: status.commits.isEmpty ? nil : status.commits))
        }
        let ownID = statuses[own]?.agent
        for agent in agents where agent.id != ownID {
            guard let ownID else { break }
            if agent.newsroomRole == "regional" {
                links.append(ReportLink(from: ownID, to: agent.id, label: "rises to"))
            } else {
                links.append(ReportLink(from: agent.id, to: ownID, label: roleLabels[agent.name] ?? "works with"))
            }
        }
        return AgentsReport(made: ISO8601DateFormatter().string(from: made), conductor: "conductor@PrompTugal.dinis",
                            agents: agents, links: links)
    }

    /// working | waiting | done, from the free-text state and the open asks.
    public static func statusWord(_ status: AgentStatus) -> String {
        let state = status.state.lowercased()
        if state.contains("stopped") || state.contains("handed over") || state.contains("done") && status.next.isEmpty { return "done" }
        if state.contains("blocked") { return "blocked" }
        if !status.asks.isEmpty { return "waiting" }
        return "working"
    }
}

// MARK: - Dates

public enum PlaceDates {
    /// Reads "2026-11-15T22:25Z", "2026-11-15T22:25:10Z", "2026-11-15T22:25:10.123Z" or "2026-11-15".
    public static func parse(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: text) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: text) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mmX", "yyyy-MM-dd'T'HH:mm'Z'", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: text) { return d }
        }
        return nil
    }

    /// "28 Jul 2026" from "2026-07-28"; a range keeps its first day; text that is not a date comes back as it is.
    public static func short(_ text: String) -> String {
        let first = String(text.prefix(10))
        guard let date = parse(first) else { return text }
        let f = DateFormatter()
        f.locale = PlacesLanguage.locale
        f.timeZone = TimeZone(identifier: "Europe/Lisbon")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    /// "12 min ago" for a status time.
    public static func ago(_ text: String, now: Date = .now) -> String {
        guard let date = parse(text) else { return text }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }
}
