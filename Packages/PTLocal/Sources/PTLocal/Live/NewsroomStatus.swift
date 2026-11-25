import Foundation

/// The newsroom's status feed (promptugal.news/api/v1/newsroom/status.json): the pipeline's stages with each one's
/// last run, and the runs ledger, newest first. Rebuilt at every release of the site. Read-only here: the app shows
/// it and links each run to its agent's page; nothing in the app starts, stops or steers an agent.
public struct NewsroomStatus: Decodable, Sendable {
    public let version: String?
    /// The day the site rebuilt this file ("2026-11-25").
    public let built: String?
    /// The newsroom's own page for this feed.
    public let page: String?
    public let counts: [String: Int]
    public let ledgerLast: String?
    public let agents: [Agent]
    public let pipeline: [Stage]
    public let runs: [Run]

    public static let url = URL(string: "https://promptugal.news/api/v1/newsroom/status.json")!
    public static let fallbackPage = URL(string: "https://promptugal.news/newsroom/index.html")!

    enum CodingKeys: String, CodingKey { case version, built, page, counts, ledger, agents, pipeline, runs }
    enum LedgerKeys: String, CodingKey { case last }
    enum LastKeys: String, CodingKey { case when }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try? c.decode(String.self, forKey: .version)
        built = try? c.decode(String.self, forKey: .built)
        page = try? c.decode(String.self, forKey: .page)
        counts = Self.intCounts(c)
        if let ledger = try? c.nestedContainer(keyedBy: LedgerKeys.self, forKey: .ledger),
           let last = try? ledger.nestedContainer(keyedBy: LastKeys.self, forKey: .last) {
            ledgerLast = try? last.decode(String.self, forKey: .when)
        } else {
            ledgerLast = nil
        }
        agents = c.lenientArray(Agent.self, forKey: .agents)
        pipeline = c.lenientArray(Stage.self, forKey: .pipeline)
        runs = c.lenientArray(Run.self, forKey: .runs)
    }

    /// Only the whole-number counts; anything else in `counts` is skipped, not fatal.
    private static func intCounts(_ c: KeyedDecodingContainer<CodingKeys>) -> [String: Int] {
        guard let raw = try? c.decode([String: Lenient<Int>].self, forKey: .counts) else { return [:] }
        var out: [String: Int] = [:]
        for (key, value) in raw { if let number = value.value { out[key] = number } }
        return out
    }

    /// The feed's own time: the day the site rebuilt it.
    public var builtAt: Date? { NewsroomDate.parse(built) }

    /// The newest run in the ledger, never later than now.
    public func newestRun(now: Date) -> Date? {
        let newest = runs.compactMap { NewsroomDate.parse($0.when) }.max() ?? NewsroomDate.parse(ledgerLast)
        return LiveClock.clamp(newest, now: now)
    }

    /// The newest runs first, at most `limit`. Times ahead of the clock sort as now.
    public func recentRuns(limit: Int, now: Date) -> [Run] {
        var dated: [DatedRun] = []
        for run in runs {
            let when: Date = LiveClock.clamp(NewsroomDate.parse(run.when), now: now) ?? Date.distantPast
            dated.append(DatedRun(run: run, when: when))
        }
        dated.sort { $0.when > $1.when }
        return dated.prefix(limit).map(\.run)
    }

    /// Where a run's provenance opens: its agent's page on the newsroom site, else the status page itself.
    public func link(for run: Run) -> URL {
        if let id = run.agent, let agent = agents.first(where: { $0.id == id }),
           let page = agent.page, let url = PlaceSite.safeURL(page) {
            return url
        }
        return pageURL
    }

    private struct DatedRun { let run: Run; let when: Date }

    public var pageURL: URL { page.flatMap { PlaceSite.safeURL($0) } ?? Self.fallbackPage }

    public struct Agent: Decodable, Sendable, Hashable {
        public let id: String
        public let name: String?
        public let label: String?
        public let status: String?
        public let page: String?
    }

    public struct Stage: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { stage }
        public let stage: String
        public let label: String?
        public let state: String?
        public let desks: [String]
        public let lastRun: LastRun?

        enum CodingKeys: String, CodingKey { case stage, label, state, desks, lastRun = "last_run" }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            stage = try c.decode(String.self, forKey: .stage)
            label = try? c.decode(String.self, forKey: .label)
            state = try? c.decode(String.self, forKey: .state)
            desks = (try? c.decode([String].self, forKey: .desks)) ?? []
            lastRun = try? c.decode(LastRun.self, forKey: .lastRun)
        }

        public var title: String { label ?? stage.capitalized }
    }

    public struct LastRun: Decodable, Sendable, Hashable {
        public let id: String?
        public let when: String?
        public let what: String?
    }

    public struct Run: Decodable, Sendable, Hashable, Identifiable {
        public let id: String
        public let when: String
        public let source: String?
        public let kind: String?
        /// The agent's full name ("curator@web-summit.vicky").
        public let by: String?
        /// The agent's id on the roster ("curator-vicky").
        public let agent: String?
        public let what: String
        public let issues: [String]
        public let release: String?

        enum CodingKeys: String, CodingKey { case id, when, source, kind, by, agent, what, issues, release }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            when = try c.decode(String.self, forKey: .when)
            source = try? c.decode(String.self, forKey: .source)
            kind = try? c.decode(String.self, forKey: .kind)
            by = try? c.decode(String.self, forKey: .by)
            agent = try? c.decode(String.self, forKey: .agent)
            what = (try? c.decode(String.self, forKey: .what)) ?? ""
            issues = (try? c.decode([String].self, forKey: .issues)) ?? []
            release = try? c.decode(String.self, forKey: .release)
        }

        /// "curator" from "curator@web-summit.vicky".
        public var handle: String {
            if let by, let first = by.split(separator: "@").first { return String(first) }
            return agent ?? "agent"
        }
    }
}
