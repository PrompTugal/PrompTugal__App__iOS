import Foundation
import Testing
@testable import PTLocal

private func since(_ items: [String]) -> Data {
    let text = #"{"built":"2026-11-26","items":["# + items.joined(separator: ",") + "]}"
    return Data(text.utf8)
}

private let sinceItems = [
    #"{"title":"Faro story","url":"https://www.barlavento.pt/a/","place":"faro","rings":["faro","algarve","portugal"],"publisher":"Barlavento"}"#,
    #"{"title":"Faro-sul story","url":"https://x.pt/b/","place":"faro-sul","rings":[]}"#,
    #"{"title":"National article","url":"https://promptugal.news/articles/c.html","place":null,"rings":["portugal"]}"#,
    #"{"title":"Unsafe link","url":"javascript:alert(1)","place":"faro"}"#,
]

private let warnings = Data("""
[{"text":"Long IPMA text not to copy","awarenessTypeName":"Precipitação","idAreaAviso":"FAR","startTime":"2026-11-26T18:00:00","awarenessLevelID":"yellow","endTime":"2026-11-27T06:00:00"},
 {"text":"","awarenessTypeName":"Vento","idAreaAviso":"FAR","startTime":"2026-11-26T18:00:00","awarenessLevelID":"green","endTime":"2026-11-27T06:00:00"},
 {"text":"","awarenessTypeName":"Vento","idAreaAviso":"LSB","startTime":"2026-11-26T18:00:00","awarenessLevelID":"orange","endTime":"2026-11-27T06:00:00"},
 {"text":"","awarenessTypeName":"Nevoeiro","idAreaAviso":"FAR","startTime":"2026-11-25T00:00:00","awarenessLevelID":"red","endTime":"2026-11-25T06:00:00"}]
""".utf8)

private let now = ISO8601DateFormatter().date(from: "2026-11-26T20:00:00Z")!

private final class Recorder: AlertNotifier, @unchecked Sendable {
    var allow: Bool
    var authorized = false
    var asked = 0
    var posted: [AlertCandidate] = []
    init(allow: Bool) { self.allow = allow }
    func requestAuthorization() async -> Bool { asked += 1; authorized = allow; return allow }
    func isAuthorized() async -> Bool { authorized }
    func post(_ alert: AlertCandidate) async { posted.append(alert) }
}

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private final class ClockBox: @unchecked Sendable {
    var value: Date
    init(_ value: Date) { self.value = value }
}

private final class Feeds: @unchecked Sendable {
    var since: Data
    var reads: [URL] = []
    init(since: Data) { self.since = since }
    func fetch(_ url: URL) throws -> Data {
        reads.append(url)
        return url.host() == "api.ipma.pt" ? warnings : since
    }
}

private func defaults() -> UserDefaults {
    let name = "alerts-tests-\(UUID().uuidString)"
    let store = UserDefaults(suiteName: name)!
    store.removePersistentDomain(forName: name)
    return store
}

@Suite("Alerts")
struct AlertsTests {
    @Test("Followed places parse as PTPlaces writes them")
    func followed() {
        #expect(FollowedPlaces.ids("faro, loule,,lisboa ") == ["faro", "loule", "lisboa"])
        #expect(FollowedPlaces.ids(nil).isEmpty)
        #expect(FollowedPlaces.key == "places.followed")
    }

    @Test("New stories: only followed places (exact ids, place or rings), safe links, headline and outlet")
    func stories() {
        let topic = TownStoriesAlert()
        let found = topic.candidates(from: since(sinceItems), followed: ["faro"], now: now)
        #expect(found.map(\.body) == ["Faro story (Barlavento)"])
        #expect(found.first?.link?.absoluteString == "https://www.barlavento.pt/a/")
        #expect(found.first?.title.contains("Faro") == true)
        #expect(topic.candidates(from: since(sinceItems), followed: ["algarve"], now: now).count == 1)
        #expect(topic.candidates(from: since(sinceItems), followed: ["portugal"], now: now).count == 2)
        #expect(topic.candidates(from: since(sinceItems), followed: [], now: now).isEmpty)
    }

    @Test("IPMA: yellow and above, current, for the followed districts; IPMA's text is never copied")
    func ipma() {
        let topic = IPMAWarningsAlert()
        let algarve = topic.candidates(from: warnings, followed: ["loule"], now: now)
        #expect(algarve.count == 1)
        #expect(algarve[0].title.contains("Faro"))
        #expect(!algarve[0].body.contains("Long IPMA text"))
        #expect(algarve[0].link == IPMAWarningsAlert.page)
        #expect(topic.candidates(from: warnings, followed: ["lisboa", "faro"], now: now).count == 2)
        #expect(topic.candidates(from: warnings, followed: ["portugal"], now: now).isEmpty)
        #expect(IPMAWarningsAlert.area(for: "quarteira") == "FAR")
        #expect(IPMAWarningsAlert.area(for: "vila-real") == "VRL")
        #expect(IPMAWarningsAlert.area(for: "vila-real-de-santo-antonio") == "FAR")
    }

    @Test("Turning an alert on asks permission then; the first check notes what is there, later checks post what is new")
    @MainActor func center() async {
        let store = defaults()
        store.set("faro", forKey: FollowedPlaces.key)
        let feeds = Feeds(since: since([sinceItems[0]]))
        let recorder = Recorder(allow: true)
        let clock = ClockBox(now)                                 // 26 Nov, 20:00 UTC
        let center = AlertsCenter(defaults: store, fetch: { try feeds.fetch($0) }, notifier: recorder,
                                  clock: { clock.value }, calendar: utcCalendar)
        #expect(recorder.asked == 0)
        await center.set("town-stories", on: true)
        #expect(recorder.asked == 1)
        #expect(center.isOn("town-stories"))
        #expect(recorder.posted.isEmpty)                         // first run: nothing is "new"
        #expect(feeds.reads.allSatisfy { $0.host() == "promptugal.news" })
        feeds.since = since([sinceItems[0], #"{"title":"Second","url":"https://x.pt/2/","place":"faro"}"#])
        await center.check()
        #expect(recorder.posted.map(\.body) == ["Second"])
        await center.check()
        #expect(recorder.posted.count == 1)                      // not twice
        await center.set("ipma-warnings", on: true)
        #expect(recorder.asked == 1)                             // already allowed
        #expect(store.stringArray(forKey: "local.alerts.enabled") == ["ipma-warnings", "town-stories"])
    }

    @Test("At most one alert a topic a day, none from 22:00 to 08:00; what waits goes into the next one")
    @MainActor func pacing() async {
        let store = defaults()
        store.set("faro", forKey: FollowedPlaces.key)
        let feeds = Feeds(since: since([sinceItems[0]]))
        let recorder = Recorder(allow: true)
        let clock = ClockBox(now)                                 // 26 Nov, 20:00 UTC
        let center = AlertsCenter(defaults: store, fetch: { try feeds.fetch($0) }, notifier: recorder,
                                  clock: { clock.value }, calendar: utcCalendar)
        await center.set("town-stories", on: true)
        feeds.since = since([sinceItems[0], #"{"title":"Two","url":"https://x.pt/2/","place":"faro"}"#])
        await center.check()
        #expect(recorder.posted.map(\.body) == ["Two"])
        feeds.since = since([sinceItems[0], #"{"title":"Two","url":"https://x.pt/2/","place":"faro"}"#,
                             #"{"title":"Three","url":"https://x.pt/3/","place":"faro"}"#,
                             #"{"title":"Four","url":"https://x.pt/4/","place":"faro"}"#])
        clock.value = now.addingTimeInterval(3600)               // 21:00: already one today
        await center.check()
        #expect(recorder.posted.count == 1)
        clock.value = now.addingTimeInterval(7 * 3600)           // 27 Nov, 03:00: quiet hours
        await center.check()
        #expect(recorder.posted.count == 1)
        clock.value = now.addingTimeInterval(13 * 3600)          // 27 Nov, 09:00
        await center.check()
        #expect(recorder.posted.count == 2)
        #expect(recorder.posted[1].body.hasPrefix("Three"))
        #expect(recorder.posted[1].body.contains("1 more"))
    }

    @Test("Quiet hours are 22:00 to 08:00 on the reader's clock")
    func quiet() {
        func at(_ hour: Int) -> Date { ISO8601DateFormatter().date(from: String(format: "2026-11-26T%02d:30:00Z", hour))! }
        #expect(AlertsCenter.isQuiet(at(22), calendar: utcCalendar))
        #expect(AlertsCenter.isQuiet(at(3), calendar: utcCalendar))
        #expect(AlertsCenter.isQuiet(at(7), calendar: utcCalendar))
        #expect(!AlertsCenter.isQuiet(at(8), calendar: utcCalendar))
        #expect(!AlertsCenter.isQuiet(at(21), calendar: utcCalendar))
    }

    @Test("Refused permission leaves the alert off and says why")
    @MainActor func refused() async {
        let store = defaults()
        let recorder = Recorder(allow: false)
        let center = AlertsCenter(defaults: store, fetch: { _ in Data() }, notifier: recorder, clock: { now })
        await center.set("ipma-warnings", on: true)
        #expect(!center.isOn("ipma-warnings"))
        #expect(center.permissionDenied)
        #expect(center.message != nil)
    }

    @Test("Several new at once make one alert: the first, and how many more")
    func combine() {
        let many = (1...3).map { AlertCandidate(id: "\($0)", topic: "t", title: "T\($0)", body: "B\($0)", link: nil) }
        let one = AlertsCenter.combine(many)
        #expect(one?.title == "T1")
        #expect(one?.body.hasPrefix("B1") == true)
        #expect(one?.body.contains("2 more") == true)
        #expect(AlertsCenter.combine(Array(many.prefix(1)))?.body == "B1")
        #expect(AlertsCenter.combine([]) == nil)
    }

    @Test("Every topic has a distinct id and a public feed")
    func topics() {
        let ids = AlertTopics.all.map { $0.id }
        #expect(Set(ids).count == ids.count)
        #expect(AlertTopics.all.allSatisfy { $0.feed.scheme == "https" })
        #expect(AlertTopics.topic("ipma-warnings") != nil)
    }
}
