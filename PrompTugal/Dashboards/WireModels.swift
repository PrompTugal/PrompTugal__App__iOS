import Foundation

// MARK: - Team site: me.json

extension Wire {
    struct Me: Decodable, Sendable {
        let builtAt: String?
        let version: String?
        let people: [String: Person]?

        enum CodingKeys: String, CodingKey { case builtAt = "built_at", version, people }

        var built: Date? { WireDate.parse(builtAt) }
        /// People in the site's own order is lost in a dictionary, so sort by load, then name.
        var sortedPeople: [Person] {
            (people ?? [:]).values.sorted {
                ($0.focus == true ? 0 : 1, $0.name ?? "") < ($1.focus == true ? 0 : 1, $1.name ?? "")
            }
        }
    }

    struct Person: Decodable, Identifiable, Sendable {
        let id: String
        let name: String?
        let first: String?
        let role: String?
        let colour: String?
        let level: Int?
        let levelName: String?
        let onlyYou: Int?
        let decide: Int?
        let open: Int?
        let overdue: Int?
        let soon: Int?
        let focus: Bool?
        let standupAt: String?
        let standup: String?
        let briefing: String?
        let next: NextStep?
        let urgent: [Urgent]?
        let decisions: [PersonDecision]?
        let agents: [PersonAgent]?
        let messages: [Message]?
        let daily: [Double]?
        let days: [String]?

        enum CodingKeys: String, CodingKey {
            case id, name, first, role, colour, level, open, overdue, soon, focus, standup, briefing, next
            case urgent, decisions, agents, messages, daily, days, decide
            case levelName = "level_name", onlyYou = "only_you", standupAt = "standup_at"
        }

        var displayName: String { name ?? first ?? id }
        var initials: String {
            let parts = displayName.split(separator: " ").prefix(2)
            return parts.compactMap(\.first).map(String.init).joined().uppercased()
        }
        var standupDate: Date? { WireDate.parse(standupAt) }
        var briefingURL: URL? { briefing.flatMap { URL(string: $0, relativeTo: TeamEndpoints.base)?.absoluteURL } }
        var commandCentreURL: URL { TeamEndpoints.base.appendingPathComponent("people/\(id)/app/") }
        /// The badge the brief proposes: only you + decide + overdue.
        var attention: Int { (onlyYou ?? 0) + (decide ?? 0) + (overdue ?? 0) }
        var activeAgents: Int { (agents ?? []).filter { $0.status == "active" }.count }
    }

    struct NextStep: Decodable, Sendable { let step: String?; let how: String? }

    struct Urgent: Decodable, Identifiable, Sendable {
        let id: String
        let title: String?
        let due: String?
        let status: String?
        let late: Bool?
    }

    struct PersonDecision: Decodable, Hashable, Sendable {
        let what: String?
        let issue: String?
        let source: String?
        var sourceURL: URL? { source.flatMap { URL(string: $0, relativeTo: TeamEndpoints.base)?.absoluteURL } }
    }

    struct PersonAgent: Decodable, Hashable, Sendable {
        let name: String?
        let status: String?
        let lastAt: String?
        let last: String?
        enum CodingKeys: String, CodingKey { case name, status, last, lastAt = "last_at" }
        var lastDate: Date? { WireDate.parse(lastAt) }
    }

    struct Message: Decodable, Hashable, Sendable {
        let at: String?
        let from: String?
        let subject: String?
        var date: Date? { WireDate.parse(at) }
    }
}

// MARK: - Team site: people/<id>/app/data.json (the command centre)

extension Wire {
    struct CommandCentre: Decodable, Sendable {
        let builtAt: String?
        let version: String?
        let person: CCPerson?
        let decisions: [CCDecision]?
        let issues: [CCIssue]?
        let workstreams: [CCWorkstream]?

        enum CodingKeys: String, CodingKey { case builtAt = "built_at", version, person, decisions, issues, workstreams }
    }

    struct CCPerson: Decodable, Sendable {
        let id: String?
        let name: String?
        let role: String?
        let owns: [String]?
        let status: String?
    }

    struct CCDecision: Decodable, Hashable, Sendable {
        let who: String?
        let what: String?
        let issue: String?
        let since: String?
        let source: String?
        let recommend: String?
        var sinceDate: Date? { WireDate.parse(since) }
    }

    struct CCIssue: Decodable, Identifiable, Sendable {
        let id: String
        let title: String?
        let area: String?
        let due: String?
        let dueAt: String?
        let status: String?
        let mine: Bool?
        let named: Bool?
        let stream: String?
        let file: String?

        enum CodingKeys: String, CodingKey {
            case id, title, area, due, status, mine, named, stream, file
            case dueAt = "due_at"
        }
        var dueDate: Date? { WireDate.parse(dueAt) }
        var isDone: Bool { ["done", "closed"].contains(status?.lowercased() ?? "") }
    }

    struct CCWorkstream: Decodable, Identifiable, Sendable {
        let id: String
        let name: String?
        let issues: [String]?
        let goal: String?
    }
}

// MARK: - Newsroom: dashboard.json

extension Wire {
    struct NewsroomDashboard: Decodable, Sendable {
        let built: String?
        let at: String?
        let asks: [Ask]?
        let agents: [DashAgent]?
        let gridHours: [String]?
        let handoffs: [Handoff]?
        let schedule: [ScheduleRow]?

        enum CodingKeys: String, CodingKey { case built, at, asks, agents, handoffs, schedule, gridHours = "grid_hours" }
        var date: Date? { WireDate.parse(at) }
    }

    struct Ask: Decodable, Hashable, Sendable {
        let from: String?
        let since: String?
        let ask: String?
    }

    struct DashAgent: Decodable, Identifiable, Sendable {
        let role: String?
        let agent: String?
        let focus: String?
        let state: String?
        let minute: Int?
        let scheduled: Bool?
        let updated: String?
        let stale: Bool?
        let lastWake: Wake?
        let done: [LooseText]?
        let next: [LooseText]?
        let asks: [LooseText]?
        let commits24h: Int?
        let grid: String?

        enum CodingKeys: String, CodingKey {
            case role, agent, focus, state, minute, scheduled, updated, stale, done, next, asks, grid
            case lastWake = "last_wake", commits24h = "commits_24h"
        }
        var id: String { agent ?? role ?? UUID().uuidString }
        var shortName: String { role ?? agent?.components(separatedBy: "@").first ?? "agent" }
        var cells: [WakeCell] { (grid ?? "").map(WakeCell.init) }
    }

    struct Wake: Decodable, Sendable {
        let started: String?
        let outcome: String?
        let release: String?
        let line: String?
        var date: Date? { WireDate.parse(started) }
    }

    struct Handoff: Decodable, Hashable, Sendable {
        let from: String?
        let to: String?
        let n: Int?
    }

    struct ScheduleRow: Decodable, Hashable, Sendable {
        let agent: String?
        let minute: Int?
        let cron: String?
        let state: String?
        let since: String?
        let note: String?
    }
}

/// One hour of the wake grid. The legend is the newsroom dashboard's:
/// ● went well, ◐ partial, ○ idle, ✕ failed, H held, • a commit outside a wake, · nothing.
enum WakeCell: Hashable, Sendable {
    case ok, partial, idle, failed, held, commit, none

    init(_ character: Character) {
        switch character {
        case "●": self = .ok
        case "◐": self = .partial
        case "○": self = .idle
        case "✕", "x", "X": self = .failed
        case "H": self = .held
        case "•": self = .commit
        default: self = .none
        }
    }

    var label: String {
        switch self {
        case .ok: "went well"
        case .partial: "partial"
        case .idle: "idle"
        case .failed: "failed"
        case .held: "held"
        case .commit: "a commit outside a wake"
        case .none: "nothing"
        }
    }

    static let legend: [WakeCell] = [.ok, .partial, .idle, .failed, .held, .commit]
}

// MARK: - Newsroom: status.json

extension Wire {
    struct NewsroomStatus: Decodable, Sendable {
        let version: String?
        let built: String?
        let counts: [String: Int]?
        let agents: [StatusAgent]?
        let pipeline: [Stage]?
        let buildOrder: [BuildStep]?
        let waiting: [Waiting]?
        let runs: [Run]?

        enum CodingKeys: String, CodingKey {
            case version, built, counts, agents, pipeline, waiting, runs
            case buildOrder = "build_order"
        }
    }

    struct StatusAgent: Decodable, Identifiable, Sendable {
        let id: String
        let name: String?
        let label: String?
        let person: String?
        let kind: String?
        let desk: String?
        let status: String?
        let statusNote: String?
        let runs: Int?
        let lastRun: String?
        let page: String?

        enum CodingKeys: String, CodingKey {
            case id, name, label, person, kind, desk, status, runs, page
            case statusNote = "status_note", lastRun = "last_run"
        }
        var lastRunDate: Date? { WireDate.parse(lastRun) }
    }

    struct Stage: Decodable, Identifiable, Sendable {
        let stage: String
        let label: String?
        let state: String?
        let desks: [String]?
        let lastRun: StageRun?
        enum CodingKeys: String, CodingKey { case stage, label, state, desks, lastRun = "last_run" }
        var id: String { stage }
    }

    struct StageRun: Decodable, Sendable {
        let id: String?
        let when: String?
        let what: String?
    }

    struct BuildStep: Decodable, Identifiable, Sendable {
        let step: Int
        let title: String?
        let due: String?
        let state: String?
        let note: String?
        var id: Int { step }
    }

    struct Waiting: Decodable, Hashable, Sendable {
        let what: String?
        let who: String?
        let issue: String?
        let unblocks: String?
    }

    struct Run: Decodable, Identifiable, Sendable {
        let id: String
        let when: String?
        let source: String?
        let kind: String?
        let by: String?
        let agent: String?
        let what: String?
        let release: String?
        let lines: Int?
        var date: Date? { WireDate.parse(when) }
    }
}

// MARK: - Newsroom: stories.json, decisions.json, desks.json

extension Wire {
    struct StoryBoard: Decodable, Sendable {
        let built: String?
        let columns: [Column]?
        let stories: [BoardStory]?
    }

    struct Column: Decodable, Identifiable, Hashable, Sendable {
        let id: String
        let name: String?
        let count: Int?
    }

    struct BoardStory: Decodable, Identifiable, Sendable {
        let id: String
        let title: String?
        let column: String?
        let beat: String?
        let desk: String?
        let assignee: String?
        let needs: LooseText?
        let next: String?
        let sources: Int?
        let page: String?

        var url: URL? { page.flatMap { URL(string: $0, relativeTo: FeedClient.site)?.absoluteURL } }
    }

    struct Decisions: Decodable, Sendable {
        let built: String?
        let decisions: [NewsroomDecision]?
    }

    struct NewsroomDecision: Decodable, Identifiable, Sendable {
        let title: String?
        let rel: String?
        let state: String?
        let askedBy: String?
        let askedOf: String?
        let since: String?
        let blocks: String?
        let answer: LooseText?
        let forDinis: Bool?

        enum CodingKeys: String, CodingKey {
            case title, rel, state, since, blocks, answer
            case askedBy = "asked_by", askedOf = "asked_of", forDinis = "for_dinis"
        }
        var id: String { rel ?? title ?? "" }
        var url: URL? { rel.flatMap { URL(string: $0, relativeTo: FeedClient.site)?.absoluteURL } }
        var isOpen: Bool { state == "open" }
    }

    struct Desks: Decodable, Sendable {
        let built: String?
        let runs: [DeskRun]?
        let funnel: [String: Int]?
        let candidates: [Candidate]?
        let gapsOpen: [Gap]?

        enum CodingKeys: String, CodingKey { case built, runs, funnel, candidates, gapsOpen = "gaps_open" }
    }

    struct DeskRun: Decodable, Identifiable, Sendable {
        let file: String?
        let at: String?
        let kind: String?
        let capturesNew: Int?
        let candidates: Int?
        let gaps: Int?
        let checks: Int?
        enum CodingKeys: String, CodingKey { case file, at, kind, candidates, gaps, checks, capturesNew = "captures_new" }
        var id: String { file ?? at ?? "" }
        var date: Date? { WireDate.parse(at) }
    }

    struct Candidate: Decodable, Identifiable, Sendable {
        let id: String
        let title: String?
        let beat: String?
        let seen: Int?
        let article: LooseText?
    }

    struct Gap: Decodable, Hashable, Sendable {
        let text: String?
        let first: String?
    }
}

// MARK: - News: newsletter.json

extension Wire {
    struct Newsletter: Decodable, Sendable {
        let editions: [Edition]?
    }

    struct Edition: Decodable, Identifiable, Sendable {
        let date: String?
        let edition: String?
        let title: String?
        let summary: String?
        let authored: Bool?
        let page: String?
        let email: String?

        var id: String { page ?? "\(date ?? "")-\(edition ?? "")" }
        var pageURL: URL? { page.flatMap(URL.init(string:)) }
        var emailURL: URL? { email.flatMap(URL.init(string:)) }
    }
}

