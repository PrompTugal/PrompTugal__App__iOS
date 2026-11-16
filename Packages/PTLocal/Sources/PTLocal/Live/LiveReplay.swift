import Foundation

/// Replaying the last 24 hours from the dashboard's hour grid: where each agent fired, hour by hour. Real data: the
/// grid says only which hours an agent fired in, so the replay lights an agent for its hours and lets it fade after.
public enum LiveReplay {
    /// How lit an agent is at `position` (a fractional index into its hour grid): 1 inside an hour it fired, fading
    /// over the next `fade` hours, 0 when it was quiet.
    public static func activity(fired: [Bool], at position: Double, fade: Double = 1.5) -> Double {
        guard !fired.isEmpty, position >= 0 else { return 0 }
        let hour = Int(position)
        var best = 0.0
        for index in stride(from: min(hour, fired.count - 1), through: max(0, hour - Int(fade.rounded(.up))), by: -1)
            where fired[index] {
            let since = position - Double(index + 1)
            best = max(best, since <= 0 ? 1 : max(0, 1 - since / fade))
        }
        return best
    }

    /// How many agents fired in each hour of the grid: the replay's histogram.
    public static func perHour(_ extras: LiveDashboardExtras) -> [Int] {
        let width = extras.gridHours.count
        guard width > 0 else { return [] }
        var counts = Array(repeating: 0, count: width)
        for agent in extras.agents.values {
            for (i, on) in agent.fired.prefix(width).enumerated() where on { counts[i] += 1 }
        }
        return counts
    }
}
