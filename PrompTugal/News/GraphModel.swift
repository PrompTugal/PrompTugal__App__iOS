import Foundation
import SwiftUI

/// promptugal.news/api/v1/graph/explorer.json: the whole graph, compact.
/// nodes[i] = {id, type, label, page?, deg, bc, pr, x, y} (x and y are the build's force layout);
/// edges[j] = [from index, to index, verb index, source index, read date or 0, edge betweenness].
struct GraphExplorer: Decodable, Sendable {
    let version: String?
    let worlds: [World]?
    let types: [NodeType]?
    let verbs: [Verb]?
    let nodes: [Node]
    /// Each cell is a number, except the read date, which is a string ("2026-11-05") or 0.
    let edges: [[Cell]]

    /// One cell of an edge row: a number, or text (kept only so the row decodes).
    struct Cell: Decodable, Sendable {
        let number: Double?
        init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            number = try? single.decode(Double.self)
        }
    }

    struct World: Decodable, Identifiable, Hashable, Sendable {
        let id: String
        let label: String?
        let types: [String]?
    }

    struct NodeType: Decodable, Identifiable, Hashable, Sendable {
        let id: String
        let label: String?
        let world: String?
    }

    struct Verb: Decodable, Sendable {
        let verb: String
        let inverse: String?
        let reads: String?
        let readsInverse: String?
        enum CodingKeys: String, CodingKey { case verb, inverse, reads, readsInverse = "reads_inverse" }
    }

    struct Node: Decodable, Identifiable, Sendable {
        let id: String
        let type: String
        let label: String?
        let page: String?
        let deg: Int?
        let bc: Double?
        let pr: Double?
        let x: Double?
        let y: Double?

        var title: String { label ?? id }
        var url: URL? { page.flatMap { URL(string: $0, relativeTo: FeedClient.site)?.absoluteURL } }
    }
}

/// The graph, indexed for drawing and for finding neighbours.
struct GraphIndex: Sendable {
    struct Edge: Sendable { let from: Int; let to: Int; let verb: Int }

    let graph: GraphExplorer
    let edges: [Edge]
    let neighbours: [[Int]]           // node index → edge indices
    let worldOfType: [String: String]
    let bounds: CGRect
    let maxRank: Double
    let byID: [String: Int]

    init(_ graph: GraphExplorer) {
        self.graph = graph
        let count = graph.nodes.count
        let edges = graph.edges.compactMap { row -> Edge? in
            guard row.count >= 3, let a = row[0].number, let b = row[1].number else { return nil }
            let from = Int(a), to = Int(b)
            guard from >= 0, from < count, to >= 0, to < count else { return nil }
            return Edge(from: from, to: to, verb: Int(row[2].number ?? -1))
        }
        self.edges = edges
        var neighbours = Array(repeating: [Int](), count: count)
        for (index, edge) in edges.enumerated() {
            neighbours[edge.from].append(index)
            neighbours[edge.to].append(index)
        }
        self.neighbours = neighbours
        var worlds: [String: String] = [:]
        for world in graph.worlds ?? [] { for type in world.types ?? [] { worlds[type] = world.id } }
        for type in graph.types ?? [] where worlds[type.id] == nil { worlds[type.id] = type.world }
        worldOfType = worlds
        let xs = graph.nodes.compactMap(\.x), ys = graph.nodes.compactMap(\.y)
        bounds = CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                        width: max((xs.max() ?? 1) - (xs.min() ?? 0), 1), height: max((ys.max() ?? 1) - (ys.min() ?? 0), 1))
        maxRank = graph.nodes.compactMap(\.pr).max() ?? 1
        byID = Dictionary(graph.nodes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func position(_ index: Int) -> CGPoint {
        let node = graph.nodes[index]
        return CGPoint(x: node.x ?? 0, y: node.y ?? 0)
    }

    func world(of node: GraphExplorer.Node) -> String { worldOfType[node.type] ?? "other" }

    /// "Replit is listed under AI" — the edge as the site's own sentence.
    func sentence(_ edge: Edge) -> String {
        let from = graph.nodes[edge.from].title, to = graph.nodes[edge.to].title
        guard let verbs = graph.verbs, verbs.indices.contains(edge.verb) else { return "\(from) → \(to)" }
        let verb = verbs[edge.verb]
        let template = verb.reads ?? "{from} \(verb.verb.replacingOccurrences(of: "_", with: " ")) {to}"
        return template.replacingOccurrences(of: "{from}", with: from).replacingOccurrences(of: "{to}", with: to)
    }

    /// The shortest path between two nodes, by breadth-first search over undirected edges.
    func path(from start: Int, to goal: Int, limit: Int = 8) -> [Int]? {
        if start == goal { return [start] }
        var previous = [Int: Int]()
        var frontier = [start]
        var seen: Set<Int> = [start]
        for _ in 0..<limit {
            var next: [Int] = []
            for node in frontier {
                for edgeIndex in neighbours[node] {
                    let edge = edges[edgeIndex]
                    let other = edge.from == node ? edge.to : edge.from
                    guard seen.insert(other).inserted else { continue }
                    previous[other] = node
                    if other == goal {
                        var path = [goal]
                        while let step = previous[path[0]] { path.insert(step, at: 0) }
                        return path
                    }
                    next.append(other)
                }
            }
            frontier = next
            if frontier.isEmpty { break }
        }
        return nil
    }
}

enum GraphColors {
    static func world(_ id: String) -> Color {
        switch id {
        case "summit": Palette.red
        case "people": Palette.blue
        case "industry": Palette.green
        case "evidence": Palette.amber
        case "newsroom": Palette.series(4)
        default: Palette.muted
        }
    }
}
