import Foundation

/// The team planner's day plan as text, for Ask ("plan my day"). `CollabHooks.dayPlan` uses it.
@MainActor
enum CollabTeamGlue {
    static func planText(_ plan: DayPlanner.Plan) -> String {
        var lines = ["Day plan for \(Lisbon.dayLabel(plan.day)) from the app's planner (Lisbon time):"]
        for item in plan.fixed {
            lines.append("- \(Lisbon.timeLabel(item.start))–\(Lisbon.timeLabel(item.end)) \(item.kind.rawValue): \(item.title) · \(item.place)")
        }
        for proposal in plan.proposals {
            lines.append("- suggested \(Lisbon.timeLabel(proposal.item.start))–\(Lisbon.timeLabel(proposal.item.end)): \(proposal.item.title) · \(proposal.item.place) (\(proposal.reasons.joined(separator: "; ")))")
        }
        for clash in plan.clashes {
            lines.append("- clash: \(clash.first.title) and \(clash.second.title) (\(clash.minutes) min\(clash.travel ? ", no time to walk" : ""))")
        }
        for gap in plan.gaps { lines.append("- free \(Lisbon.timeLabel(gap.start))–\(Lisbon.timeLabel(gap.end)) (\(gap.minutes) min)") }
        return lines.joined(separator: "\n")
    }
}
