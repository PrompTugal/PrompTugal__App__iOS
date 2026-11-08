import SwiftUI

// Shared pieces for the dashboards: avatars, the wake grid, rows.

/// A person's initials on their own colour from the team site.
struct Avatar: View {
    let initials: String
    let colour: Color
    var size: CGFloat = 40
    /// Grows with Dynamic Type, so the initials stay readable at large text sizes.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(colour)
            .frame(width: size * scale, height: size * scale)
            .overlay(Text(initials).font(.system(size: size * scale * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

extension Wire.Person {
    var tint: Color { Color(hex: colour) }
}

/// The agents' last 24 hours, one row per agent and one column per hour,
/// redrawn natively from the newsroom dashboard's wake grid.
struct WakeGrid: View {
    let agents: [Wire.DashAgent]
    let hours: [String]
    var highlight: (Wire.DashAgent) -> Bool = { _ in false }
    @State private var selected: Wire.DashAgent.ID?
    @Environment(\.horizontalSizeClass) private var width

    private let rowHeight: CGFloat = 18
    /// Narrower names on iPhone, so the 24 hour columns keep a usable width.
    private var labelWidth: CGFloat { width == .compact ? 78 : 130 }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            GeometryReader { geo in
                let columns = max(hours.count, 1)
                let cell = (geo.size.width - labelWidth) / CGFloat(columns)
                Canvas { context, size in
                    // Hour labels every three hours.
                    for (index, hour) in hours.enumerated() where index % 3 == 0 {
                        let x = labelWidth + CGFloat(index) * cell + cell / 2
                        context.draw(Text(hour).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted),
                                     at: CGPoint(x: x, y: 7))
                    }
                    for (row, agent) in agents.enumerated() {
                        let y = 18 + CGFloat(row) * rowHeight
                        if highlight(agent) || agent.id == selected {
                            context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight)),
                                         with: .color(Palette.red.opacity(0.08)))
                        }
                        context.draw(Text(agent.shortName).font(.caption2).foregroundStyle(agent.stale == true ? Palette.muted : Palette.ink),
                                     at: CGPoint(x: 2, y: y + rowHeight / 2), anchor: .leading)
                        for (column, state) in agent.cells.prefix(columns).enumerated() {
                            let center = CGPoint(x: labelWidth + CGFloat(column) * cell + cell / 2, y: y + rowHeight / 2)
                            Self.draw(state, at: center, radius: min(cell, rowHeight) * 0.36, in: &context)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    guard let row = Self.row(at: tap.location.y, header: 18, rowHeight: rowHeight, count: agents.count)
                    else { return }
                    selected = agents[row].id == selected ? nil : agents[row].id
                })
            }
            .frame(height: 18 + CGFloat(agents.count) * rowHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)

            legend
            if let selected, let agent = agents.first(where: { $0.id == selected }) {
                AgentWakeDetail(agent: agent)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Space.m) {
            ForEach(WakeCell.legend, id: \.self) { state in
                HStack(spacing: 4) {
                    Canvas { context, size in
                        Self.draw(state, at: CGPoint(x: size.width / 2, y: size.height / 2), radius: 4.5, in: &context)
                    }
                    .frame(width: 12, height: 12)
                    Text(state.label).font(.caption2).foregroundStyle(Palette.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var accessibilitySummary: String {
        let ok = agents.reduce(0) { $0 + $1.cells.filter { $0 == .ok }.count }
        let partial = agents.reduce(0) { $0 + $1.cells.filter { $0 == .partial }.count }
        let failed = agents.reduce(0) { $0 + $1.cells.filter { $0 == .failed }.count }
        return "Wake grid for \(agents.count) agents over 24 hours: \(ok) good wakes, \(partial) partial, \(failed) failed."
    }

    /// The agent row under a tap, or nil for the hour header above the rows and the space below them.
    static func row(at y: CGFloat, header: CGFloat, rowHeight: CGFloat, count: Int) -> Int? {
        guard y >= header, rowHeight > 0 else { return nil }
        let row = Int((y - header) / rowHeight)
        return row < count ? row : nil
    }

    static func draw(_ state: WakeCell, at center: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        switch state {
        case .ok:
            context.fill(circle, with: .color(Palette.green))
        case .partial:
            context.stroke(circle, with: .color(Palette.amber), lineWidth: 1.2)
            var half = Path()
            half.addArc(center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            half.closeSubpath()
            context.fill(half, with: .color(Palette.amber))
        case .idle:
            context.stroke(circle, with: .color(Palette.muted), lineWidth: 1.2)
        case .failed:
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - radius, y: center.y - radius))
            cross.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius))
            cross.move(to: CGPoint(x: center.x + radius, y: center.y - radius))
            cross.addLine(to: CGPoint(x: center.x - radius, y: center.y + radius))
            context.stroke(cross, with: .color(Palette.red), lineWidth: 1.8)
        case .held:
            context.fill(Path(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(Palette.blue))
        case .commit:
            let dot = radius * 0.45
            context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(Palette.ink))
        case .none:
            let dot = radius * 0.18
            context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(Palette.rule))
        }
    }
}

/// What one agent last did, what it does next, and what it asks for.
struct AgentWakeDetail: View {
    let agent: Wire.DashAgent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(agent.agent ?? agent.shortName).font(.subheadline.weight(.semibold))
                Spacer()
                if let minute = agent.minute { Text(":\(String(format: "%02d", minute))").font(Typo.data).foregroundStyle(Palette.muted) }
            }
            if let focus = agent.focus { Text(focus).font(.footnote).foregroundStyle(Palette.muted) }
            if let state = agent.state { Label(state, systemImage: "bolt.horizontal").font(.footnote) }
            if let wake = agent.lastWake {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Last wake").font(.caption.weight(.semibold))
                        if let outcome = wake.outcome { Text(outcome).font(.caption).foregroundStyle(outcome == "ok" ? Palette.green : Palette.amber) }
                        if let date = wake.date { Text(date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(Palette.muted) }
                    }
                    if let line = wake.line { Text(line).font(.footnote) }
                }
            }
            bullets("Next", agent.next)
            bullets("Asks", agent.asks)
        }
        .padding(Space.m)
        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder private func bullets(_ title: String, _ items: [LooseText]?) -> some View {
        if let items, !items.isEmpty {
            Text(title).font(.caption.weight(.semibold))
            ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                Text("• " + (item.who.map { "\($0): " } ?? "") + item.text).font(.footnote).lineLimit(3)
            }
        }
    }
}

/// A list row for something with a title, a line of detail and a time.
struct InfoRow: View {
    let title: String
    var detail: String?
    var date: Date?
    var symbol: String?
    var tint: Color = Palette.muted

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(Palette.ink)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Palette.muted).lineLimit(3)
                }
            }
            Spacer(minLength: Space.s)
            if let date {
                Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

/// Opens a page from a dashboard: a navigation link to the in-app web page.
struct WebLinkRow: View {
    let title: String
    let url: URL
    var symbol = "arrow.up.right.square"

    var body: some View {
        NavigationLink {
            WebPage(url: url, title: title)
        } label: {
            Label(title, systemImage: symbol).font(.subheadline)
        }
    }
}
