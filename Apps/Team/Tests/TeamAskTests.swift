import Foundation
import Testing
import PTCore
@testable import Team

@Suite("Ask: team context (Team app)")
struct TeamAskContextTests {
    private func person(_ json: String) throws -> TeamPerson {
        let text = "{\"built_at\":\"x\",\"version\":\"v\",\"people\":{\"dinis\":" + json + "}}"
        let me = try JSONDecoder().decode(TeamMe.self, from: Data(text.utf8))
        return try #require(me.person("dinis"))
    }

    private func centre(_ json: String) throws -> CommandCentre {
        try JSONDecoder().decode(CommandCentre.self, from: Data(json.utf8))
    }

    @Test("Team status reads the team session's models")
    func team() throws {
        let me = try person(#"{"id":"dinis","name":"Dinis Cruz","only_you":4,"decide":23,"overdue":56,"standup_at":"2026-11-07T12:00:00.000Z","urgent":[{"id":"WS-63","title":"Print files","due":"Mon 2 Nov","late":true}]}"#)
        let cc = try centre(#"{"person":{"id":"dinis","name":"Dinis"},"standups":{"times_utc":["13:00","18:00"]},"decisions":[{"what":"Protect main","recommend":"Now"}],"agents":[{"short":"abp","name":"abp@x","commits_24h":8,"last_at":"2026-11-07T00:52:28Z","last_subject":"WS-188"}],"unknown_future_field":1}"#)
        let part = TeamAskContext.teamPart(person: "dinis", me: me, centre: cc)
        #expect(part.summary == "4 only you · 23 to decide · 56 overdue")
        #expect(part.body.contains("WS-63 Print files (due Mon 2 Nov, late)"))
        #expect(part.body.contains("Protect main (recommended: Now)"))
        #expect(part.body.contains("Next stand-up: Sat 7 Nov 12:00"))
        #expect(part.body.contains("abp: 8 commits in 24 h"))
        #expect(TeamAskContext.teamPart(person: "x", me: nil, centre: nil).body.isEmpty)
    }

    @Test("Agents part marks my commits")
    func agents() throws {
        let cc = try centre(#"{"person":{"id":"dinis"},"agents":[{"name":"a@x","status":"active","commits_24h":0,"commits_7d":3}],"activity":[{"at":"2026-11-07T03:22:02Z","subject":"mine","mine":true},{"at":"2026-11-07T03:21:24Z","subject":"theirs","mine":false}]}"#)
        let part = TeamAskContext.agentsPart(person: "dinis", centre: cc)
        #expect(part.summary == "1 agents, 0 active in 24 h")
        #expect(part.body.contains("* Sat 7 Nov 03:22 mine"))
        #expect(part.body.contains("- Sat 7 Nov 03:21 theirs"))
        #expect(TeamAskContext.agentsPart(person: "dinis", centre: nil).body.isEmpty)
    }

    @Test("Pick ids are the bare slug, whatever form they arrive in")
    func pickIds() throws {
        #expect(PickId.normalise("events/ai-doom-or-boom/index.html") == "ai-doom-or-boom")
        #expect(PickId.normalise("/events/abc/") == "abc")
        #expect(PickId.normalise("events/abc") == "abc")
        #expect(PickId.normalise("abc") == "abc")
        let doc = try PickId.scheduleDocument(ids: ["events/a/index.html", "b"])
        #expect(PickId.ids(inScheduleDocument: doc) == ["a", "b"])
        let text = String(decoding: doc, as: UTF8.self)
        #expect(text.contains("\"v\":1"))
        #expect(text.range(of: #"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z"#, options: .regularExpression) != nil)
        #expect(PickId.ids(inScheduleDocument: Data("[]".utf8)).isEmpty)
    }
}
