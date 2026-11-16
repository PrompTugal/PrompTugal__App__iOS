import PTCore
import SwiftUI

/// The board: every agent as a node, town agents where their town is, handoffs flowing between nodes as particles,
/// a pulse on any agent that showed a sign of life in the last half hour, a spark on any seen to change while
/// watching. Drawn in one Canvas under a TimelineView; with Reduce Motion the board is still, and recency shows as a
/// steady halo instead of a pulse. Tapping a node selects it; nothing here acts on an agent.
struct NewsroomBoard: View {
    let model: LiveNewsroom
    @Binding var selected: String?
    var highlighted: Set<String> = []
    /// When set, the board replays the last 24 hours: the position in the dashboard's hour grid (0 = its first hour),
    /// and each agent lights up in the hours it fired, instead of by its last sign of life.
    var replay: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool { sizeClass != .regular }

    var body: some View {
        let nodes = layout()
        let edges = handoffEdges(nodes: nodes)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, nodes: nodes, edges: edges, now: timeline.date)
            }
        }
        .aspectRatio(compact ? 0.82 : 1.55, contentMode: .fit)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Space.radius, style: .continuous).strokeBorder(Palette.rule, lineWidth: 0.5)
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear.contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        select(at: value.location, size: proxy.size, nodes: nodes)
                    })
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary(nodes: nodes))
        .accessibilityChildren {
            // One element per agent for VoiceOver: towns west to east, then the region, the desks; each selectable.
            ForEach(NewsroomLayout.spokenOrder(nodes)) { node in
                Rectangle()
                    .accessibilityLabel(NewsroomLayout.spoken(node, agent: model.agent(node.id), now: Date()))
                    .accessibilityAddTraits(selected == node.id ? [.isButton, .isSelected] : [.isButton])
                    .accessibilityAction { selected = node.id }
            }
        }
    }

    // MARK: Model

    private func layout() -> [NewsroomLayout.Node] {
        guard let dashboard = model.dashboard else { return [] }
        return NewsroomLayout.nodes(roles: dashboard.agents.map(\.role),
                                    handoffs: dashboard.handoffs.map { (from: $0.from, to: $0.to) })
    }

    struct Edge: Identifiable {
        var id: String { from + ">" + to }
        let from: String
        let to: String
        let n: Int
    }

    private func handoffEdges(nodes: [NewsroomLayout.Node]) -> [Edge] {
        guard let dashboard = model.dashboard else { return [] }
        let roles = Set(dashboard.agents.map(\.role))
        return dashboard.handoffs.map {
            Edge(from: NewsroomLayout.nodeID(for: $0.from, roles: roles), to: NewsroomLayout.nodeID(for: $0.to, roles: roles), n: $0.n)
        }
    }

    private func radius(_ node: NewsroomLayout.Node) -> CGFloat {
        let scale: CGFloat = compact ? 0.85 : 1.15
        switch node.kind {
        case .country: return 9 * scale
        case .region: return 11 * scale
        case .town:
            let stories = node.placeID.flatMap { model.places[$0]?.aiNews.count } ?? 0
            return (5 + min(7, sqrt(CGFloat(stories)) * 1.6)) * scale
        case .placeDesk: return 6 * scale
        case .desk: return 4 * scale
        case .outside: return 5 * scale
        }
    }

    private func fill(_ node: NewsroomLayout.Node) -> Color {
        if let id = node.placeID, let accent = model.places[id]?.look?.accent { return Color(hex: accent) }
        if node.kind == .outside { return Palette.card }
        guard let agent = model.agent(node.id) else { return Palette.muted }
        return StatusDot(status: agent.status).color
    }

    private func ring(_ node: NewsroomLayout.Node) -> Color {
        guard let agent = model.agent(node.id) else { return Palette.muted }
        return StatusDot(status: agent.status).color
    }

    private func dimmed(_ node: NewsroomLayout.Node) -> Bool {
        guard let agent = model.agent(node.id) else { return false }
        return agent.status == .stale || agent.status == .stopped
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, nodes: [NewsroomLayout.Node], edges: [Edge], now: Date) {
        guard !nodes.isEmpty else { return }
        let inset: CGFloat = 14
        let box = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        func at(_ p: CGPoint) -> CGPoint { CGPoint(x: box.minX + p.x * box.width, y: box.minY + p.y * box.height) }
        let byID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let t = now.timeIntervalSinceReferenceDate

        // The town band and the two desk areas, named.
        let band = NewsroomLayout.townBand.insetBy(dx: -0.04, dy: -0.06)
        let bandRect = CGRect(x: box.minX + band.minX * box.width, y: box.minY + band.minY * box.height,
                              width: band.width * box.width, height: band.height * box.height)
        context.fill(Path(roundedRect: bandRect, cornerRadius: 18), with: .color(Palette.paper2.opacity(0.7)))
        let captionFont = Font.system(size: compact ? 8 : 10, weight: .semibold)
        context.draw(Text("THE TOWNS · WEST TO EAST").font(captionFont).foregroundStyle(Palette.muted),
                     at: CGPoint(x: bandRect.minX + 8, y: bandRect.minY + 8), anchor: .topLeading)
        context.draw(Text("THE DESKS").font(captionFont).foregroundStyle(Palette.muted),
                     at: at(CGPoint(x: 0.0, y: 0.71)), anchor: .leading)

        // The places' own hierarchy (each site's `parent`): Portugal over the Algarve over its towns. Hairlines only.
        if let region = nodes.first(where: { $0.kind == .region }) {
            var spokes = Path()
            for town in nodes where town.kind == .town {
                spokes.move(to: at(region.point))
                spokes.addLine(to: at(town.point))
            }
            if let country = nodes.first(where: { $0.kind == .country }) {
                spokes.move(to: at(country.point))
                spokes.addLine(to: at(region.point))
            }
            context.stroke(spokes, with: .color(Palette.rule.opacity(0.7)), lineWidth: 0.5)
        }

        // Handoffs: a curve per pair, particles flowing from sender to receiver, more for more handoffs.
        for edge in edges {
            guard let a = byID[edge.from], let b = byID[edge.to] else { continue }
            let pa = at(a.point), pb = at(b.point)
            var curve = Path()
            curve.move(to: pa)
            curve.addQuadCurve(to: pb, control: NewsroomLayout.controlPoint(from: pa, to: pb))
            let hot = model.changedAt[a.id].map { now.timeIntervalSince($0) < 120 } ?? false
            let color = hot ? Palette.sun : Palette.blue
            context.stroke(curve, with: .color(color.opacity(0.35)), lineWidth: 1 + CGFloat(log2(Double(max(1, edge.n)))))
            let count = min(2 + edge.n, 8)
            if reduceMotion {
                let mid = NewsroomLayout.curvePoint(from: pa, to: pb, t: 0.55)
                context.fill(Path(ellipseIn: CGRect(x: mid.x - 3, y: mid.y - 3, width: 6, height: 6)), with: .color(color))
            } else {
                for i in 0..<count {
                    let phase = (t * 0.22 + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
                    let p = NewsroomLayout.curvePoint(from: pa, to: pb, t: phase)
                    let r: CGFloat = 2.6
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                                 with: .color(color.opacity(0.4 + 0.6 * sin(.pi * phase))))
                }
            }
        }

        // Nodes, back to front: pulse, body, ring, label.
        for node in nodes {
            let p = at(node.point)
            let r = radius(node)
            let activity = lit(node.id, now: now)
            let seed = Double(abs(node.id.hashValue % 1000)) / 1000
            let dim = dimmed(node)

            if highlighted.contains(node.id) {
                let halo = r + 9
                context.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                             with: .color(Palette.sun.opacity(0.55)))
            }
            if activity > 0 {
                let color = ring(node)
                if reduceMotion {
                    let halo = r + 5
                    context.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                                 with: .color(color.opacity(0.25 * activity)))
                } else {
                    for k in 0..<2 {
                        let phase = (t / 2.4 + seed + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                        let pr = r + CGFloat(phase) * CGFloat(8 + 14 * activity)
                        context.stroke(Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr, width: pr * 2, height: pr * 2)),
                                       with: .color(color.opacity((1 - phase) * 0.7 * activity)), lineWidth: 1.5)
                    }
                }
            }
            // A spark for two minutes after a change was seen here.
            if let changed = model.changedAt[node.id], now.timeIntervalSince(changed) < 120 {
                let age = now.timeIntervalSince(changed) / 120
                let grow: CGFloat = reduceMotion ? 4 : CGFloat((t * 1.5).truncatingRemainder(dividingBy: 1)) * 10
                let sr: CGFloat = r + 4 + grow
                context.stroke(Path(ellipseIn: CGRect(x: p.x - sr, y: p.y - sr, width: sr * 2, height: sr * 2)),
                               with: .color(Palette.sun.opacity(1 - age)), lineWidth: 2.5)
            }

            let body = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            var layer = context
            layer.opacity = dim ? 0.4 : 1
            if node.kind == .outside {
                layer.fill(body, with: .color(Palette.card))
                layer.stroke(body, with: .color(Palette.muted), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                let live = node.placeID.flatMap { model.places[$0]?.isLive } ?? true
                layer.fill(body, with: .color(live ? fill(node) : Palette.card))
                layer.stroke(body, with: .color(node.kind == .town ? fill(node) : ring(node)), lineWidth: node.kind == .town ? 2 : 1)
                if node.kind == .town || node.kind == .region || node.kind == .country {
                    let dot = r * 0.38
                    layer.fill(Path(ellipseIn: CGRect(x: p.x + r * 0.55 - dot / 2, y: p.y - r * 0.85 - dot / 2, width: dot, height: dot)),
                               with: .color(ring(node)))
                }
            }
            if selected == node.id {
                let sr = r + 3
                context.stroke(Path(ellipseIn: CGRect(x: p.x - sr, y: p.y - sr, width: sr * 2, height: sr * 2)),
                               with: .color(Palette.ink), lineWidth: 2)
            }

            if showsLabel(node, activity: activity) {
                let size: CGFloat = compact ? 8 : 10
                let weight: Font.Weight = node.kind == .town || node.kind == .region ? .semibold : .regular
                let label = Text(node.label).font(.system(size: size, weight: weight))
                    .foregroundStyle(node.kind == .outside ? Palette.muted : Palette.ink)
                var labelLayer = context
                labelLayer.opacity = dim ? 0.55 : 1
                // Towns in the upper half of their band take their name above, the rest below, so neighbours
                // along the coast do not write over each other.
                let band = NewsroomLayout.townBand
                let above = node.kind == .town && node.point.y < band.midY
                if above {
                    labelLayer.draw(label, at: CGPoint(x: p.x, y: p.y - r - 2), anchor: .bottom)
                } else {
                    labelLayer.draw(label, at: CGPoint(x: p.x, y: p.y + r + 2), anchor: .top)
                }
            }
        }
    }

    private func lit(_ role: String, now: Date) -> Double {
        guard let replay else { return model.activity(role, now: now) }
        return LiveReplay.activity(fired: model.extras?.agents[role]?.fired ?? [], at: replay)
    }

    private func showsLabel(_ node: NewsroomLayout.Node, activity: Double) -> Bool {
        if selected == node.id || highlighted.contains(node.id) { return true }
        switch node.kind {
        case .region, .country, .outside, .placeDesk: return true
        case .town:
            // On a phone 17 names do not fit side by side: name the live sites and the busy agents; tap for the rest.
            let live = node.placeID.flatMap { model.places[$0]?.isLive } ?? false
            return !compact || live || activity > 0.5
        case .desk: return !compact || activity > 0.05
        }
    }

    private func select(at location: CGPoint, size: CGSize, nodes: [NewsroomLayout.Node]) {
        let inset: CGFloat = 14
        let box = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let nearest = nodes.min { a, b in
            distance(a.point, location, box) < distance(b.point, location, box)
        }
        guard let nearest, distance(nearest.point, location, box) < 28, nearest.kind != .outside else {
            selected = nil
            return
        }
        selected = selected == nearest.id ? nil : nearest.id
    }

    private func distance(_ unit: CGPoint, _ location: CGPoint, _ box: CGRect) -> CGFloat {
        let p = CGPoint(x: box.minX + unit.x * box.width, y: box.minY + unit.y * box.height)
        return hypot(p.x - location.x, p.y - location.y)
    }

    private func accessibilitySummary(nodes: [NewsroomLayout.Node]) -> String {
        let now = Date()
        let active = nodes.filter { lit($0.id, now: now) > 0 }.count
        return "The newsroom board: \(nodes.count) agents, \(active) active in the last half hour, \(model.dashboard?.handoffs.count ?? 0) handoff routes."
    }
}

/// What the board's marks mean.
struct NewsroomBoardLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.m) { items }
            VStack(alignment: .leading, spacing: 4) { items }
        }
        .font(.caption2)
        .foregroundStyle(Palette.muted)
    }

    @ViewBuilder private var items: some View {
        LegendItem(color: Palette.green, ring: true, text: "Pulse: a sign of life in the last 30 min")
        LegendItem(color: Palette.sun, ring: true, text: "Spark: changed while you watch")
        LegendItem(color: Palette.blue, ring: false, text: "Particles: handoffs, last 24 h")
        LegendItem(color: Palette.muted, ring: false, text: "Faded: quiet or stopped")
    }
}

private struct LegendItem: View {
    let color: Color
    let ring: Bool
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            if ring { Circle().strokeBorder(color, lineWidth: 2).frame(width: 10, height: 10) }
            else { Circle().fill(color).frame(width: 8, height: 8) }
            Text(text)
        }
    }
}
