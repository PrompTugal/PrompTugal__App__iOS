import Foundation
import PTCore

/// Prepared questions over the team's data (brief item 4). Each adds the context it needs for that question only,
/// and the prompt and context show in the answer's "How this was asked" disclosure.
public struct AIStarter: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let prompt: String
    public let include: Set<AIContextKind>

    public init(id: String, title: String, symbol: String, prompt: String, include: Set<AIContextKind>) {
        self.id = id; self.title = title; self.symbol = symbol; self.prompt = prompt; self.include = include
    }

    @MainActor func run(_ store: ChatStore) {
        store.ask(prompt, showing: title, include: include)
    }
}

enum AIPrompts {
    static let briefMe = AIStarter(
        id: "brief", title: "Brief me: my next 3 hours", symbol: "text.badge.checkmark",
        prompt: """
        Brief me on my next 3 hours, from now. In this order, each as a short list:
        1. Sessions I picked that start in the next 3 hours (time, title, place). Then other sessions in that window worth a look, at most three, and why.
        2. Stand-ups in the window, and what I should bring.
        3. Decisions waiting on me, the most urgent first, with the recommendation when there is one.
        4. Anything overdue that only I can do.
        End with one line: the single most important thing to do next. If something is not in the context, say so instead of guessing.
        """,
        include: [.agenda, .picks, .team])

    static let planMyDay = AIStarter(
        id: "plan", title: "Plan my day", symbol: "list.bullet.clipboard",
        prompt: """
        Plan the rest of my day at the summit, from now, in Lisbon time. Use my picks first, then the day plan when there is one, then the agenda. Keep the stand-ups. Show it as a timeline: time, what, where. Point out clashes (two things at once) and say which one you would choose and why. Leave gaps for walking between venues (about 10 minutes) and one break. Then list the decisions I should take today.
        """,
        include: [.agenda, .picks, .team, .plan])

    static let myAgents = AIStarter(
        id: "agents", title: "What are my agents doing?", symbol: "cpu",
        prompt: """
        Summarise what my agents are doing. For each agent: what it did most recently and when, and whether it looks active, quiet or stuck (no commits in 24 hours). Then: the latest reports and messages in two or three lines, and anything that looks like it needs me. Be brief.
        """,
        include: [.team, .agents])

    static let whereToMeet = AIStarter(
        id: "meet", title: "Where should we meet today?", symbol: "person.2.wave.2",
        prompt: """
        Using where_is_everyone for today (and my picks), tell me: which sessions two or more of us are at, where and when we could meet in person (right after a shared session, or in a free window that keeps the 13:00 and 18:00 stand-ups free), and any clash in my own picks. If no teammate has shared a plan, say so and tell me how to link one (Where is everyone → Add key).
        """,
        include: [.picks, .teammates])

    static let starters: [AIStarter] = [briefMe, planMyDay, whereToMeet, myAgents]

    /// The prepared questions this app can answer: those whose context the app offers, then the app's own.
    @MainActor static func starters(for provider: any AskContextProvider) -> [AIStarter] {
        starters.filter { $0.include.isSubset(of: provider.supportedKinds) } + provider.extraStarters
    }
}
