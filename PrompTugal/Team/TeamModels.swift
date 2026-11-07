import Foundation

// Models for the team site's public data (contracts §6). The team session owns these; the design session builds the
// dashboards on them. Every field is read leniently: a missing or odd field becomes empty, never a failed screen.
// Field names follow the JSON, read from web-summit.sgit.ai v0.2.933 on 7 November 2026.

// MARK: - me.json  (https://web-summit.sgit.ai/me.json)

struct TeamMe: Decodable, Sendable {
    let builtAt: String
    let version: String
    let people: [TeamPerson]          // in the order of `TeamPerson.order`, then by name

    enum CodingKeys: String, CodingKey { case builtAt = "built_at", version, people }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        builtAt = c.string(.builtAt)
        version = c.string(.version)
        let byID = (try? c.decode([String: Lossy<TeamPerson>].self, forKey: .people)) ?? [:]
        people = byID.values.compactMap(\.value).sorted(by: TeamPerson.ordered)
    }

    func person(_ id: String) -> TeamPerson? { people.first { $0.id == id } }
}

struct TeamPerson: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let first: String
    let role: String
    let colour: String              // "#111111"
    let level: Int
    let levelName: String
    let onlyYou: Int
    let decide: Int
    let overdue: Int
    let open: Int
    let soon: Int
    let focus: Bool
    let standupAt: Date?            // the next stand-up, UTC
    let standup: String             // "2026-11-07 12:00"
    let briefing: String            // "meetings/2026-11-07-1200/dinis/index.html", relative to the site
    let urgent: [Urgent]
    let decisions: [Decision]
    let agents: [AgentStatus]
    let messages: [Message]
    let daily: [Int]                // commits per day, matching `days`
    let days: [String]
    let next: NextStep?
    let links: [String: String]     // dashboard, centre, brief, profile: paths relative to the site
    let sealed: [String]

    /// The app icon badge (brief 03): only you + decide + overdue.
    var badge: Int { onlyYou + decide + overdue }
    var centreURL: URL? { TeamEndpoints.url(links["centre"] ?? "people/\(id)/app/index.html") }
    var briefingURL: URL? { briefing.isEmpty ? nil : TeamEndpoints.url(briefing) }
    var dataURL: URL { TeamEndpoints.base.appendingPathComponent("people/\(id)/app/data.json") }
    var initials: String {
        name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased()
    }

    struct Urgent: Decodable, Hashable, Sendable {
        let id, title, due, status: String
        let late: Bool
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); title = c.string("title"); due = c.string("due"); status = c.string("status")
            late = c.bool("late")
        }
    }

    struct Decision: Decodable, Hashable, Sendable {
        let what, issue, source: String
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            what = c.string("what"); issue = c.string("issue"); source = c.string("source")
        }
    }

    struct AgentStatus: Decodable, Hashable, Sendable {
        let name, status, last: String
        let lastAt: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            name = c.string("name"); status = c.string("status"); last = c.string("last")
            lastAt = c.date("last_at")
        }
    }

    struct Message: Decodable, Hashable, Sendable {
        let from, subject: String
        let at: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            from = c.string("from"); subject = c.string("subject"); at = c.date("at")
        }
    }

    struct NextStep: Decodable, Hashable, Sendable {
        let step, how: String
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            step = c.string("step"); how = c.string("how")
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.string("id")
        guard !id.isEmpty else { throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "no id")) }
        name = c.string("name", default: id.capitalized)
        first = c.string("first", default: String(name.split(separator: " ").first ?? ""))
        role = c.string("role"); colour = c.string("colour", default: "#666666")
        level = c.int("level"); levelName = c.string("level_name")
        onlyYou = c.int("only_you"); decide = c.int("decide"); overdue = c.int("overdue")
        open = c.int("open"); soon = c.int("soon"); focus = c.bool("focus")
        standupAt = c.date("standup_at"); standup = c.string("standup"); briefing = c.string("briefing")
        urgent = c.lossy("urgent"); decisions = c.lossy("decisions"); agents = c.lossy("agents")
        messages = c.lossy("messages")
        daily = (try? c.decode([Int].self, forKey: AnyKey("daily"))) ?? []
        days = (try? c.decode([String].self, forKey: AnyKey("days"))) ?? []
        next = try? c.decodeIfPresent(NextStep.self, forKey: AnyKey("next"))
        links = (try? c.decode([String: String].self, forKey: AnyKey("links"))) ?? [:]
        sealed = (try? c.decode([String].self, forKey: AnyKey("sealed"))) ?? []
    }

    /// The team's own order (data.json `team`), so lists read the same as on the site.
    static let order = ["dinis", "silvio", "nimay", "angelo", "vicky", "daniela", "indi", "jose", "sarah"]

    static func ordered(_ lhs: TeamPerson, _ rhs: TeamPerson) -> Bool {
        let l = order.firstIndex(of: lhs.id) ?? Int.max, r = order.firstIndex(of: rhs.id) ?? Int.max
        return l != r ? l < r : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Command centre  (https://web-summit.sgit.ai/people/<id>/app/data.json)

struct CommandCentre: Decodable, Sendable {
    let builtAt: String
    let version: String
    let person: Person
    let summitOpening: Date?
    let summitLabel: String
    let standupTimesUTC: [String]       // ["13:00", "18:00"]; the meetings list is the source of truth for slots
    let workstreams: [Workstream]
    let decisions: [Decision]
    let issues: [Issue]
    let agents: [Agent]
    let activity: [Activity]
    let messages: [Activity]
    let sessions: [Session]             // event.sessions: the summit sessions picked for this person
    let team: [Member]
    let repo: String

    struct Person: Decodable, Hashable, Sendable {
        let id, name, role, status, photo: String
        let owns: [String]
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); name = c.string("name"); role = c.string("role"); status = c.string("status")
            photo = c.string("photo"); owns = (try? c.decode([String].self, forKey: AnyKey("owns"))) ?? []
        }
    }

    struct Workstream: Decodable, Identifiable, Hashable, Sendable {
        let id, name, colour, agent, with, goal: String
        let issues: [String]
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); name = c.string("name"); colour = c.string("colour"); agent = c.string("agent")
            with = c.string("with"); goal = c.string("goal")
            issues = (try? c.decode([String].self, forKey: AnyKey("issues"))) ?? []
        }
    }

    struct Decision: Decodable, Hashable, Sendable {
        let who, what, issue, source, recommend: String
        let since: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            who = c.string("who"); what = c.string("what"); issue = c.string("issue"); source = c.string("source")
            recommend = c.string("recommend"); since = c.date("since")
        }
    }

    struct Issue: Decodable, Identifiable, Hashable, Sendable {
        let id, title, area, due, status, pickedBy, doneForMe, agents, body, file: String
        let forWhom: [String]
        let dueAt: Date?
        let recurring, mine, named: Bool
        let stream: String?

        var isDone: Bool { ["done", "closed"].contains(status.lowercased()) || !doneForMe.isEmpty }
        var isLate: Bool { !isDone && (dueAt.map { $0 < .now } ?? false) }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); title = c.string("title"); area = c.string("area"); due = c.string("due")
            status = c.string("status"); pickedBy = c.string("picked_by"); doneForMe = c.string("done_for_me")
            agents = c.string("agents"); body = c.string("body"); file = c.string("file")
            forWhom = (try? c.decode([String].self, forKey: AnyKey("for"))) ?? []
            dueAt = c.date("due_at"); recurring = c.bool("recurring"); mine = c.bool("mine"); named = c.bool("named")
            stream = try? c.decodeIfPresent(String.self, forKey: AnyKey("stream"))
        }
    }

    struct Agent: Decodable, Identifiable, Hashable, Sendable {
        var id: String { name }
        let name, short, colour, job, schedule, status, lastSubject: String
        let commits24h, commits7d: Int
        let lastAt: Date?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            name = c.string("name"); short = c.string("short"); colour = c.string("colour"); job = c.string("job")
            schedule = c.string("schedule"); status = c.string("status"); lastSubject = c.string("last_subject")
            commits24h = c.int("commits_24h"); commits7d = c.int("commits_7d"); lastAt = c.date("last_at")
        }
    }

    /// A commit on the team repository (`activity` and `messages`).
    struct Activity: Decodable, Identifiable, Hashable, Sendable {
        var id: String { hash + subject }
        let hash, subject, agent: String
        let at: Date?
        let mine: Bool
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            hash = c.string("hash"); subject = c.string("subject"); agent = c.string("agent")
            at = c.date("at"); mine = c.bool("mine")
        }
    }

    struct Session: Decodable, Identifiable, Hashable, Sendable {
        let id, title, day, time, stage, track, whyRelevant, source: String
        let speakers: [Speaker]
        struct Speaker: Decodable, Hashable, Sendable {
            let name, org, title: String
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: AnyKey.self)
                name = c.string("name"); org = c.string("org"); title = c.string("title")
            }
        }
        /// "11:50-12:10 (Lisbon, WET = UTC+0)" → 11:50 on `day`, Lisbon time.
        var start: Date? { Lisbon.instant(day: day, clock: String(time.prefix(5))) }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); title = c.string("title"); day = c.string("day"); time = c.string("time")
            stage = c.string("stage"); track = c.string("track"); whyRelevant = c.string("why_relevant")
            source = c.string("source"); speakers = c.lossy("speakers")
        }
    }

    struct Member: Decodable, Identifiable, Hashable, Sendable {
        let id, name, photo: String
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            id = c.string("id"); name = c.string("name"); photo = c.string("photo")
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        builtAt = c.string("built_at"); version = c.string("version")
        person = try c.decode(Person.self, forKey: AnyKey("person"))
        let summit = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("summit"))
        summitOpening = summit?.date("opening"); summitLabel = summit?.string("label") ?? ""
        let standups = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("standups"))
        standupTimesUTC = (try? standups?.decode([String].self, forKey: AnyKey("times_utc"))) ?? []
        workstreams = c.lossy("workstreams"); decisions = c.lossy("decisions"); issues = c.lossy("issues")
        agents = c.lossy("agents"); activity = c.lossy("activity"); messages = c.lossy("messages")
        team = c.lossy("team"); repo = c.string("repo")
        let event = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("event"))
        sessions = event?.lossy("sessions") ?? []
    }

    /// Issues for this person that are not done, late first, then by due time.
    var openIssues: [Issue] {
        issues.filter { !$0.isDone && ($0.mine || $0.named) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }
}

// MARK: - Stand-ups  (https://web-summit.sgit.ai/meetings/index.md and /meetings/<slot>/<person>/)

struct TeamStandup: Identifiable, Hashable, Sendable {
    let slot: String                // "2026-11-07-1200"
    let at: Date                    // Lisbon time (UTC in November)
    var id: String { slot }
    var url: URL { TeamEndpoints.base.appendingPathComponent("meetings/\(slot)/index.html") }
    func briefingURL(for person: String) -> URL {
        TeamEndpoints.base.appendingPathComponent("meetings/\(slot)/\(person)/index.html")
    }
    /// The stand-ups last about 30 minutes; the site does not say.
    var end: Date { at.addingTimeInterval(30 * 60) }

    /// - Parameters:
    ///   - slot: the folder name, "2026-11-05-1300".
    ///   - label: the list's link text, "2026-11-05 12:00". It wins over the slot: the team moved the
    ///     13:00 stand-up to 12:00 on 5 November and kept some folder names.
    init?(slot: String, label: String? = nil) {
        let parts = slot.split(separator: "-")
        guard parts.count == 4, parts[3].count == 4 else { return nil }
        let fromSlot = Lisbon.instant(day: parts[0...2].joined(separator: "-"),
                                      clock: "\(parts[3].prefix(2)):\(parts[3].suffix(2))")
        let labelParts = (label ?? "").split(separator: " ")
        let fromLabel = labelParts.count == 2 ? Lisbon.instant(day: String(labelParts[0]), clock: String(labelParts[1])) : nil
        guard let at = fromLabel ?? fromSlot else { return nil }
        self.slot = slot
        self.at = at
    }
}

// MARK: - Agents: wakes, reports, pulse, log
// These pages publish no JSON; each has a markdown twin (`index.md`) that the app reads.

/// /wakes/index.md: per agent, its schedule and its wakes, newest first.
struct AgentWakes: Identifiable, Hashable, Sendable {
    var id: String { agent }
    let agent: String               // "conductor@web-summit.dinis"
    let schedule: String            // "every 2 hours at :27 (cron 27 */2 * * *)"
    let wakes: [Wake]

    struct Wake: Hashable, Sendable {
        let at: Date?
        let text: String            // "v0.2.893: 22:27 wake: brief 31 (…)"
        let link: URL?              // the commit
    }

    var owner: String { agent.split(separator: ".").last.map(String.init) ?? "" }
    var lastWake: Date? { wakes.compactMap(\.at).max() }
}

/// /reports/index.md: the reports every two hours and the newsletters.
struct TeamReport: Identifiable, Hashable, Sendable {
    var id: String { path }
    let title: String               // "What happened: Saturday 7 November, 00:57"
    let path: String                // "2026-11-07-0057/index.html", relative to /reports/
    let summary: String
    var url: URL { TeamEndpoints.base.appendingPathComponent("reports/\(path)") }
    var isNewsletter: Bool { path.contains("newsletter") }
}

/// /pulse/index.md: the team's check-ins.
struct PulseEntry: Identifiable, Hashable, Sendable {
    var id: String { who + "|" + slot }
    let who: String                 // "Vicky Wang"
    let slot: String                // "2026-11-03-morning"
    let body: String                // markdown
    var day: String { String(slot.prefix(10)) }
    var part: String { String(slot.dropFirst(11)) }   // morning, midday, evening
}

/// /log/index.md: every wake of the team, opened and closed by the conductor.
struct SessionLogEntry: Identifiable, Hashable, Sendable {
    var id: String { (at.map(ScheduleTime.format) ?? "") + title }
    let at: Date?
    let title: String
    let summary: String             // "Roles run: conductor. Outcome: ok. Release: v0.1.24."
    let lines: [String]
}

// MARK: - The site

enum TeamEndpoints {
    static let base = URL(string: "https://web-summit.sgit.ai/")!
    static let me = base.appendingPathComponent("me.json")
    static let meetings = base.appendingPathComponent("meetings/index.md")
    static let wakes = base.appendingPathComponent("wakes/index.md")
    static let reports = base.appendingPathComponent("reports/index.md")
    static let pulse = base.appendingPathComponent("pulse/index.md")
    static let log = base.appendingPathComponent("log/index.md")

    static func url(_ path: String) -> URL? {
        URL(string: path.hasPrefix("/") ? String(path.dropFirst()) : path, relativeTo: base)?.absoluteURL
    }
}

// MARK: - Lenient decoding

struct AnyKey: CodingKey, Hashable {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Counts from JSON as Int without trapping: not finite → 0; beyond ±1,000,000,000 → clamped.
enum TeamNumbers {
    static let limit = 1_000_000_000.0
    static func int(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(value, -limit), limit).rounded(.towardZero))
    }
}

/// One element that may fail to decode without failing its array.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

extension KeyedDecodingContainer {
    func string(_ key: Key, default fallback: String = "") -> String {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let n = try? decodeIfPresent(Double.self, forKey: key) { return n.formatted() }
        return fallback
    }
}

extension KeyedDecodingContainer where Key == AnyKey {
    func string(_ key: String, default fallback: String = "") -> String { string(AnyKey(key), default: fallback) }
    func int(_ key: String) -> Int {
        if let value = try? decodeIfPresent(Int.self, forKey: AnyKey(key)) { return value }
        guard let value = try? decodeIfPresent(Double.self, forKey: AnyKey(key)) else { return 0 }
        return TeamNumbers.int(value)
    }
    func bool(_ key: String) -> Bool { ((try? decodeIfPresent(Bool.self, forKey: AnyKey(key))) ?? nil) ?? false }
    func date(_ key: String) -> Date? {
        guard let text = (try? decodeIfPresent(String.self, forKey: AnyKey(key))) ?? nil else { return nil }
        return ScheduleTime.parse(text)
    }
    func lossy<T: Decodable>(_ key: String) -> [T] {
        ((try? decodeIfPresent([Lossy<T>].self, forKey: AnyKey(key))) ?? nil)?.compactMap(\.value) ?? []
    }
}
