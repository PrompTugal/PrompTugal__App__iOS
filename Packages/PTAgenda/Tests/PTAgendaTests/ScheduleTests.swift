import Foundation
import Testing
@testable import PTAgenda
import PTCore

// The schedule's wire format, merge rule, Lisbon time and the saved.json migration (team session, contracts §3).
// Each rule has a negative control next to it: the same input without the thing that makes the rule work.

private let t0 = Date(timeIntervalSince1970: 1_762_650_000)   // 2025-11-09T01:00:00Z, any fixed instant
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }
private func doc(_ picks: [(String, Date)]) -> ScheduleDocument {
    ScheduleDocument(picks: picks.map { .init(id: $0.0, at: $0.1) })
}
private func event(_ slug: String, date: String = "2026-11-10", time: String = "14:20-14:40") -> Event {
    Event(date: date, time: time, title: slug, place: "Centre Stage", kind: "session", official: true,
          page: "events/\(slug)/index.html")
}

@Suite("Wire format")
struct ScheduleWireTests {
    @Test func readsTheWebsitesISOForm() throws {
        let text = #"{"v":1,"picks":[{"id":"ai-doom-or-boom","at":"2026-11-08T03:12:45.120Z"}]}"#
        let document = try #require(ScheduleDocument.decode(text))
        #expect(document.picks.map(\.id) == ["ai-doom-or-boom"])
        #expect(ScheduleTime.format(document.picks[0].at) == "2026-11-08T03:12:45.120Z")
    }

    @Test func readsTheContractsMillisecondForm() throws {
        let document = try #require(ScheduleDocument.decode(#"{"v":1,"picks":[{"id":"a","at":1762650000000}]}"#))
        #expect(document.picks[0].at == Date(timeIntervalSince1970: 1_762_650_000))
    }

    @Test func writesTheWebsitesForm() throws {
        let json = doc([("a", Date(timeIntervalSince1970: 1_762_650_000.5))]).json
        #expect(json == #"{"v":1,"picks":[{"id":"a","at":"2025-11-09T01:00:00.500Z"}]}"#)
    }

    @Test func refusesWhatTheWebsiteRefuses() {
        #expect(ScheduleDocument.decode(#"{"v":2,"picks":[]}"#) == nil)
        #expect(ScheduleDocument.decode(#"{"v":1,"picks":{}}"#) == nil)
        #expect(ScheduleDocument.decode("null") == nil)
        #expect(ScheduleDocument.decode("not json") == nil)
        // control: the smallest valid document is accepted
        #expect(ScheduleDocument.decode(#"{"v":1,"picks":[]}"#) == ScheduleDocument())
    }

    @Test func dropsBadAndDuplicatePicks() throws {
        let text = #"{"v":1,"picks":[{"id":"a","at":"2026-11-08T00:00:00.000Z"},{"id":"a","at":"2026-11-09T00:00:00.000Z"},{"id":"x/y","at":"2026-11-08T00:00:00Z"},{"at":"2026-11-08T00:00:00Z"},{"id":"b"}]}"#
        let document = try #require(ScheduleDocument.decode(text))
        // "b" has no time: since the Q1 fix, a pick without a time between 2000 and 2100 is dropped
        #expect(document.picks.map(\.id) == ["a"])
    }

    @Test func idIsTheSlugAsTheWebsiteMakesIt() {
        #expect(ScheduleID.fromPage("events/ai-doom-or-boom/index.html") == "ai-doom-or-boom")
        #expect(ScheduleID.fromPage("/events/ai-doom-or-boom/index.html") == "ai-doom-or-boom")
        #expect(ScheduleID.fromPage("https://promptugal.news/events/x-y/index.html") == "x-y")
        // negative controls: other pages are not events
        #expect(ScheduleID.fromPage("articles/ai-doom-or-boom/index.html") == nil)
        #expect(ScheduleID.fromPage("events/index.html") == nil)
        #expect(ScheduleID.fromPage("ai-doom-or-boom") == nil)
    }
}

@Suite("Merge rule")
struct ScheduleMergeTests {
    @Test func unionByIdKeepsOurCopy() {
        var local = ScheduleState()
        local.picks = ["a": at(0)]
        let outcome = ScheduleMerge.merge(doc([("a", at(5)), ("b", at(6))]), into: local, now: at(10))
        #expect(outcome.state.picks == ["a": at(0), "b": at(6)])
        #expect(outcome.added == ["b"])
        #expect(outcome.removed.isEmpty)
    }

    @Test func aLaterRemovalWins() {
        let picked = ScheduleMerge.toggle("a", in: ScheduleState(), now: at(0))
        let removed = ScheduleMerge.toggle("a", in: picked, now: at(10))
        #expect(removed.picks["a"] == nil)
        // a stale copy (picked at 0) must not bring it back
        let outcome = ScheduleMerge.merge(doc([("a", at(0))]), into: removed, now: at(20))
        #expect(outcome.state.picks["a"] == nil)
        #expect(!outcome.changed)
    }

    @Test func negativeControlWithoutTheRemovalTheStaleCopyComesBack() {
        // the same stale copy, into a state that never saw the removal: the union adds it
        let outcome = ScheduleMerge.merge(doc([("a", at(0))]), into: ScheduleState(), now: at(20))
        #expect(outcome.state.picks["a"] == at(0))
    }

    @Test func aPickLaterThanTheRemovalWins() {
        var local = ScheduleState()
        local.removed = ["a": at(10)]
        let outcome = ScheduleMerge.merge(doc([("a", at(15))]), into: local, now: at(20))
        #expect(outcome.state.picks["a"] == at(15))
        #expect(outcome.state.removed["a"] == nil)
    }

    @Test func aRemovalOnThePageIsSeenThroughTheBaseline() {
        var local = ScheduleState()
        local.picks = ["a": at(0), "b": at(1)]
        let baseline = ScheduleBaseline(ids: ["a", "b"], at: at(5))
        let outcome = ScheduleMerge.merge(doc([("b", at(1))]), into: local, baseline: baseline, now: at(30))
        #expect(outcome.state.picks.keys.sorted() == ["b"])
        #expect(outcome.removed == ["a"])
        #expect(outcome.state.removed["a"] == at(30))
    }

    @Test func negativeControlWithoutABaselineNothingIsRemoved() {
        var local = ScheduleState()
        local.picks = ["a": at(0), "b": at(1)]
        let outcome = ScheduleMerge.merge(doc([("b", at(1))]), into: local, baseline: nil, now: at(30))
        #expect(outcome.state.picks.keys.sorted() == ["a", "b"])
    }

    @Test func aPickMadeInTheAppAfterTheLastSyncIsKept() {
        var local = ScheduleState()
        local.picks = ["a": at(10)]                     // picked in the app at 10
        let baseline = ScheduleBaseline(ids: ["a"], at: at(5)) // last sync at 5 (the page had an older "a")
        let outcome = ScheduleMerge.merge(doc([]), into: local, baseline: baseline, now: at(30))
        #expect(outcome.state.picks["a"] == at(10))
    }

    @Test func removalsAreForgottenAfterThirtyDays() {
        var local = ScheduleState()
        local.removed = ["old": at(0), "new": at(60 * 24 * 29)]
        let pruned = ScheduleMerge.pruned(local, now: at(60 * 24 * 30 + 1))
        #expect(pruned.removed.keys.sorted() == ["new"])
    }

    @Test func toggleTwiceIsANoOpOnPicks() {
        let state = ScheduleMerge.toggle("a", in: ScheduleMerge.toggle("a", in: ScheduleState(), now: at(0)), now: at(1))
        #expect(state.picks.isEmpty)
        #expect(state.removed["a"] == at(1))
    }
}

@Suite("Lisbon time, for the schedule")
struct ScheduleLisbonTimeTests {
    @Test func novemberIsUTC() throws {
        let start = try #require(Lisbon.instant(day: "2026-11-10", clock: "14:20"))
        #expect(start == ScheduleTime.parse("2026-11-10T14:20:00Z"))
    }

    @Test func negativeControlSummerIsOneHourAhead() throws {
        // proves the zone is Lisbon's, not UTC: in July Lisbon is UTC+1
        let noon = try #require(Lisbon.instant(day: "2026-07-01", clock: "12:00"))
        #expect(noon == ScheduleTime.parse("2026-07-01T11:00:00Z"))
    }

    @Test func anEventPastMidnightEndsTheNextDay() throws {
        let night = event("night-summit", date: "2026-11-10", time: "22:00-02:00")
        let end = try #require(night.end)
        #expect(end == ScheduleTime.parse("2026-11-11T02:00:00Z"))
    }

    @Test func badClocksAreRefused() {
        #expect(Lisbon.instant(day: "2026-11-10", clock: "25:00") == nil)
        #expect(Lisbon.instant(day: "2026-11", clock: "10:00") == nil)
    }
}

@Suite("Store and migration")
@MainActor
struct ScheduleStoreTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("schedule-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeSaved(_ events: [Event], to dir: URL, modified: Date) throws {
        let saved = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        let url = dir.appendingPathComponent("saved.json")
        try JSONEncoder().encode(saved).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    @Test func migratesEverySavedSession() throws {
        let dir = try folder()
        var events: [Event] = []
        for n in 1...12 {
            let hour: Int = 8 + n % 10
            events.append(event("session-\(n)", time: String(format: "%02d:00-%02d:30", hour, hour)))
        }
        try writeSaved(events, to: dir, modified: at(0))
        let store = ScheduleStore(directory: dir, clock: { at(1) })
        #expect(store.picks.count == 12)
        #expect(Set(store.document.picks.map(\.id)) == Set(events.map { ScheduleID.fromPage($0.page)! }))
        #expect(store.picks.allSatisfy { $0.event != nil })   // offline copies kept
        // saved.json is left in place, as a backup
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("saved.json").path))
    }

    @Test func migrationRunsOnceAndRespectsLaterRemovals() throws {
        let dir = try folder()
        try writeSaved([event("a"), event("b")], to: dir, modified: at(0))
        let first = ScheduleStore(directory: dir, clock: { at(1) })
        first.toggle("a")                                     // removed at 1, after the saved.json date
        let second = ScheduleStore(directory: dir, clock: { at(2) })
        #expect(second.document.picks.map(\.id) == ["b"])
    }

    @Test func negativeControlANewerSavedFileIsImportedAgain() throws {
        let dir = try folder()
        try writeSaved([event("a")], to: dir, modified: at(0))
        _ = ScheduleStore(directory: dir, clock: { at(1) })
        try writeSaved([event("a"), event("c")], to: dir, modified: at(5))   // an older build saved one more
        let again = ScheduleStore(directory: dir, clock: { at(6) })
        #expect(Set(again.document.picks.map(\.id)) == ["a", "c"])
    }

    @Test func picksSortByEventStartInLisbon() throws {
        let dir = try folder()
        let store = ScheduleStore(directory: dir, clock: { at(0) })
        store.updateEvents([event("late", time: "16:00-16:20"), event("early", time: "09:00-09:20"),
                            event("next-day", date: "2026-11-11", time: "08:00-08:20")])
        store.toggle("late"); store.toggle("unknown-slug"); store.toggle("next-day"); store.toggle("early")
        #expect(store.picks.map(\.id) == ["early", "late", "next-day", "unknown-slug"])
    }

    @Test func persistsAcrossLaunches() throws {
        let dir = try folder()
        let store = ScheduleStore(directory: dir, clock: { at(0) })
        store.toggle("events/ai-doom-or-boom/index.html")
        #expect(store.isPicked("ai-doom-or-boom"))
        let reopened = ScheduleStore(directory: dir, clock: { at(1) })
        #expect(reopened.isPicked("events/ai-doom-or-boom/index.html"))
    }

    @Test func webSyncRemovesWhatThePageRemoved() throws {
        let dir = try folder()
        var now = at(0)
        let store = ScheduleStore(directory: dir, clock: { now })
        store.merge(doc([("a", at(0)), ("b", at(0))]), from: .web)
        store.markSynced(.web, document: store.document)
        now = at(10)
        store.merge(doc([("b", at(0))]), from: .web)
        #expect(store.document.picks.map(\.id) == ["b"])
        // and a vault copy that still has "a" from before cannot bring it back
        store.merge(doc([("a", at(0))]))
        #expect(store.document.picks.map(\.id) == ["b"])
    }
}

@Suite("Vault mirror")
@MainActor
struct ScheduleVaultSyncTests {
    @Test func pullsAndPushesTheWebsitesDocument() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vault-\(UUID().uuidString)")
        let store = ScheduleStore(directory: dir, clock: { at(0) })
        store.toggle("mine")
        let fromVault = #"{"v":1,"picks":[{"id":"from-vault","at":"2026-11-08T03:12:45.120Z"}]}"#
        let result = try await ScheduleVaultSync.pull(into: store) { path in
            #expect(path == "agenda/picks")
            return fromVault
        }
        #expect(result == .init(found: true, added: 1, removed: 0))
        #expect(Set(store.document.picks.map(\.id)) == ["mine", "from-vault"])
        var written: String?
        try await ScheduleVaultSync.push(from: store) { _, text in written = text }
        #expect(ScheduleDocument.decode(try #require(written))?.picks.count == 2)
        // control: an empty vault changes nothing
        let none = try await ScheduleVaultSync.pull(into: store) { _ in nil }
        #expect(!none.found)
    }
}

@Suite("Website round trip")
struct ScheduleRoundTripTests {
    /// The shape schedule.js writes: ISO strings from toISOString(), any order, odd milliseconds.
    static let website = #"{"v":1,"picks":[{"id":"ai-doom-or-boom","at":"2026-11-08T03:12:45.120Z"},{"id":"ai-s-octopus-era","at":"2026-11-08T03:13:01.007Z"},{"id":"a-identity-auth-tips-to-secure-ai-agents-and-mcp-servers","at":"2026-11-08T23:59:59.999Z"}]}"#

    @Test func everyTimeComesBackCharacterForCharacter() throws {
        let document = try #require(ScheduleDocument.decode(Self.website))
        let again = try #require(ScheduleDocument.decode(document.json))
        let original = try JSONSerialization.jsonObject(with: Data(Self.website.utf8)) as! [String: Any]
        let written = try JSONSerialization.jsonObject(with: document.encoded()) as! [String: Any]
        let before = (original["picks"] as! [[String: String]]).map { [$0["id"]!, $0["at"]!] }
        let after = (written["picks"] as! [[String: String]]).map { [$0["id"]!, $0["at"]!] }
        #expect(before == after)
        #expect(again == document)
    }

    @Test func thousandsOfMillisecondValuesSurvive() {
        // every millisecond of one second, plus some far dates: format(parse(x)) == x
        for ms in 0..<1000 {
            let text = String(format: "2026-11-10T14:20:07.%03dZ", ms)
            #expect(ScheduleTime.format(ScheduleTime.parse(text)!) == text)
        }
        for text in ["1999-12-31T23:59:59.999Z", "2038-01-19T03:14:08.001Z", "2026-03-29T01:00:00.000Z"] {
            #expect(ScheduleTime.format(ScheduleTime.parse(text)!) == text)
        }
    }

    @Test func numbersAreReadAndWrittenAsTheWebsitesString() throws {
        let document = try #require(ScheduleDocument.decode(#"{"v":1,"picks":[{"id":"a","at":1762650000123}]}"#))
        #expect(document.json == #"{"v":1,"picks":[{"id":"a","at":"2025-11-09T01:00:00.123Z"}]}"#)
    }
}

@Suite("Vault sync, vault session's API")
@MainActor
struct ScheduleVaultAPITests {
    @Test func loadMergeSaveMerge() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vsync-\(UUID().uuidString)")
        let store = ScheduleStore(directory: dir, clock: { Date(timeIntervalSince1970: 1_762_650_000) })
        store.toggle("local-pick")
        var sent: Data?
        let outcome = try await ScheduleVaultSync.sync(store, load: { Data(ScheduleRoundTripTests.website.utf8) }, save: { data in
            sent = data
            // the vault answers with the union, plus a pick another device made meanwhile
            var doc = ScheduleDocument.decode(data)!
            doc.picks.append(.init(id: "from-phone-2", at: Date(timeIntervalSince1970: 1_762_650_100)))
            return doc.encoded()
        })
        #expect(outcome.found && outcome.added == 4)
        #expect(ScheduleDocument.decode(try #require(sent))?.picks.count == 4)
        #expect(store.document.picks.count == 5)
    }
}

@Suite("Deterministic JSON")
struct ScheduleJSONTests {
    @Test func keyOrderIsTheWebsitesEveryTime() {
        let document = ScheduleDocument(picks: [.init(id: "b", at: Date(timeIntervalSince1970: 1)),
                                                .init(id: "a", at: Date(timeIntervalSince1970: 2))])
        for _ in 0..<20 {
            #expect(document.json == #"{"v":1,"picks":[{"id":"b","at":"1970-01-01T00:00:01.000Z"},{"id":"a","at":"1970-01-01T00:00:02.000Z"}]}"#)
        }
    }

    @Test func oddIdsAreEscapedAndReadBack() throws {
        // ids never look like this on the website; the writer must still produce valid JSON
        let odd = "quote\" back\\slash\ttab\u{01}"
        let document = ScheduleDocument(picks: [.init(id: odd, at: Date(timeIntervalSince1970: 0))])
        let parsed = try JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any]
        let picks = try #require(parsed?["picks"] as? [[String: Any]])
        #expect(picks.first?["id"] as? String == odd)
    }
}


@Suite("Hostile pick times (Q1)")
struct SchedulePickTimeTests {
    private func ids(_ json: String) -> [String] {
        ScheduleDocument.decode(json)?.picks.map(\.id) ?? ["<not a document>"]
    }

    @Test func hugeAndOddNumbersAreDroppedNotCrashing() {
        let json = #"{"v":1,"picks":[{"id":"huge","at":1e300},{"id":"tiny","at":-1e300},{"id":"negative","at":-1},{"id":"zero","at":0},{"id":"far","at":4102444800001},{"id":"ok","at":1762650000000}]}"#
        #expect(ids(json) == ["ok"])
    }

    @Test func oddStringsAreDropped() {
        let json = #"{"v":1,"picks":[{"id":"nan","at":"NaN"},{"id":"inf","at":"Infinity"},{"id":"num","at":"1e300"},{"id":"word","at":"tomorrow"},{"id":"old","at":"1999-12-31T23:59:59.999Z"},{"id":"late","at":"2100-01-01T00:00:00.001Z"},{"id":"ok","at":"2026-11-10T14:20:00.000Z"}]}"#
        #expect(ids(json) == ["ok"])
    }

    @Test func boundariesAreInclusive() {
        let json = #"{"v":1,"picks":[{"id":"first","at":"2000-01-01T00:00:00.000Z"},{"id":"last","at":"2100-01-01T00:00:00.000Z"}]}"#
        #expect(Set(ids(json)) == ["first", "last"])
    }

    @Test func formatNeverTraps() {
        // each of these used to reach Int64(...) unchecked
        for value in [1e300, -1e300, Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, .nan, .infinity, -.infinity] {
            let text = ScheduleTime.format(Date(timeIntervalSince1970: value))
            #expect(text.hasSuffix("Z"))
        }
        // control: a normal time is still written exactly
        #expect(ScheduleTime.format(Date(timeIntervalSince1970: 1_762_650_000.123)) == "2025-11-09T01:00:00.123Z")
    }

    @Test @MainActor func aBadTimeSavedByAnOlderBuildIsDroppedAtLaunch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("q1-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // schedule.json as JSONEncoder writes Dates (seconds since 2001), one pick far out of range
        let saved = #"{"state":{"picks":{"bad":1e300,"good":815000000},"removed":{"gone":-1e300}},"events":{},"baselines":{}}"#
        try Data(saved.utf8).write(to: dir.appendingPathComponent("schedule.json"))
        let store = ScheduleStore(directory: dir, clock: { Date(timeIntervalSince1970: 1_762_650_000) })
        #expect(store.document.picks.map(\.id) == ["good"])
        #expect(store.document.json.contains("\"good\""))
    }
}
