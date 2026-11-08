import Foundation
import Testing
@testable import Team

// The stand-ups, read natively (team session). Fixtures are cut from web-summit.sgit.ai/meetings/ as served on
// 8 November 2026, reduced to the lines that matter.

private let meetingsIndex = """
# Stand-ups: the agenda, building through the day

## The stand-ups {#list}

| Stand-up | Open: decisions · questions · ideas · syncs | Decided |
|---|---|---|
| [2026-11-05 12:00](2026-11-05-1300/index.html) | 17 · 4 · 1 · 6 | 1 |
| [2026-11-08 12:00](2026-11-08-1200/index.html) **next** | 21 · 6 · 1 · 7 | 0 |
| [2026-11-02 13:00](2026-11-02-1300/index.html) | 4 · 1 · 0 · 0 | 0 |
"""

private let agendaPage = """
# Stand-up, 2026-11-08 12:00

The agenda for the 2026-11-08 12:00 stand-up.

## Agenda {#agenda}

### Decisions

- **Protect main on GitHub** *(carried over from 2026-11-02-1300)*. For: dinis. Added by conductor@web-summit.dinis. Any agent with push can push to main. Options: (1) protect main now; (2) leave it this week. *Recommended:* Protect main now; dev stays open for CI. [WS-90](../../briefs/index.html#issues)
- **Who sends the invitations** *(carried over from 2026-11-03-1300)*. For: dinis, angelo. Added by mentor@web-summit.dinis. Not decided. Options: (1) Dinis sends, as WS-09 says; (2) Angelo sends. *Recommended:* Whoever holds admin sends both.

### Questions

- **Which accounts do the videos go to?** *(carried over from 2026-11-02-1300)*. For: silvio. Added by conductor@web-summit.dinis. Linked to WS-126. [WS-71](../../briefs/index.html#issues)

### Ideas

- **A site per busy person** *(carried over from 2026-11-02-1800)*. For: dinis. Added by conductor@web-summit.dinis. Keep in the pocket.

### Quick syncs

- **Everyone adds their key**. For: everyone. Added by conductor@web-summit.dinis. Dinis has done it.

## The rules {#rules}

- Not a status round: what people did is in their briefing, read before.

## Everyone's briefing {#briefings}

- [Dinis Cruz](dinis/index.html): 31 items for them
- [Silvio](silvio/index.html): 12 items for them
"""

private func nativeTempDir(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("native-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("Stand-ups, native")
struct StandupNativeTests {
    @Test func theListGivesEachStandupItsOpenCounts() throws {
        let rows = TeamMarkdown.standupSummaries(meetingsIndex)
        #expect(rows.map(\.slot) == ["2026-11-02-1300", "2026-11-05-1300", "2026-11-08-1200"])   // by time
        let next = try #require(rows.last)
        #expect(next.isNext)
        #expect([next.decisions, next.questions, next.ideas, next.syncs, next.decided] == [21, 6, 1, 7, 0])
        #expect(next.openTotal == 35)
        #expect(rows.filter(\.isNext).count == 1)
        // the list's label wins over the folder name, as for TeamStandup
        #expect(rows[1].at == Lisbon.instant(day: "2026-11-05", clock: "12:00"))
        #expect(rows[1].decided == 1)
    }

    @Test func theAgendaIsReadItemByItem() throws {
        let agenda = TeamMarkdown.agenda(agendaPage, slot: "2026-11-08-1200")
        #expect(agenda.items(.decision).count == 2)
        #expect(agenda.items(.question).count == 1)
        #expect(agenda.items(.idea).count == 1)
        #expect(agenda.items(.sync).count == 1)
        #expect(agenda.items.count == 5)       // the rules' bullets are not items

        let first = try #require(agenda.items(.decision).first)
        #expect(first.title == "Protect main on GitHub")
        #expect(first.carriedFrom == "2026-11-02-1300")
        #expect(first.forWhom == ["dinis"])
        #expect(first.addedBy == "conductor@web-summit.dinis")
        #expect(first.detail == "Any agent with push can push to main.")
        #expect(first.options == ["protect main now", "leave it this week"])
        #expect(first.recommended == "Protect main now; dev stays open for CI.")
        #expect(first.issue == "WS-90")
        #expect(first.issueURL?.absoluteString == "https://web-summit.sgit.ai/briefs/index.html#issues")
    }

    @Test func partsThatAreMissingStayEmpty() throws {
        let agenda = TeamMarkdown.agenda(agendaPage, slot: "2026-11-08-1200")
        let second = try #require(agenda.items(.decision).last)
        #expect(second.forWhom == ["dinis", "angelo"])
        #expect(second.options == ["Dinis sends, as WS-09 says", "Angelo sends"])
        #expect(second.recommended == "Whoever holds admin sends both.")
        #expect(second.issue == nil && second.issueURL == nil)

        let question = try #require(agenda.items(.question).first)
        #expect(question.options.isEmpty && question.recommended.isEmpty)
        #expect(question.detail == "Linked to WS-126.")
        #expect(question.issue == "WS-71")

        let sync = try #require(agenda.items(.sync).first)       // no carried-over note, "." after the title
        #expect(sync.title == "Everyone adds their key")
        #expect(sync.carriedFrom == nil)
        #expect(sync.detail == "Dinis has done it.")
    }

    @Test func anItemIsForThePeopleItNamesOrForEveryone() throws {
        let agenda = TeamMarkdown.agenda(agendaPage, slot: "2026-11-08-1200")
        let decision = try #require(agenda.items(.decision).first)
        #expect(decision.isFor("dinis") && !decision.isFor("silvio"))
        let sync = try #require(agenda.items(.sync).first)
        #expect(sync.isFor("anyone"))
    }

    @Test func briefingsNameThePersonAndTheCount() {
        let agenda = TeamMarkdown.agenda(agendaPage, slot: "2026-11-08-1200")
        #expect(agenda.briefings.map(\.person) == ["dinis", "silvio"])
        #expect(agenda.briefings.map(\.items) == [31, 12])
        #expect(agenda.briefings.first?.name == "Dinis Cruz")
    }

    @Test func aPageThatIsNotAnAgendaGivesNothing() {
        let agenda = TeamMarkdown.agenda("<html>Not found</html>", slot: "2026-11-08-1200")
        #expect(agenda.items.isEmpty && agenda.briefings.isEmpty)
        #expect(TeamMarkdown.standupSummaries("nothing here").isEmpty)
    }

    @Test func onlyRealSlotsGoIntoAUrl() {
        #expect(TeamStore.isValidSlot("2026-11-08-1200"))
        #expect(!TeamStore.isValidSlot("../../etc/passwd"))
        #expect(!TeamStore.isValidSlot("2026-11-08-1200/../x"))
        #expect(!TeamStore.isValidSlot(""))
    }

    @MainActor
    @Test func theStoreFetchesAnAgendaKeepsItAndReadsItBack() async throws {
        let dir = try nativeTempDir("agenda")
        let requested = Requests()
        let fetch: TeamStore.Fetch = { url in
            await requested.add(url.absoluteString)
            return Data(agendaPage.utf8)
        }
        let store = TeamStore(directory: dir, fetch: fetch)
        #expect(store.agenda(for: "2026-11-08-1200") == nil)
        await store.refreshAgenda(slot: "2026-11-08-1200")
        #expect(store.agenda(for: "2026-11-08-1200")?.items.count == 5)
        #expect(await requested.all == ["https://web-summit.sgit.ai/meetings/2026-11-08-1200/index.md"])

        // a bad slot is never fetched
        await store.refreshAgenda(slot: "../secret")
        #expect(await requested.all.count == 1)

        // offline: a new store reads the kept copy
        let offline = TeamStore(directory: dir, fetch: { _ in throw URLError(.notConnectedToInternet) })
        #expect(offline.agenda(for: "2026-11-08-1200")?.items.count == 5)
        await offline.refreshAgenda(slot: "2026-11-08-1200")
        #expect(offline.agenda(for: "2026-11-08-1200")?.items.count == 5)       // a failed refresh keeps what it had
        #expect(offline.status["agenda.2026-11-08-1200"]?.failed == true)
    }

    @MainActor
    @Test func theMeetingsListFeedsTheSummaries() async throws {
        let fetch: TeamStore.Fetch = { url in
            guard url.path.hasSuffix("/meetings/index.md") else { throw URLError(.fileDoesNotExist) }
            return Data(meetingsIndex.utf8)
        }
        let store = TeamStore(directory: try nativeTempDir("summaries"), fetch: fetch)
        await store.refresh()
        #expect(store.standupSummaries.count == 3)
        #expect(store.standups.count == 3)
    }
}

private actor Requests {
    private(set) var all: [String] = []
    func add(_ url: String) { all.append(url) }
}
