import Foundation
import Testing
import PTCore
@testable import PTAsk

/// A provider that changes nothing from the defaults, to see what the protocol extension gives.
@MainActor
private final class DefaultTextProvider: AskContextProvider {
    var supportedKinds: Set<AIContextKind> { Set(AIContextKind.allCases) }
    var personName: String? { nil }
    func agenda() async -> [Event] { [] }
    func myPickIds() -> [String] { [] }
    func isPicked(_ event: Event) -> Bool { false }
    func togglePick(_ event: Event) {}
    func part(for kind: AIContextKind, now: Date) async -> AIContextPart? { nil }
    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)? { nil }
}

@Suite("Ask: providers")
@MainActor
struct ProviderTests {
    @Test("The public app's text says nothing about a team; the default keeps the Team app's text")
    func placeholderText() {
        let publicApp = PublicAskProvider()
        #expect(!publicApp.askPlaceholder.lowercased().contains("team"))
        #expect(!publicApp.askIntro.lowercased().contains("team"))
        let team = DefaultTextProvider()
        #expect(team.askPlaceholder == "Ask about today, your picks, the team…")
        #expect(team.askIntro == "Ask about the summit, your day and the team. Choose below what Ask may see.")
    }

    @Test("The public app's prompt says nothing about a team and its settings offer no vault copy")
    func publicAudience() throws {
        let publicApp = PublicAskProvider()
        #expect(!publicApp.offersVaultKeyCopy)
        let now = try #require(Lisbon.instant(day: "2026-11-10", clock: "08:00"))
        let prompt = AIContextAssembler.systemPrompt(parts: [], now: now, person: publicApp.personName,
                                                     audience: publicApp.askAudience, unknownPerson: publicApp.unknownPersonLine)
        #expect(!prompt.lowercased().contains("team"))
        #expect(!prompt.contains("Web Summit"), "no trademark in the public prompt")
        #expect(DefaultTextProvider().offersVaultKeyCopy)
    }

    @Test("The public provider offers the agenda, picks and page, and no team context or tools")
    func publicKinds() async {
        let provider = PublicAskProvider()
        #expect(provider.supportedKinds == [.agenda, .picks, .page])
        #expect(provider.personName == nil)
        for kind in [AIContextKind.team, .agents, .teammates, .plan] {
            #expect(await provider.part(for: kind, now: .now) == nil)
        }
        #expect(await provider.runTool("team_status", args: [:], now: .now) == nil)
    }

    @Test("Prepared questions: only those the app can answer, then the app's own")
    func starters() {
        let publicIDs = AIPrompts.starters(for: PublicAskProvider()).map(\.id)
        #expect(publicIDs == ["now-next", "my-picks-day"])
        let all = AIPrompts.starters(for: DefaultTextProvider()).map(\.id)
        #expect(all == ["brief", "plan", "meet", "agents"], "the Team app keeps all four, in the same order")
    }

    @Test("The toggles shown are the ones the app's provider supports")
    func togglesFollowTheProvider() {
        #expect(AIContextKind.toggleableHere == [.agenda, .picks, .page], "the default provider is the public one")
    }
}
