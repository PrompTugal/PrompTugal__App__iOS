import Foundation
import PTAgenda
import PTAsk
import PTCore
import PTNews

/// The Team app's side of Ask (contracts §7): the team, agents, teammates and plan context and their tools,
/// on top of what every app offers (agenda, picks, page). PTAsk names none of the team types used here.
@MainActor
final class TeamAskProvider: AskContextProvider {
    /// Sets the provider PTAsk uses. Called once at launch: from `TeamLanesWiring.install()` for now, from the Team entry point later.
    static func install() { AskEnvironment.provider = TeamAskProvider() }

    var supportedKinds: Set<AIContextKind> { Set(AIContextKind.allCases) }
    var personName: String? { CollabHooks.me()?.name }

    func agenda() async -> [Event] { await CollabHooks.agenda() }
    func myPickIds() -> [String] { CollabHooks.myPickIds() }
    func isPicked(_ event: Event) -> Bool { TeamFeatures.shared.schedule.isPicked(event) }
    func togglePick(_ event: Event) { TeamFeatures.shared.schedule.toggle(event) }

    func part(for kind: AIContextKind, now: Date) async -> AIContextPart? {
        switch kind {
        case .team: await teamPart()
        case .agents: await agentsPart()
        case .teammates:
            let store = CoordinationStore.shared
            if store.plans.isEmpty { await store.load() }
            let day = Lisbon.day(now)
            return AIContextPart(kind: .teammates, summary: "\(max(store.plans.count - 1, 0)) teammates' plans",
                                 body: store.plans.count > 1 ? store.summary(for: day) : "",
                                 source: "plans shared through vaults")
        case .plan:
            guard let plan = await CollabHooks.dayPlan?() else { return nil }
            return AIContextPart(kind: .plan, summary: "Planner", body: plan, source: "the app's day planner")
        default: nil
        }
    }

    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)? {
        switch name {
        case "team_status":
            let part = await teamPart()
            return (part.body.isEmpty ? part.summary : part.body, part.summary)
        case "my_agents":
            let part = await agentsPart()
            return (part.body.isEmpty ? part.summary : part.body, part.summary)
        case "where_is_everyone":
            let store = CoordinationStore.shared
            if store.plans.isEmpty { await store.load() }
            let day = args["day"] ?? Lisbon.day(now)
            return (store.summary(for: day), "\(store.plans.count) plans")
        default:
            return nil
        }
    }

    private func teamPart() async -> AIContextPart {
        guard let me = CollabHooks.me() else {
            return AIContextPart(kind: .team, summary: "Choose who you are in Settings", body: "", source: "web-summit.sgit.ai")
        }
        let (person, centre) = await teamData(person: me.id)
        return TeamAskContext.teamPart(person: me.id, me: person, centre: centre)
    }

    private func agentsPart() async -> AIContextPart {
        guard let me = CollabHooks.me() else {
            return AIContextPart(kind: .agents, summary: "Choose who you are in Settings", body: "", source: "web-summit.sgit.ai")
        }
        let (_, centre) = await teamData(person: me.id)
        return TeamAskContext.agentsPart(person: me.id, centre: centre)
    }

    /// My entry and my command centre from the team session's store, refreshed when missing.
    private func teamData(person: String) async -> (TeamPerson?, CommandCentre?) {
        let team = TeamFeatures.shared.team
        if team.me?.person(person) == nil {
            await team.refresh(person: person)
        } else if team.centre(for: person) == nil {
            await team.refreshCentre(for: person)
        }
        return (team.me?.person(person), team.centre(for: person))
    }
}

/// Pure text builders over `TeamPerson` (me.json) and `CommandCentre` (my data.json): one set of team models in the app (Q8).
enum TeamAskContext {
    /// From the team session's models (`TeamPerson` from me.json, `CommandCentre` from my data.json): one set of
    /// team models in the app (Q8).
    static func teamPart(person: String, me: TeamPerson?, centre: CommandCentre?) -> AIContextPart {
        var lines: [String] = []
        var counts: [String] = []
        if let me {
            lines.append("Team member: \(me.name) (\(person))\(me.role.isEmpty ? "" : ", \(me.role)")")
            for (n, label) in [(me.onlyYou, "only you"), (me.decide, "to decide"), (me.overdue, "overdue"),
                               (me.soon, "due soon"), (me.open, "open")] {
                counts.append("\(n) \(label)")
            }
            lines.append("Counts: " + counts.joined(separator: ", "))
            if let standup = me.standupAt { lines.append("Next stand-up: \(lisbonTime(standup))") }
            if !me.urgent.isEmpty {
                lines.append("Urgent items:")
                for item in me.urgent.prefix(10) {
                    lines.append("- \(item.id) \(item.title) (due \(item.due.isEmpty ? "?" : item.due)\(item.late ? ", late" : ""))")
                }
            }
        }
        if let centre {
            if !centre.standupTimesUTC.isEmpty {
                lines.append("Stand-ups every day at \(centre.standupTimesUTC.joined(separator: " and ")) Lisbon time.")
            }
            if !centre.decisions.isEmpty {
                lines.append("Decisions waiting on me (\(centre.decisions.count)):")
                for item in centre.decisions.prefix(12) {
                    lines.append("- \(item.what)\(item.recommend.isEmpty ? "" : " (recommended: \(item.recommend))")")
                }
            }
            if !centre.agents.isEmpty {
                lines.append("My agents (\(centre.agents.count)):")
                for agent in centre.agents.prefix(12) {
                    let last = agent.lastAt.map(lisbonTime) ?? "?"
                    lines.append("- \(agent.short.isEmpty ? agent.name : agent.short): \(agent.commits24h) commits in 24 h, last \(last): \(agent.lastSubject)")
                }
            }
            if !centre.messages.isEmpty {
                lines.append("Latest reports and messages:")
                for item in centre.messages.prefix(8) {
                    lines.append("- \(item.at.map(lisbonTime) ?? "") \(item.subject)")
                }
            }
        }
        let summary = counts.isEmpty ? (lines.isEmpty ? "No team data" : "Team data for \(person)") : counts.prefix(3).joined(separator: " · ")
        return AIContextPart(kind: .team, summary: summary, body: lines.joined(separator: "\n"),
                             source: "web-summit.sgit.ai me.json and people/\(person)/app/data.json")
    }

    /// My agents in detail, and the team's latest commits with mine marked.
    static func agentsPart(person: String, centre: CommandCentre?) -> AIContextPart {
        guard let centre else {
            return AIContextPart(kind: .agents, summary: "No data", body: "", source: "web-summit.sgit.ai")
        }
        var lines = ["My agents (\(centre.agents.count)):"]
        for agent in centre.agents {
            let last = agent.lastAt.map(lisbonTime) ?? "never"
            var line = "- \(agent.name) [\(agent.status.isEmpty ? "?" : agent.status)]: \(agent.commits24h) commits in 24 h, \(agent.commits7d) in 7 days; last at \(last): \(agent.lastSubject)"
            if !agent.job.isEmpty { line += " · job: \(agent.job)" }
            if !agent.schedule.isEmpty { line += " · schedule: \(agent.schedule)" }
            lines.append(line)
        }
        if !centre.messages.isEmpty {
            lines.append("Their latest reports and messages:")
            for item in centre.messages.prefix(12) { lines.append("- \(item.at.map(lisbonTime) ?? "") \(item.subject)") }
        }
        if !centre.activity.isEmpty {
            lines.append("Latest team activity (mine marked *):")
            for item in centre.activity.prefix(25) {
                lines.append("- \(item.mine ? "* " : "")\(item.at.map(lisbonTime) ?? "") \(item.subject)")
            }
        }
        let active = centre.agents.filter { $0.commits24h > 0 }.count
        return AIContextPart(kind: .agents, summary: "\(centre.agents.count) agents, \(active) active in 24 h",
                             body: lines.joined(separator: "\n"), source: "web-summit.sgit.ai people/\(person)/app/data.json")
    }

    static func lisbonTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = Lisbon.zone
        formatter.dateFormat = "EEE d MMM HH:mm"
        return formatter.string(from: date)
    }
}
