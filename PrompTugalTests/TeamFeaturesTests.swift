import Foundation
import Testing
@testable import PrompTugal

// Team data parsers, reminders and the day planner (team session). Fixtures are cut from the live sites' output
// of 7 November 2026, reduced to the lines that matter.

private func lisbon(_ day: String, _ clock: String) -> Date { Lisbon.instant(day: day, clock: clock)! }
private func event(_ slug: String, _ time: String, day: String = "2026-11-10", place: String = "Centre Stage",
                   official: Bool = true) -> Event {
    Event(date: day, time: time, title: slug.replacingOccurrences(of: "-", with: " "), place: place, kind: "session",
          official: official, page: "events/\(slug)/index.html")
}
private func pick(_ e: Event) -> SchedulePick {
    SchedulePick(id: ScheduleID.fromPage(e.page)!, at: .distantPast, event: e)
}

@Suite("Team site markdown")
struct TeamMarkdownTests {
    @Test func standupsUseTheLabelNotTheFolder() throws {
        let md = """
        | Stand-up | Open | Decided |
        |---|---|---|
        | [2026-11-04 18:00](2026-11-04-1800/index.html) | 15 · 4 · 1 · 4 | 0 |
        | [2026-11-05 12:00](2026-11-05-1300/index.html) | 17 · 4 · 1 · 6 | 1 |
        | [2026-11-07 12:00](2026-11-07-1200/index.html) **next** | 22 · 5 · 1 · 7 | 0 |
        """
        let standups = TeamMarkdown.standups(md)
        #expect(standups.map(\.slot) == ["2026-11-04-1800", "2026-11-05-1300", "2026-11-07-1200"])
        #expect(standups[1].at == lisbon("2026-11-05", "12:00"))
        // negative control: without the label, the folder name gives the wrong hour
        #expect(TeamStandup(slot: "2026-11-05-1300")?.at == lisbon("2026-11-05", "13:00"))
        #expect(standups[2].briefingURL(for: "silvio").absoluteString
                == "https://web-summit.sgit.ai/meetings/2026-11-07-1200/silvio/index.html")
    }

    @Test func wakes() throws {
        let md = """
        # The agents at work

        ## conductor@web-summit.dinis

        every 2 hours at :27 (cron 27 */2 * * *)

        - 2026-11-07T00:56Z not released yet
        - 2026-11-06T22:29Z v0.2.893: 22:27 wake: brief 31 (a quiet evening) (https://github.com/SGit-AI/x/commit/9b973a8)

        ## pulse@web-summit.dinis

        08:40, 13:10 and 19:40
        """
        let agents = TeamMarkdown.wakes(md)
        #expect(agents.map(\.agent) == ["conductor@web-summit.dinis", "pulse@web-summit.dinis"])
        let conductor = agents[0]
        #expect(conductor.schedule == "every 2 hours at :27 (cron 27 */2 * * *)")
        #expect(conductor.wakes.count == 2)
        #expect(conductor.wakes[0].text == "not released yet")
        #expect(conductor.wakes[1].text == "v0.2.893: 22:27 wake: brief 31 (a quiet evening)")
        #expect(conductor.wakes[1].link?.absoluteString == "https://github.com/SGit-AI/x/commit/9b973a8")
        #expect(conductor.wakes[1].at == ScheduleTime.parse("2026-11-06T22:29:00Z"))
        #expect(conductor.owner == "dinis")
        #expect(agents[1].wakes.isEmpty)
    }

    @Test func reportsPulseAndLog() {
        let reports = TeamMarkdown.reports("""
        - [What happened: Saturday 7 November, 00:57](2026-11-07-0057/index.html): v0.2.899 to v0.2.922: the home page
        - [The newsletter: Friday 6 November](2026-11-06-newsletter/index.html): The day in five lines.
        """)
        #expect(reports.count == 2)
        #expect(reports[0].summary == "v0.2.899 to v0.2.922: the home page")
        #expect(reports[1].isNewsletter)

        let pulse = TeamMarkdown.pulse("""
        # The pulse

        ### Vicky Wang, 2026-11-03-morning

        **1. Where we are.** Onboarding works.

        ### Jose Bota, 2026-11-03-evening

        Fine.
        """)
        #expect(pulse.map(\.who) == ["Vicky Wang", "Jose Bota"])
        #expect(pulse[0].part == "morning")
        #expect(pulse[0].body == "**1. Where we are.** Onboarding works.")

        let log = TeamMarkdown.log("""
        ## 2026-11-01T18:38:00Z: Join as conductor.3, record brief 3

        Roles run: conductor. Outcome: ok. Release: v0.1.24.

        - joined as conductor.3@web-summit
        - brief 3 recorded
        """)
        #expect(log.count == 1)
        #expect(log[0].title == "Join as conductor.3, record brief 3")
        #expect(log[0].at == ScheduleTime.parse("2026-11-01T18:38:00Z"))
        #expect(log[0].summary == "Roles run: conductor. Outcome: ok. Release: v0.1.24.")
        #expect(log[0].lines.count == 2)
    }
}

@Suite("Team JSON")
struct TeamJSONTests {
    @Test func meJSONIsLenient() throws {
        let json = #"""
        {"built_at":"2026-11-07T02:38:21.515Z","version":"v0.2.933","people":{
          "silvio":{"id":"silvio","name":"Silvio Switha","only_you":2,"decide":3,"overdue":1,"colour":"#AA3300",
                    "standup_at":"2026-11-07T12:00:00.000Z","urgent":[{"id":"WS-1","title":"T","due":"Mon","status":"open","late":true},{"oops":1}],
                    "agents":[{"name":"conductor@web-summit.silvio","status":"active","last_at":null,"last":""}],
                    "links":{"centre":"people/silvio/app/index.html"}},
          "dinis":{"id":"dinis","name":"Dinis Cruz","only_you":"four"},
          "broken":{"name":"No id"}}}
        """#
        let me = try JSONDecoder().decode(TeamMe.self, from: Data(json.utf8))
        #expect(me.people.map(\.id) == ["dinis", "silvio"])     // team order; the person with no id is dropped
        let silvio = try #require(me.person("silvio"))
        #expect(silvio.badge == 6)
        #expect(silvio.urgent.count == 2)                          // the odd entry decodes empty, not a failure
        #expect(silvio.urgent[0].late)
        #expect(silvio.agents[0].lastAt == nil)
        #expect(silvio.centreURL?.absoluteString == "https://web-summit.sgit.ai/people/silvio/app/index.html")
        #expect(me.person("dinis")?.onlyYou == 0)                  // a string where a number was expected
    }

    @Test func commandCentre() throws {
        let json = #"""
        {"built_at":"x","version":"v1","person":{"id":"silvio","name":"Silvio Switha","owns":["a"]},
         "summit":{"opening":"2026-11-09T18:00:00Z"},"standups":{"times_utc":["13:00","18:00"]},
         "issues":[{"id":"WS-62","title":"Vote","mine":true,"status":"open","due_at":"2026-11-02T16:00:00.000Z"},
                   {"id":"WS-63","title":"Done","mine":true,"status":"done"}],
         "event":{"sessions":[{"id":"ws26-s01","title":"The agentic internet","day":"2026-11-10","time":"11:50-12:10 (Lisbon, WET = UTC+0)"}]}}
        """#
        let centre = try JSONDecoder().decode(CommandCentre.self, from: Data(json.utf8))
        #expect(centre.person.id == "silvio")
        #expect(centre.standupTimesUTC == ["13:00", "18:00"])
        #expect(centre.openIssues.map(\.id) == ["WS-62"])
        #expect(centre.sessions[0].start == lisbon("2026-11-10", "11:50"))
    }
}

@Suite("Reminders")
struct ReminderPlanTests {
    let now = Lisbon.instant(day: "2026-11-10", clock: "10:00")!

    @Test func tenMinutesBeforeInLisbon() throws {
        let items = ReminderPlan.items(picks: [pick(event("ai-doom-or-boom", "16:20-16:40"))], standups: [],
                                       person: nil, leadMinutes: 10, now: now)
        let item = try #require(items.first)
        #expect(item.fire == lisbon("2026-11-10", "16:10"))
        #expect(item.id == "pt.pick.ai-doom-or-boom")
        let parts = ReminderPlan.components(item.fire)
        #expect(parts.hour == 16 && parts.minute == 10 && parts.timeZone == Lisbon.zone)
    }

    @Test func pastAndTooLateAreSkipped() {
        let items = ReminderPlan.items(picks: [pick(event("past", "09:00-09:30")), pick(event("soon", "10:05-10:30")),
                                               pick(event("later", "11:00-11:30"))],
                                       standups: [], person: nil, leadMinutes: 10, now: now)
        #expect(items.map(\.id) == ["pt.pick.later"])
        // control: with no lead time, the one starting at 10:05 is kept
        let atStart = ReminderPlan.items(picks: [pick(event("soon", "10:05-10:30"))], standups: [], person: nil,
                                         leadMinutes: 0, now: now)
        #expect(atStart.count == 1)
    }

    @Test func standupsNeedAPerson() {
        let standup = TeamStandup(slot: "2026-11-10-1200")!
        #expect(ReminderPlan.items(picks: [], standups: [standup], person: nil, leadMinutes: 10, now: now).isEmpty)
        let mine = ReminderPlan.items(picks: [], standups: [standup], person: "silvio", leadMinutes: 10, now: now)
        #expect(mine.first?.url?.absoluteString == "https://web-summit.sgit.ai/meetings/2026-11-10-1200/silvio/index.html")
    }

    @Test func neverMoreThanTheLimit() {
        let picks = (0..<100).map { i in
            pick(event("s\(i)", String(format: "%02d:%02d-%02d:%02d", 11 + i / 60, i % 60, 11 + i / 60, i % 60)))
        }
        let items = ReminderPlan.items(picks: picks, standups: [], person: nil, leadMinutes: 10, now: now)
        #expect(items.count == 60)
        #expect(items.first?.id == "pt.pick.s0")              // the soonest are kept
    }
}

@Suite("Day planner")
struct DayPlannerTests {
    let day = "2026-11-10"

    @Test func clashesAndTravel() {
        let picks = [pick(event("a", "10:00-11:00")), pick(event("b", "10:30-11:30")),
                     pick(event("c", "11:35-12:00", place: "Rua das Portas de Santo Antão"))]
        let plan = DayPlanner.plan(day: day, agenda: [], picks: picks, standups: [])
        #expect(plan.clashes.count == 2)
        #expect(plan.clashes[0].minutes == 30 && !plan.clashes[0].travel)
        #expect(plan.clashes[1].travel)                        // 5 minutes to get across town is not enough
        // negative control: the same rooms with time to walk are not a clash
        let ok = DayPlanner.plan(day: day, agenda: [], picks: [pick(event("a", "10:00-11:00")),
                                                               pick(event("d", "11:05-11:30", place: "Stage 2"))],
                                 standups: [])
        #expect(ok.clashes.isEmpty)
    }

    @Test func gapsAndProposalsFitWithWalkingTime() {
        let picks = [pick(event("morning", "09:00-10:00")), pick(event("noon", "12:00-13:00"))]
        let agenda = [event("fits", "10:10-10:50", place: "Stage 2"),
                      event("too-tight", "10:01-10:40", place: "Stage 2"),        // no time to walk in
                      event("offsite", "10:30-11:40", place: "A bar in Alfama"),   // 25 min walk back: ends too late
                      event("other-day", "10:10-10:50", day: "2026-11-11")]
        let plan = DayPlanner.plan(day: day, agenda: agenda + picks.compactMap(\.event), picks: picks, standups: [])
        #expect(plan.gaps.first?.start == lisbon(day, "10:00"))
        #expect(plan.gaps.first?.end == lisbon(day, "12:00"))
        let first = plan.proposals.filter { $0.item.start < lisbon(day, "12:00") }.map { $0.item.eventID }
        #expect(first == ["fits"])
    }

    @Test func teamPicksRankFirst() {
        var prefs = DayPlanner.Preferences()
        prefs.suggested = ["b": "Picked for you by the team"]
        prefs.teammates = ["c": ["Vicky"]]
        let agenda = [event("a", "14:00-14:30", place: "Stage 2"), event("b", "14:00-14:30", place: "Stage 3"),
                      event("c", "14:00-14:30", place: "Stage 4")]
        let plan = DayPlanner.plan(day: day, agenda: agenda, picks: [], standups: [], preferences: prefs)
        let at2 = plan.proposals.filter { $0.item.start == lisbon(day, "14:00") }
        #expect(at2.first?.item.eventID == "b")
        #expect(plan.alternatives["proposal.b"]?.map(\.item.eventID) == ["c", "a"])
    }

    @Test func standupsAreFixed() {
        let plan = DayPlanner.plan(day: day, agenda: [], picks: [], standups: [TeamStandup(slot: "2026-11-10-1200")!])
        #expect(plan.fixed.map(\.kind) == [.standup])
        #expect(plan.gaps.count == 2)
    }
}

@Suite("Site data stores")
struct SiteDataStoreTests {
    @Test func identifiersAreStablePerHost() {
        #expect(SiteDataStores.identifier(for: "web-summit.sgit.ai") == SiteDataStores.identifier(for: "WEB-SUMMIT.sgit.ai"))
        #expect(SiteDataStores.identifier(for: "web-summit.sgit.ai") != SiteDataStores.identifier(for: "newsroom.sgit.ai"))
    }

    @Test func scriptsCarryTheWebsiteKeys() {
        #expect(BridgeScripts.writeSchedule.contains("'nr.schedule.v1'"))
        #expect(BridgeScripts.writeSchedule.contains("'nr:schedule'"))
        #expect(BridgeScripts.creditMeter.contains("'web-summit.newsroom.meter.v1'"))
        #expect(BridgeScripts.pageAPI(version: "1.2", ops: ["schedule.get"]).contains(#"version: "1.2", ops: Object.freeze(["schedule.get"])"#))
    }
}
