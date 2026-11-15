import Foundation

// The newsroom in action: the extra fields the live view reads from dashboard.json beside NewsroomDashboard, and the
// events it shows in its ticker. Everything here is read from promptugal.news; nothing acts on an agent.

/// Fields of dashboard.json the shared model does not keep: each agent's 24-hour fire grid and commit count, and the
/// grid's hour labels. Decoded from the same bytes as `NewsroomDashboard`.
public struct LiveDashboardExtras: Decodable, Sendable, Equatable {
    public let gridHours: [String]
    public let agents: [String: Agent]

    public struct Agent: Sendable, Equatable {
        /// One flag per hour of `gridHours`: true when the agent fired in that hour.
        public let fired: [Bool]
        public let commits24h: Int
    }

    enum CodingKeys: String, CodingKey { case gridHours = "grid_hours", agents }

    struct RawAgent: Decodable {
        let agent: String?
        let role: String?
        let grid: String?
        let commits: Int?
        enum CodingKeys: String, CodingKey { case agent, role, grid, commits = "commits_24h" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            agent = try? c.decode(String.self, forKey: .agent)
            role = try? c.decode(String.self, forKey: .role)
            grid = try? c.decode(String.self, forKey: .grid)
            commits = try? c.decode(Int.self, forKey: .commits)
        }
    }

    public init(gridHours: [String], agents: [String: Agent]) {
        self.gridHours = gridHours
        self.agents = agents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gridHours = (try? c.decode([String].self, forKey: .gridHours)) ?? []
        let raw = c.lenientArray(RawAgent.self, forKey: .agents)
        var out: [String: Agent] = [:]
        for item in raw {
            guard let agent = item.agent else { continue }
            let role = item.role ?? String(agent.split(separator: "@").first ?? "")
            out[role] = Agent(fired: Self.parseGrid(item.grid), commits24h: item.commits ?? 0)
        }
        agents = out
    }

    /// "·····●●●": a dot is a quiet hour, anything else a fire.
    static func parseGrid(_ text: String?) -> [Bool] {
        guard let text else { return [] }
        return text.map { $0 != "·" && $0 != "." && $0 != " " && $0 != "-" }
    }
}

/// One line of the ticker: something an agent did or said, with when.
public struct LiveEvent: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case update, wake, done, ask, handoff, joined, stories, mapped, live
    }

    /// Where the line came from: read from the latest dashboard, seen to change while this screen was open, or
    /// changed since this device last looked.
    public enum Origin: String, Sendable { case latest, watched, sinceLastVisit }

    public let id: String
    public let date: Date
    /// The agent's role, "place.faro"; for a handoff, the sender.
    public let role: String
    /// For a handoff, the receiver.
    public let to: String?
    public let kind: Kind
    public let text: String
    public let detail: String?
    public let origin: Origin

    public init(date: Date, role: String, to: String? = nil, kind: Kind, text: String, detail: String? = nil, origin: Origin) {
        self.date = date
        self.role = role
        self.to = to
        self.kind = kind
        self.text = text
        self.detail = detail
        self.origin = origin
        id = [kind.rawValue, role, to ?? "", String(Int(date.timeIntervalSince1970)), text].joined(separator: "|")
    }

    public var symbol: String {
        switch self.kind {
        case .update: "pencil.line"
        case .wake: "alarm"
        case .done: "checkmark.circle"
        case .ask: "hand.raised"
        case .handoff: "arrow.left.arrow.right"
        case .joined: "person.badge.plus"
        case .stories: "newspaper"
        case .mapped: "mappin.and.ellipse"
        case .live: "dot.radiowaves.left.and.right"
        }
    }
}

extension NewsroomDashboard.Agent {
    /// "place.faro@": how the ticker names an agent.
    public var handle: String { role + "@" }

    /// The town's name for a town agent, "Faro"; the region for place.algarve.
    public var placeName: String? { placeID.flatMap { PlaceDirectory.info($0)?.name } }

    /// When the agent last showed a sign of life: its `updated` or its last wake, whichever is later. Agents sometimes
    /// write a time a few minutes ahead of the clock; that is read as now, never as the future.
    public func lastSign(now: Date) -> Date? {
        let dates = [updatedDate, NewsroomDate.parse(lastWake?.started)].compactMap { $0 }
        guard let latest = dates.max() else { return nil }
        return min(latest, now)
    }
}

enum LiveClock {
    /// A time an agent wrote, never later than now.
    static func clamp(_ date: Date?, now: Date) -> Date? { date.map { min($0, now) } }
}
