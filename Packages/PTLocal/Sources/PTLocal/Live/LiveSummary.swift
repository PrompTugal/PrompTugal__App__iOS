import Foundation

/// The live screen's headline numbers, all read from the dashboard: how many agents showed a sign of life in the last
/// half hour, how many agent-hours fired in the last 24, the handoffs counted over the same day, and what waits on a
/// person.
public struct LiveSummary: Equatable, Sendable {
    public let agents: Int
    public let activeNow: Int
    public let firedHours24h: Int
    public let handoffs24h: Int
    public let asksWaiting: Int

    public static func make(_ dashboard: NewsroomDashboard, extras: LiveDashboardExtras?, now: Date,
                            window: TimeInterval = 30 * 60) -> LiveSummary {
        let active = dashboard.agents.filter { agent in
            guard let sign = agent.lastSign(now: now) else { return false }
            return now.timeIntervalSince(sign) < window
        }.count
        var fired = 0
        for agent in extras?.agents.values.map({ $0 }) ?? [] { fired += agent.fired.filter { $0 }.count }
        let handoffs = dashboard.handoffs.reduce(0) { $0 + $1.n }
        return LiveSummary(agents: dashboard.agents.count, activeNow: active, firedHours24h: fired,
                           handoffs24h: handoffs, asksWaiting: dashboard.asks.count)
    }
}
