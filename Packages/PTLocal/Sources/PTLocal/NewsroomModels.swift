import Foundation

/// The newsroom's own dashboard (promptugal.news/api/v1/newsroom/dashboard.json): every agent, its schedule, last
/// wake and next step in its own words, what waits on Dinis, and who handed what to whom. Read-only here.
public struct NewsroomDashboard: Decodable, Sendable {
    public let built: String?
    public let at: String?
    public let agents: [Agent]
    public let asks: [Ask]
    public let handoffs: [Handoff]

    enum CodingKeys: String, CodingKey { case built, at, agents, asks, handoffs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        built = try? c.decode(String.self, forKey: .built)
        at = try? c.decode(String.self, forKey: .at)
        agents = c.lenientArray(Agent.self, forKey: .agents)
        asks = c.lenientArray(Ask.self, forKey: .asks)
        handoffs = c.lenientArray(Handoff.self, forKey: .handoffs)
    }

    public var updated: Date? { NewsroomDate.parse(at) }

    /// The agent behind a place's site, if the dashboard lists it.
    public func agent(forPlace id: String) -> Agent? {
        agents.first { $0.role == "place.\(id)" }
    }

    public struct Agent: Decodable, Sendable, Identifiable, Hashable {
        public var id: String { agent }
        public let role: String
        public let agent: String
        public let focus: String?
        public let state: String?
        public let minute: Int?
        public let scheduled: Bool
        public let updated: String?
        public let stale: Bool
        public let lastWake: Wake?
        public let done: [String]
        public let next: [String]
        public let asks: [String]

        enum CodingKeys: String, CodingKey {
            case role, agent, focus, state, minute, scheduled, updated, stale, done, next, asks
            case lastWake = "last_wake"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            agent = try c.decode(String.self, forKey: .agent)
            role = (try? c.decode(String.self, forKey: .role)) ?? String(agent.split(separator: "@").first ?? "")
            focus = try? c.decode(String.self, forKey: .focus)
            state = try? c.decode(String.self, forKey: .state)
            minute = try? c.decode(Int.self, forKey: .minute)
            scheduled = (try? c.decode(Bool.self, forKey: .scheduled)) ?? false
            updated = try? c.decode(String.self, forKey: .updated)
            stale = (try? c.decode(Bool.self, forKey: .stale)) ?? false
            lastWake = try? c.decode(Wake.self, forKey: .lastWake)
            done = (try? c.decode([String].self, forKey: .done)) ?? []
            next = (try? c.decode([String].self, forKey: .next)) ?? []
            asks = (try? c.decode([String].self, forKey: .asks)) ?? []
        }

        public static func == (a: Agent, b: Agent) -> Bool { a.agent == b.agent && a.updated == b.updated }
        public func hash(into hasher: inout Hasher) { hasher.combine(agent) }

        public var updatedDate: Date? { NewsroomDate.parse(updated) }

        /// What the screens group by: a place agent, or one of the newsroom's desks.
        public var group: Group { role.hasPrefix("place.") ? .places : .newsroom }

        /// The place id for a place agent ("place.faro" → "faro").
        public var placeID: String? { role.hasPrefix("place.") ? String(role.dropFirst("place.".count)) : nil }

        /// A status read from what the agent says about itself. The dashboard has no status field, so this is a reading
        /// of `state`, `stale` and `asks`, and the screen says so.
        public var status: Status {
            let text = (state ?? "").lowercased()
            if text.hasPrefix("stopped") || text.hasPrefix("disabled") || text.contains("on hold") || text.hasPrefix("hold") { return .stopped }
            if stale { return .stale }
            if !asks.isEmpty { return .waiting }
            if text.hasPrefix("running") || scheduled { return .working }
            return .idle
        }
    }

    public enum Group: String, CaseIterable, Sendable, Identifiable {
        case places = "Places", newsroom = "Newsroom"
        public var id: Self { self }
    }

    public enum Status: String, CaseIterable, Sendable {
        case working = "Working", waiting = "Waiting on a person", stale = "Quiet", stopped = "Stopped", idle = "Idle"
    }

    public struct Wake: Decodable, Sendable, Hashable {
        public let started: String?
        public let outcome: String?
        public let line: String?
    }

    public struct Ask: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { (from ?? "") + "|" + (ask ?? "") }
        public let from: String?
        public let since: String?
        public let ask: String?
    }

    public struct Handoff: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { from + ">" + to }
        public let from: String
        public let to: String
        public let n: Int

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            from = try c.decode(String.self, forKey: .from)
            to = try c.decode(String.self, forKey: .to)
            n = (try? c.decode(Int.self, forKey: .n)) ?? 1
        }
        enum CodingKeys: String, CodingKey { case from, to, n }
    }
}

enum NewsroomDate {
    /// "2026-11-15T23:12Z", "2026-11-15T23:11:23.000Z" or "2026-11-15".
    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        // Minutes only, no seconds: "2026-11-15T23:12Z".
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm'Z'", "yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
