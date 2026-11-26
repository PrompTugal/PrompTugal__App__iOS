import Foundation

/// Turns dashboards and place files into ticker lines: what the latest dashboard says each agent did last (`latest`),
/// and what changed between two successive reads (`changes`). Pure, so it is tested without a network.
public enum NewsroomDiff {
    /// The ticker before anything has been seen to change: each agent's last update and last wake, newest first.
    public static func latest(_ dashboard: NewsroomDashboard, now: Date, limit: Int = 40) -> [LiveEvent] {
        var out: [LiveEvent] = []
        for agent in dashboard.agents {
            if let date = LiveClock.clamp(agent.updatedDate, now: now) {
                out.append(LiveEvent(date: date, role: agent.role, kind: .update, text: updateLine(agent),
                                     detail: agent.state, origin: .latest))
            }
            if let wake = agent.lastWake, let date = LiveClock.clamp(NewsroomDate.parse(wake.started), now: now) {
                out.append(LiveEvent(date: date, role: agent.role, kind: .wake,
                                     text: LocalText.string("\(String(describing: agent.handle)) woke") + (wake.outcome.map { ": \($0)" } ?? ""),
                                     detail: wake.line, origin: .latest))
            }
        }
        return Array(out.sorted(by: newestFirst).prefix(limit))
    }

    /// What changed from `old` to `new`, newest first. `origin` says whether it was watched or happened while away.
    public static func changes(from old: NewsroomDashboard, to new: NewsroomDashboard, now: Date,
                               origin: LiveEvent.Origin = .watched) -> [LiveEvent] {
        var out: [LiveEvent] = []
        let before = Dictionary(old.agents.map { ($0.agent, $0) }, uniquingKeysWith: { a, _ in a })

        for agent in new.agents {
            let when = LiveClock.clamp(agent.updatedDate, now: now) ?? now
            guard let was = before[agent.agent] else {
                out.append(LiveEvent(date: when, role: agent.role, kind: .joined,
                                     text: LocalText.string("\(String(describing: agent.handle)) joined the newsroom"), detail: agent.focus, origin: origin))
                continue
            }
            let newDone = agent.done.filter { !was.done.contains($0) }
            if agent.updated != was.updated || agent.state != was.state {
                var text = updateLine(agent)
                if !newDone.isEmpty { text += LocalText.string(": \(String(describing: newDone.count)) new done") }
                out.append(LiveEvent(date: when, role: agent.role, kind: newDone.isEmpty ? .update : .done, text: text,
                                     detail: newDone.last ?? (agent.state != was.state ? agent.state : nil), origin: origin))
            }
            if let wake = agent.lastWake, wake.started != was.lastWake?.started {
                let date = LiveClock.clamp(NewsroomDate.parse(wake.started), now: now) ?? now
                out.append(LiveEvent(date: date, role: agent.role, kind: .wake,
                                     text: LocalText.string("\(String(describing: agent.handle)) woke") + (wake.outcome.map { ": \($0)" } ?? ""),
                                     detail: wake.line, origin: origin))
            }
            for ask in agent.asks where !was.asks.contains(ask) {
                out.append(LiveEvent(date: when, role: agent.role, kind: .ask, text: LocalText.string("\(String(describing: agent.handle)) asks a person"),
                                     detail: ask, origin: origin))
            }
        }

        let oldHandoffs = Dictionary(old.handoffs.map { ($0.id, $0.n) }, uniquingKeysWith: { Swift.max($0, $1) })
        for handoff in new.handoffs {
            let delta = handoff.n - (oldHandoffs[handoff.id] ?? 0)
            guard delta > 0 else { continue }
            out.append(LiveEvent(date: now, role: handoff.from, to: handoff.to, kind: .handoff,
                                 text: delta == 1 ? LocalText.string("\(handoff.from) → \(handoff.to): 1 new handoff") : LocalText.string("\(handoff.from) → \(handoff.to): \(String(describing: delta)) new handoffs"),
                                 origin: origin))
        }
        return out.sorted(by: newestFirst)
    }

    /// New stories, new map entries and sites going live, town by town, between two reads of the place files.
    public static func placeChanges(from old: [String: PlaceSite], to new: [String: PlaceSite], now: Date,
                                    origin: LiveEvent.Origin = .watched) -> [LiveEvent] {
        var out: [LiveEvent] = []
        for info in [PlaceDirectory.region] + PlaceDirectory.towns {
            guard let was = old[info.id], let site = new[info.id] else { continue }
            let role = "place.\(info.id)"
            let name = info.id == PlaceDirectory.region.id ? LocalText.string("the Algarve") : info.name
            let oldStories = Set(was.aiNews.map(\.url))
            let stories = site.aiNews.filter { !oldStories.contains($0.url) }
            if !stories.isEmpty {
                out.append(LiveEvent(date: now, role: role, kind: .stories,
                                     text: stories.count == 1 ? LocalText.string("\(role)@ updated \(name): 1 new story") : LocalText.string("\(role)@ updated \(name): \(String(describing: stories.count)) new stories"),
                                     detail: stories.first?.title, origin: origin))
            }
            let oldMap = Set(was.aiMap.map(\.name))
            let mapped = site.aiMap.filter { !oldMap.contains($0.name) }
            if !mapped.isEmpty {
                out.append(LiveEvent(date: now, role: role, kind: .mapped,
                                     text: LocalText.string("\(String(describing: role))@ mapped \(String(describing: mapped.count)) more in \(String(describing: name))"),
                                     detail: mapped.prefix(3).map(\.name).joined(separator: ", "), origin: origin))
            }
            if site.isLive && !was.isLive {
                out.append(LiveEvent(date: now, role: role, kind: .live, text: LocalText.string("\(String(describing: name))'s site went live"), origin: origin))
            }
        }
        return out
    }

    /// The roles a list of events touches, for the graph's pulses.
    public static func roles(in events: [LiveEvent]) -> Set<String> {
        var out = Set<String>()
        for event in events {
            out.insert(event.role)
            if let to = event.to { out.insert(to) }
        }
        return out
    }

    /// Adds `fresh` to the front of `existing`, each line once, capped.
    public static func merge(_ fresh: [LiveEvent], into existing: [LiveEvent], cap: Int = 80) -> [LiveEvent] {
        var seen = Set<String>()
        var out: [LiveEvent] = []
        for event in fresh + existing where seen.insert(event.id).inserted { out.append(event) }
        return Array(out.prefix(cap))
    }

    static func updateLine(_ agent: NewsroomDashboard.Agent) -> String {
        if let place = agent.placeName { return LocalText.string("\(String(describing: agent.handle)) updated \(String(describing: place))") }
        return "\(agent.handle) updated"
    }

    static func newestFirst(_ a: LiveEvent, _ b: LiveEvent) -> Bool {
        a.date != b.date ? a.date > b.date : a.id < b.id
    }
}
