import Foundation
import Testing
@testable import PTLocal

private let utc = TimeZone(identifier: "UTC")!
private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
private let now = at("2026-11-25T22:00:00Z")

@Suite("Freshness by the feed's own read time")
struct FreshnessTests {
    @Test("Under 3 hours is live; older is a snapshot with its date")
    func window() {
        #expect(Freshness.of(at("2026-11-25T21:10:00Z"), now: now) == .live(at("2026-11-25T21:10:00Z")))
        #expect(Freshness.of(at("2026-11-21T09:20:40Z"), now: now) == .snapshot(at("2026-11-21T09:20:40Z")))
        #expect(Freshness.of(nil, now: now) == .unknown)
        #expect(Freshness.of(at("2026-11-25T18:59:59Z"), now: now).isLive == false)
    }

    @Test("A read time ahead of the clock counts as now")
    func clamped() {
        #expect(Freshness.of(at("2026-11-25T23:30:00Z"), now: now) == .live(now))
    }

    @Test("Labels: the time when live, the day when a snapshot, the year only when it is another year")
    func labels() {
        #expect(Freshness.live(at("2026-11-25T21:10:00Z")).label(now: now, timeZone: utc) == "Live, read 21:10")
        #expect(Freshness.snapshot(at("2026-11-21T09:20:40Z")).label(now: now, timeZone: utc) == "Snapshot, read 21 Nov")
        #expect(Freshness.snapshot(at("2025-11-21T09:20:40Z")).label(now: now, timeZone: utc) == "Snapshot, read 21 Nov 2025")
        #expect(Freshness.unknown.label(now: now) == "Read time not given")
    }

    @Test("The newest of mixed stamps; unreadable ones skipped")
    func newest() {
        let date = Freshness.newest(["2026-11-21", "2026-11-21T09:20:40Z", "nonsense", nil, "2026-11-05T03:45:45.000Z"])
        #expect(date == at("2026-11-21T09:20:40Z"))
        #expect(Freshness.newest([nil, ""]) == nil)
    }

    @Test("Fetched just now but read days ago says snapshot, never live")
    func fetchedButStale() {
        let line = Freshness.line(provenance: .live(now), readAt: at("2026-11-21T09:20:40Z"),
                                  host: "data.promptugal.news", now: now, timeZone: utc)
        #expect(line.text == "Snapshot, read 21 Nov, from data.promptugal.news")
        #expect(line.isLive == false)
    }

    @Test("Fetched and recently read says live; this device's copy never does")
    func liveAndCached() {
        let live = Freshness.line(provenance: .live(now), readAt: at("2026-11-25T21:55:00Z"), now: now, timeZone: utc)
        #expect(live.text == "Live, read 21:55, from promptugal.news")
        #expect(live.isLive)
        let cached = Freshness.line(provenance: .cached(nil), readAt: at("2026-11-25T21:55:00Z"), now: now, timeZone: utc)
        #expect(cached.isLive == false)
        #expect(cached.text.hasPrefix("Offline: this device's copy."))
        let plain = Freshness.line(provenance: .snapshot("21 Nov"), readAt: nil, now: now)
        #expect(plain.text == Provenance.snapshot("21 Nov").label)
    }
}
