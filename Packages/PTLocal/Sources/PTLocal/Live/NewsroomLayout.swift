import CoreGraphics
import Foundation

/// Where each agent sits on the live board, in unit coordinates (0...1 on both axes, y down). Town agents sit where
/// their town is (a band across the middle, west to east as on the map); the region and country agents above them,
/// the place desks (`*.places`) on an arc around the region, every other desk in rows below; anyone a handoff names
/// who is not on the dashboard (a person, a desk elsewhere) along the top edge. Pure, so it is tested.
public enum NewsroomLayout {
    public enum Kind: String, Sendable { case town, region, country, placeDesk, desk, outside }

    public struct Node: Identifiable, Hashable, Sendable {
        /// The agent's role, or the handoff's name for someone outside the dashboard.
        public let id: String
        public let label: String
        public let kind: Kind
        public let point: CGPoint
        public let placeID: String?
    }

    /// The box the towns are drawn in (unit coordinates).
    public static let townBand = CGRect(x: 0.07, y: 0.40, width: 0.86, height: 0.26)
    static let lonRange: ClosedRange<Double> = -8.95 ... -7.38
    static let latRange: ClosedRange<Double> = 37.00 ... 37.50

    /// Unit point of a town by its coordinates.
    public static func townPoint(latitude: Double, longitude: Double) -> CGPoint {
        let x = (longitude - lonRange.lowerBound) / (lonRange.upperBound - lonRange.lowerBound)
        let y = 1 - (latitude - latRange.lowerBound) / (latRange.upperBound - latRange.lowerBound)
        return CGPoint(x: townBand.minX + townBand.width * x.clamped(0, 1),
                       y: townBand.minY + townBand.height * y.clamped(0, 1))
    }

    public static func nodes(roles: [String], handoffs: [(from: String, to: String)]) -> [Node] {
        var out: [Node] = []
        var placed = Set<String>()
        func add(_ node: Node) { if placed.insert(node.id).inserted { out.append(node) } }

        let roleSet = Set(roles)
        // Towns, by their place on the map.
        for role in roles where role.hasPrefix("place.") {
            let id = String(role.dropFirst("place.".count))
            if id == PlaceDirectory.region.id {
                add(Node(id: role, label: LocalText.string("Algarve"), kind: .region, point: CGPoint(x: 0.5, y: 0.25), placeID: id))
            } else if id == PlaceDirectory.country.id {
                add(Node(id: role, label: LocalText.string("Portugal"), kind: .country, point: CGPoint(x: 0.5, y: 0.08), placeID: id))
            } else if let info = PlaceDirectory.info(id) {
                add(Node(id: role, label: info.name, kind: .town,
                         point: townPoint(latitude: info.latitude, longitude: info.longitude), placeID: id))
            }
        }
        // Towns that sit almost on top of each other (Castro Marim and Vila Real, Lagoa and Silves) are nudged apart,
        // each pulled back towards its true place.
        let townIndices = out.indices.filter { out[$0].kind == .town }
        let relaxed = AlgarveCartogram.dorling(
            townIndices.map { AlgarveCartogram.Bubble(id: out[$0].id, center: out[$0].point, radius: 0.017, home: out[$0].point) },
            iterations: 120, padding: 0.004, bounds: townBand)
        let moved = Dictionary(uniqueKeysWithValues: relaxed.map { ($0.id, $0.center) })
        for i in townIndices {
            let node = out[i]
            out[i] = Node(id: node.id, label: node.label, kind: node.kind, point: moved[node.id] ?? node.point, placeID: node.placeID)
        }
        // Unknown place agents (a new town) and the place desks share the arc around the region.
        let arc = roles.filter { role in
            !placed.contains(role) && (role.hasSuffix(".places") || role.hasPrefix("place."))
        }.sorted()
        for (i, role) in arc.enumerated() {
            // An open arc around the region, two wings (195°–250° and 290°–345°) so the middle stays clear for the
            // line from the country to the region.
            let t = arc.count == 1 ? 0.0 : Double(i) / Double(arc.count - 1)
            let degrees = t <= 0.5 ? 195 + 110 * t : 235 + 110 * t
            let angle = degrees * .pi / 180
            let point = CGPoint(x: 0.5 + 0.40 * cos(angle), y: 0.33 + 0.19 * sin(angle))
            add(Node(id: role, label: short(role), kind: .placeDesk, point: point, placeID: nil))
        }
        // Every other desk, in rows under the towns.
        let desks = roles.filter { !placed.contains($0) }.sorted()
        let perRow = max(1, Int((Double(desks.count) / 3).rounded(.up)))
        for (i, role) in desks.enumerated() {
            let row = i / perRow, col = i % perRow
            let inRow = min(perRow, desks.count - row * perRow)
            let x = 0.08 + 0.84 * (inRow == 1 ? 0.5 : Double(col) / Double(inRow - 1))
            let y = 0.76 + 0.09 * Double(row)
            add(Node(id: role, label: short(role), kind: .desk, point: CGPoint(x: x, y: y), placeID: nil))
        }
        // Whoever a handoff names that is not an agent here: along the top, outward from the middle.
        let outside = handoffs.flatMap { [$0.from, $0.to] }
            .filter { match($0, in: roleSet) == nil }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        for (i, name) in outside.enumerated() {
            let side = i % 2 == 0 ? -1.0 : 1.0
            let step = Double(i / 2 + 1)
            let x = (0.5 + side * (0.12 + 0.1 * step)).clamped(0.05, 0.95)
            add(Node(id: outsideID(name), label: name, kind: .outside, point: CGPoint(x: x, y: 0.06), placeID: nil))
        }
        return out
    }

    /// The order VoiceOver reads the board in: the towns west to east, then the region and country, the place desks,
    /// the other desks; whoever is outside the dashboard is left out (there is nothing to open).
    public static func spokenOrder(_ nodes: [Node]) -> [Node] {
        func rank(_ kind: Kind) -> Int {
            switch kind {
            case .town: 0
            case .region: 1
            case .country: 2
            case .placeDesk: 3
            case .desk: 4
            case .outside: 5
            }
        }
        return nodes.filter { $0.kind != .outside }.sorted { a, b in
            let ra = rank(a.kind), rb = rank(b.kind)
            if ra != rb { return ra < rb }
            return a.point.x < b.point.x
        }
    }

    /// What VoiceOver says for a node: "Faro, town agent, Working, last sign of life 4 min ago, third pass live".
    public static func spoken(_ node: Node, agent: NewsroomDashboard.Agent?, now: Date) -> String {
        var parts: [String] = [node.label]
        switch node.kind {
        case .town: parts.append(LocalText.string("town agent"))
        case .region: parts.append(LocalText.string("region agent"))
        case .country: parts.append(LocalText.string("country agent"))
        case .placeDesk, .desk: parts.append("desk " + node.id)
        case .outside: parts.append(LocalText.string("outside the newsroom"))
        }
        if let agent {
            parts.append(agent.status.rawValue)
            if let sign = agent.lastSign(now: now) {
                let minutes = max(0, Int(now.timeIntervalSince(sign) / 60))
                parts.append(minutes < 1 ? LocalText.string("active now") : minutes < 120 ? LocalText.string("last sign of life \(String(describing: minutes)) min ago") : LocalText.string("last sign of life \(String(describing: minutes / 60)) h ago"))
            }
            if let state = agent.state { parts.append(state) }
        }
        return parts.joined(separator: ", ")
    }

    /// The node a handoff's name refers to: a role, an agent address, or someone outside.
    public static func nodeID(for name: String, roles: Set<String>) -> String {
        match(name, in: roles) ?? outsideID(name)
    }

    static func match(_ name: String, in roles: Set<String>) -> String? {
        if roles.contains(name) { return name }
        let role = String(name.split(separator: "@").first ?? "")
        return roles.contains(role) ? role : nil
    }

    static func outsideID(_ name: String) -> String { "outside:" + name }

    /// "detective.places" → "detective".
    static func short(_ role: String) -> String {
        role.hasSuffix(".places") ? String(role.dropLast(".places".count)) : role
    }

    /// A gentle curve between two points: the control point lifted off the straight line, so crossing handoffs
    /// stay apart. Returns the point at `t` (0...1).
    public static func curvePoint(from a: CGPoint, to b: CGPoint, t: Double, bend: CGFloat = 0.18) -> CGPoint {
        let control = controlPoint(from: a, to: b, bend: bend)
        let t = CGFloat(t)
        let u: CGFloat = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * control.y + t * t * b.y)
    }

    public static func controlPoint(from a: CGPoint, to b: CGPoint, bend: CGFloat = 0.18) -> CGPoint {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x, dy = b.y - a.y
        return CGPoint(x: mid.x - dy * bend, y: mid.y + dx * bend)
    }
}

extension Double {
    func clamped(_ low: Double, _ high: Double) -> Double { Swift.min(Swift.max(self, low), high) }
}
