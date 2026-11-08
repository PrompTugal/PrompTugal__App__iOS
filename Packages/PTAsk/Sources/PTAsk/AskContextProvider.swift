import Foundation
import PTCore

/// What Ask needs from the app around it. PTAsk names no team type: each app supplies a provider at launch
/// (`AskEnvironment.provider`). The public app uses `PublicAskProvider`, the default. The Team app installs
/// `TeamAskProvider`, which adds the team, agents, teammates and plan context and their tools.
@MainActor
public protocol AskContextProvider: AnyObject {
    /// The kinds this app offers. A kind that is not here is not shown, not gathered and its tools are not offered.
    var supportedKinds: Set<AIContextKind> { get }
    /// Who Ask is talking to, for the system prompt. Nil: not known (the public app).
    var personName: String? { get }
    /// The summit agenda.
    func agenda() async -> [Event]
    /// My picks as bare event slugs.
    func myPickIds() -> [String]
    /// Whether a session named in an answer is picked, and a way to pick or unpick it. One pick list: the schedule.
    func isPicked(_ event: Event) -> Bool
    func togglePick(_ event: Event)
    /// A part for `.team`, `.agents`, `.teammates` or `.plan`. Nil when the app has none.
    func part(for kind: AIContextKind, now: Date) async -> AIContextPart?
    /// Runs a tool the provider owns (`team_status`, `my_agents`, `where_is_everyone`). Nil when it is not one of its tools.
    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)?
    /// Prepared questions only this app offers.
    var extraStarters: [AIStarter] { get }
    /// The line above the prepared questions, and the hint in the empty question box. They name only what this app can see.
    var askIntro: String { get }
    var askPlaceholder: String { get }
    /// Who Ask is for, in the system prompt ("used by …"), and how it names a person it does not know.
    var askAudience: String { get }
    var unknownPersonLine: String { get }
    /// Whether Ask settings offer to copy the key to and from a vault. Off where the app has no vault.
    var offersVaultKeyCopy: Bool { get }
}

public extension AskContextProvider {
    var extraStarters: [AIStarter] { [] }
    /// The Team app's text (what the app said before there was a public app).
    var askIntro: String { "Ask about the summit, your day and the team. Choose below what Ask may see." }
    var askPlaceholder: String { "Ask about today, your picks, the team…" }
    var askAudience: String { "the PrompTugal team" }
    var unknownPersonLine: String { "You do not know which team member you are talking to." }
    var offersVaultKeyCopy: Bool { true }
}

/// The provider Ask uses. Set once at launch; the default needs no wiring.
public enum AskEnvironment {
    @MainActor public static var provider: any AskContextProvider = PublicAskProvider()
}
