import Foundation
import Testing
@testable import PTNowNext

@Suite("Now and next snapshot")
struct NowNextSnapshotTests {
    /// A whole second, so the ISO 8601 round trip is exact.
    private let now = Date(timeIntervalSince1970: 1_762_855_200)

    private func item(_ id: String, start: TimeInterval, end: TimeInterval?, mine: Bool = false) -> NowNextSnapshot.Item {
        NowNextSnapshot.Item(id: id, title: id, place: "Stage", start: now.addingTimeInterval(start * 60),
                             end: end.map { now.addingTimeInterval($0 * 60) }, mine: mine, url: nil)
    }

    private var snapshot: NowNextSnapshot {
        NowNextSnapshot(updatedAt: now, items: [
            item("running", start: -15, end: 45, mine: true),
            item("later", start: 105, end: 135),
            item("noEnd", start: 300, end: nil),
        ])
    }

    @Test func nowIsWhatHasStartedAndNotEnded() {
        #expect(snapshot.now(at: now).map(\.id) == ["running"])
        #expect(snapshot.now(at: now.addingTimeInterval(110 * 60)).map(\.id) == ["later"])
    }

    @Test func nextIsWhatStartsAfterInOrderUpToTheLimit() {
        #expect(snapshot.next(after: now).map(\.id) == ["later", "noEnd"])
        #expect(snapshot.next(after: now, limit: 1).map(\.id) == ["later"])
    }

    @Test func aSessionWithNoEndRunsThirtyMinutes() {
        let open = NowNextSnapshot(updatedAt: now, items: [item("open", start: -10, end: nil)])
        #expect(open.now(at: now).map(\.id) == ["open"])
        #expect(open.now(at: now.addingTimeInterval(25 * 60)).isEmpty)
    }

    @Test func timelineChangesAreTheStartsAndEndsInRange() {
        let changes = snapshot.changes(after: now, until: now.addingTimeInterval(3 * 3_600))
        #expect(changes == [now.addingTimeInterval(45 * 60), now.addingTimeInterval(105 * 60), now.addingTimeInterval(135 * 60)])
    }

    @Test func itRoundTripsThroughJSON() throws {
        #expect(SharedContainer.decode(try SharedContainer.encode(snapshot)) == snapshot)
    }

    @Test func aSnapshotOfAnotherVersionIsRefused() throws {
        let other = NowNextSnapshot(version: NowNextSnapshot.version + 1, updatedAt: now, items: [])
        #expect(SharedContainer.decode(try SharedContainer.encode(other)) == nil)
        #expect(SharedContainer.decode(Data("not json".utf8)) == nil)
    }

    @Test func theClockIsLisbonTime() {
        #expect(LisbonClock.zone.identifier == "Europe/Lisbon")
        #expect(!LisbonClock.time(now).isEmpty)
    }

    @Test func theAppGroupIsTheReaderGroupUntilAnAppSetsItsOwn() {
        #expect(SharedContainer.appGroup == "group.news.promptugal.reader")
        #expect(SharedContainer.nowNextKind == "news.promptugal.reader.now-next")
    }
}
