import CoreGraphics
import Foundation
import Testing
@testable import PrompTugal

// Tests for the design session's App Review readiness fixes (briefs/2026-11-08__app-review-readiness).

@Suite("Graph index safety (Q2)")
struct GraphIndexSafetyTests {
    @Test("Numbers that are not whole, finite and in range are not node indices")
    func slot() {
        #expect(GraphIndex.slot(0, count: 3) == 0)
        #expect(GraphIndex.slot(2, count: 3) == 2)
        #expect(GraphIndex.slot(3, count: 3) == nil)
        #expect(GraphIndex.slot(-1, count: 3) == nil)
        #expect(GraphIndex.slot(1.5, count: 3) == nil)
        #expect(GraphIndex.slot(1e300, count: 3) == nil)
        #expect(GraphIndex.slot(.nan, count: 3) == nil)
        #expect(GraphIndex.slot(.infinity, count: 3) == nil)
        #expect(GraphIndex.slot(nil, count: 3) == nil)
    }

    private func graph() throws -> GraphExplorer {
        let json = """
        {"version":"t","nodes":[
          {"id":"a","type":"company","label":"A","x":0,"y":0,"pr":1},
          {"id":"b","type":"topic","label":"B","x":10,"y":5,"pr":2},
          {"id":"c","type":"person","label":"C","x":-4,"y":8,"pr":0.5}],
         "verbs":[{"verb":"listed_under","reads":"{from} is listed under {to}"}],
         "edges":[[0,1,0,0,"2026-11-05",3],[1,2,0,0,0,1],[0,1e300,0,0,0,0],[2,7,0,0,0,0],[1,0,99,0,0,0]]}
        """
        return try JSONDecoder().decode(GraphExplorer.self, from: Data(json.utf8))
    }

    @Test("Edges with dates, huge or out-of-range indices decode, and the bad ones are dropped")
    func edges() throws {
        let index = GraphIndex(try graph())
        #expect(index.edges.count == 3)
        #expect(index.contains(2))
        #expect(!index.contains(3))
        #expect(!index.contains(nil))
        #expect(index.sentence(index.edges[0]) == "A is listed under B")
        // An unknown verb falls back to an arrow instead of indexing past the verbs.
        #expect(index.sentence(index.edges[2]) == "B → A")
    }

    @Test("Paths: found inside the graph, nil for nodes outside it")
    func paths() throws {
        let index = GraphIndex(try graph())
        #expect(index.path(from: 0, to: 2) == [0, 1, 2])
        #expect(index.path(from: 0, to: 9) == nil)
        #expect(index.path(from: -1, to: 0) == nil)
    }
}

@Suite("Wake grid taps")
struct WakeGridTapTests {
    @Test("A tap on the hour header selects nothing; rows map from the header down")
    func rows() {
        #expect(WakeGrid.row(at: 5, header: 18, rowHeight: 18, count: 3) == nil)
        #expect(WakeGrid.row(at: 17.9, header: 18, rowHeight: 18, count: 3) == nil)
        #expect(WakeGrid.row(at: 18, header: 18, rowHeight: 18, count: 3) == 0)
        #expect(WakeGrid.row(at: 40, header: 18, rowHeight: 18, count: 3) == 1)
        #expect(WakeGrid.row(at: 200, header: 18, rowHeight: 18, count: 3) == nil)
    }
}

@MainActor
@Suite("Debug mode and links (S4)")
struct DebugLinkTests {
    @Test("Debug-only screens open from a link only while debug mode is on")
    func openable() {
        #expect(Destinations.openable("debug", debug: false) == nil)
        #expect(Destinations.openable("debug", debug: true)?.id == "debug")
        #expect(Destinations.openable("today", debug: false)?.id == "today")
        #expect(Destinations.openable("no-such-screen", debug: true) == nil)
    }

    @Test("Debug mode is on by default only in debug builds")
    func defaultOn() {
        #if DEBUG
        #expect(DebugMode.defaultOn)
        #else
        #expect(!DebugMode.defaultOn)
        #endif
    }
}

@MainActor
@Suite("Sample data for App Review (R1)")
struct SampleDataTests {
    @Test("Sample data fills the team, agents and newsroom, and stays put")
    func sampleData() async {
        let saved = UserDefaults.standard.string(forKey: DashboardData.meKey)
        defer { UserDefaults.standard.set(saved, forKey: DashboardData.meKey) }

        let data = PreviewSamples.data()
        #expect(data.team.value?.people?.count == 2)
        #expect(data.person(SampleMode.samplePersonID)?.first == "Ana")
        #expect(data.dashboard.value?.agents?.count == 3)
        #expect(data.status.value?.pipeline?.isEmpty == false)
        #expect(data.board.value?.stories?.count == 3)
        #expect(data.team.pinned)

        // A pinned feed never goes to the network, even when forced.
        let before = data.team.updated
        await data.team.load(force: true)
        #expect(data.team.updated == before)
        #expect(data.team.value?.people?.count == 2)
    }

    @Test("The reader and sample ids are distinct from each other and from any real person")
    func ids() {
        #expect(SampleMode.readerID != SampleMode.samplePersonID)
        #expect(!SampleMode.readerID.isEmpty)
    }
}

@Suite("Settings links (R3)")
struct SupportLinkTests {
    @Test("Privacy and support pages are https on the app's own site")
    func links() {
        for url in [SupportLinks.privacy, SupportLinks.support] {
            #expect(url.scheme == "https")
            #expect(url.host() == "ios.app.promptugal.news")
        }
        #expect(SupportLinks.privacy.lastPathComponent == "privacy.html")
        #expect(SupportLinks.support.lastPathComponent == "support.html")
        #expect(SupportLinks.independence.contains("not affiliated"))
    }
}

@Suite("Layouts for Split View (Q9)")
struct SplitViewLayoutTests {
    @Test("The wall uses two columns only when there is room, with a bounded side column")
    func wall() {
        #expect(!WallLayout.twoColumns(width: 507))   // half-screen iPad Split View
        #expect(!WallLayout.twoColumns(width: 375))   // iPhone SE
        #expect(WallLayout.twoColumns(width: 1180))
        #expect(WallLayout.sideColumn(width: 760) == 280)
        #expect(WallLayout.sideColumn(width: 1366) == 380)
    }

    @Test("The graph's detail goes beside it only when the graph keeps most of the width")
    func graph() {
        #expect(!GraphLayout.sidePanel(width: 694))
        #expect(GraphLayout.sidePanel(width: 1024))
        #expect(GraphLayout.panelWidth(width: 1366) == 340)
        #expect(GraphLayout.panelWidth(width: 700) == 266)
    }
}
