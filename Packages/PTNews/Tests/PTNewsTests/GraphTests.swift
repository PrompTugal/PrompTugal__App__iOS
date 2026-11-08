import CoreGraphics
import Foundation
import Testing
@testable import PTNews

// Moved from the app's DesignReviewTests: the graph index and layout tests.

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

@Suite("Graph layout")
struct GraphLayoutTests {
    @Test("The graph's detail goes beside it only when the graph keeps most of the width")
    func graph() {
        #expect(!GraphLayout.sidePanel(width: 694))
        #expect(GraphLayout.sidePanel(width: 1024))
        #expect(GraphLayout.panelWidth(width: 1366) == 340)
        #expect(GraphLayout.panelWidth(width: 700) == 266)
    }
}
