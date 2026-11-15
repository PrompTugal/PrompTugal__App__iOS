import PTCore
import SwiftUI

/// The agents behind a place, from a conductor-report/v1: a small network of who works with whom, then a card
/// per agent with its face, what it is doing, what it waits for, and what it has done. Drawn only from the record.
struct AgentsPanel: View {
    let report: AgentsReport
    let accent: Color
    let placeAgent: String
    @Environment(\.horizontalSizeClass) private var width

    private var ordered: [ReportAgent] {
        report.agents.sorted { a, b in rank(a) < rank(b) }
    }

    private func rank(_ agent: ReportAgent) -> Int {
        if agent.id == placeAgent { return 0 }
        if agent.newsroomRole == "regional" { return 1 }
        return 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            summary
            AgentsNetwork(agents: ordered, links: report.links, accent: accent)
                .frame(height: width == .regular ? 300 : 240)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
            let columns = [GridItem(.adaptive(minimum: width == .regular ? 320 : 280), spacing: Space.m)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.m) {
                ForEach(ordered) { agent in
                    AgentCard(agent: agent, accent: accent, lead: agent.id == placeAgent)
                }
            }
        }
        .accessibilityIdentifier("places.agents")
    }

    private var summary: some View {
        let counts = Dictionary(grouping: report.agents, by: \.status).mapValues(\.count)
        return HStack(spacing: Space.l) {
            BigNumber(value: report.agents.count, label: String(localized: "agents"), accent: accent)
            ForEach(["working", "waiting", "blocked", "done"], id: \.self) { status in
                if let n = counts[status], n > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(AgentFace.color(status)).frame(width: 8, height: 8)
                        Text("\(n) \(status)").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
    }
}

/// Who works with whom: the place agent in the middle, the regional agent above, the shared team around.
struct AgentsNetwork: View {
    let agents: [ReportAgent]
    let links: [ReportLink]
    let accent: Color
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let positions = Self.positions(agents, in: geo.size)
            ZStack {
                Canvas { context, _ in
                    for link in links {
                        guard let a = positions[link.from], let b = positions[link.to] else { continue }
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        context.stroke(path, with: .color(accent.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                }
                ForEach(links, id: \.self) { link in
                    if let a = positions[link.from], let b = positions[link.to] {
                        Text(link.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 4)
                            .background(Palette.card.opacity(0.9), in: Capsule())
                            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    }
                }
                ForEach(agents) { agent in
                    if let p = positions[agent.id] {
                        VStack(spacing: 2) {
                            AgentFace(agent: agent, size: agent.newsroomRole == "place" ? 52 : 36)
                                .scaleEffect(agent.status == "working" && pulse ? 1.06 : 1)
                            Text(agent.name.replacingOccurrences(of: "place.", with: ""))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        .position(p)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// The place agent at the centre, the regional one above it, the rest on an arc below. Pure.
    static func positions(_ agents: [ReportAgent], in size: CGSize) -> [String: CGPoint] {
        var out: [String: CGPoint] = [:]
        let mid = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let others = agents.filter { $0.newsroomRole != "place" && $0.newsroomRole != "regional" }
        for agent in agents {
            if agent.newsroomRole == "place" { out[agent.id] = mid }
            if agent.newsroomRole == "regional" { out[agent.id] = CGPoint(x: mid.x, y: size.height * 0.12) }
        }
        let rx = size.width / 2 - 44, ry = size.height * 0.42
        for (i, agent) in others.enumerated() {
            let t = others.count == 1 ? 0.5 : Double(i) / Double(others.count - 1)
            let angle = Double.pi * (0.05 + 0.9 * t) // left to right along the lower arc
            out[agent.id] = CGPoint(x: mid.x - rx * cos(angle), y: mid.y + ry * sin(angle) * 0.95)
        }
        return out
    }
}

struct AgentCard: View {
    let agent: ReportAgent
    let accent: Color
    let lead: Bool
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.m) {
                AgentFace(agent: agent, size: lead ? 52 : 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.id).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text(agent.role).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(agent.status.capitalized)
                    .font(.caption2.weight(.bold)).textCase(.uppercase)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AgentFace.color(agent.status).opacity(0.15), in: Capsule())
                    .foregroundStyle(AgentFace.color(agent.status))
                if let last = agent.lastActive, !last.isEmpty {
                    Text(PlaceDates.ago(last)).font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            if !agent.doing.isEmpty {
                Text(agent.doing).font(.footnote).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            if let waiting = agent.waitingFor, !waiting.isEmpty {
                Label {
                    Text(waiting).font(.caption).foregroundStyle(Palette.ink).lineLimit(expanded ? nil : 3)
                } icon: {
                    Image(systemName: "hand.raised.fill").foregroundStyle(Palette.amber)
                }
            }
            let done = agent.done ?? []
            let next = agent.next ?? []
            if !done.isEmpty || !next.isEmpty {
                DisclosureGroup(isExpanded: $expanded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(done.enumerated()), id: \.offset) { _, line in
                            Label { Text(line).font(.caption) } icon: { Image(systemName: "checkmark").foregroundStyle(Palette.green) }
                        }
                        ForEach(Array(next.enumerated()), id: \.offset) { _, line in
                            Label { Text(line).font(.caption) } icon: { Image(systemName: "arrow.right").foregroundStyle(accent) }
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
                } label: {
                    Text(String(localized: "\(done.count) done · \(next.count) next")).font(.caption.weight(.semibold)).foregroundStyle(accent)
                }
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).stroke(lead ? accent : Palette.rule, lineWidth: lead ? 2 : 0.5))
    }
}
