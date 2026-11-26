import PTCore
import SwiftUI

/// A place's AI map drawn as connections: the place at the centre, each entity on a ring set by its steps from AI
/// (inner ring: AI itself), coloured by kind. Tap a node to read what it is and why it is on the map.
struct ConnectionsGraph: View {
    let center: String
    let entries: [MapEntry]
    let accent: Color
    @State private var selected: MapEntry?
    @State private var appeared = false

    static func symbol(_ type: String) -> String { PlaceKind.of(type).symbol }

    static func color(_ type: String, accent: Color) -> Color {
        switch PlaceKind.of(type) {
        case .government: accent
        case .companies: Palette.blue
        case .startups: Palette.series(4)
        case .investors: Palette.amber
        case .research: Palette.green
        case .community: Palette.series(5)
        case .talent: Palette.red
        case .other: Palette.muted
        }
    }

    /// Where each entry sits, as a fraction of the radius and an angle. Pure, so the layout is stable and tested.
    static func layout(_ entries: [MapEntry]) -> [(entry: MapEntry, ring: Int, angle: Double)] {
        let rings = Dictionary(grouping: entries) { min(max($0.steps ?? 2, 0), 2) }
        var out: [(entry: MapEntry, ring: Int, angle: Double)] = []
        for ring in 0...2 {
            let members = rings[ring] ?? []
            for (i, entry) in members.enumerated() {
                let offset = Double(ring) * 0.6
                let angle = offset + Double(i) / Double(max(members.count, 1)) * 2 * .pi
                out.append((entry, ring, angle))
            }
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 36
            let nodes = Self.layout(entries)
            let fractions: [CGFloat] = [0.38, 0.7, 0.98]
            let point: (Int, Double) -> CGPoint = { ring, angle in
                let r = radius * fractions[ring] * (appeared ? 1 : 0.2)
                return CGPoint(x: mid.x + r * cos(angle), y: mid.y + r * sin(angle))
            }
            ZStack {
                // Rings and their labels.
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(accent.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: radius * fractions[ring] * 2, height: radius * fractions[ring] * 2)
                        .position(mid)
                }
                // The connections.
                Canvas { context, _ in
                    for node in nodes {
                        var path = Path()
                        path.move(to: mid)
                        let p = point(node.ring, node.angle)
                        let control = CGPoint(x: (mid.x + p.x) / 2 + (p.y - mid.y) * 0.15, y: (mid.y + p.y) / 2 - (p.x - mid.x) * 0.15)
                        path.addQuadCurve(to: p, control: control)
                        let isSelected = selected?.id == node.entry.id
                        context.stroke(path, with: .color(Self.color(node.entry.type, accent: accent).opacity(isSelected ? 0.9 : 0.4)),
                                       lineWidth: isSelected ? 3 : CGFloat(3 - node.ring))
                    }
                }
                // The place.
                VStack(spacing: 2) {
                    Text(center).font(.system(.headline, design: .serif, weight: .black)).foregroundStyle(.white)
                    Text(String(localized: "\(entries.count) on the map", bundle: .module)).font(.caption2).foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(accent.gradient, in: Capsule())
                .shadow(color: accent.opacity(0.4), radius: 10)
                .position(mid)
                // The entities.
                ForEach(nodes, id: \.entry.id) { node in
                    Button {
                        withAnimation(.snappy) { selected = selected?.id == node.entry.id ? nil : node.entry }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: Self.symbol(node.entry.type))
                                .font(.system(size: node.ring == 0 ? 16 : 13))
                                .foregroundStyle(.white)
                                .frame(width: node.ring == 0 ? 36 : 30, height: node.ring == 0 ? 36 : 30)
                                .background(Self.color(node.entry.type, accent: accent), in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: selected?.id == node.entry.id ? 3 : 1.5))
                            Text(shortName(node.entry.name))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 84)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point(node.ring, node.angle))
                    .accessibilityLabel(Text("\(node.entry.name), \(node.entry.type)"))
                }
            }
            .overlay(alignment: .bottom) {
                if let selected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.name).font(.headline)
                        if !selected.what.isEmpty { Text(selected.what).font(.caption).lineLimit(3) }
                        StepsBadge(steps: selected.steps, accent: accent)
                    }
                    .padding(Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(Space.m)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) { legend.padding(Space.m) }
        }
        .onAppear { withAnimation(.spring(duration: 0.9)) { appeared = true } }
        .accessibilityIdentifier("places.graph")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Inner ring: AI itself", bundle: .module)).font(.caption2)
            Text(String(localized: "Outer rings: one, two steps away", bundle: .module)).font(.caption2)
        }
        .foregroundStyle(Palette.muted)
    }

    private func shortName(_ name: String) -> String {
        // "Universidade do Algarve (UAlg)" reads as "UAlg" on the graph.
        if let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), open < close {
            let inner = name[name.index(after: open)..<close]
            if inner.count <= 14 { return String(inner) }
        }
        return name.count > 26 ? String(name.prefix(24)) + "…" : name
    }
}
