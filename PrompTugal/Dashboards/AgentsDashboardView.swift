import Charts
import SwiftUI

/// What the agents are doing: the wake grid for the last 24 hours, the runs over
/// time, every agent's last wake, and who hands work to whom.
/// From promptugal.news/api/v1/newsroom/{dashboard,status}.json.
struct AgentsDashboardView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @State private var mineOnly = false
    @State private var query = ""

    private var dashboard: Wire.NewsroomDashboard? { data.dashboard.value }
    private var status: Wire.NewsroomStatus? { data.status.value }

    private func isMine(_ agent: Wire.DashAgent) -> Bool {
        guard !me.isEmpty, let name = agent.agent?.lowercased() else { return false }
        return name.hasSuffix(".\(me.lowercased())")
    }

    private var agents: [Wire.DashAgent] {
        (dashboard?.agents ?? [])
            .filter { !mineOnly || isMine($0) }
            .filter { query.isEmpty || ($0.agent ?? "").localizedStandardContains(query)
                || ($0.focus ?? "").localizedStandardContains(query) }
    }

    var body: some View {
        Page {
            ScreenHeader(kicker: "Agents", title: "What the agents are doing",
                         summary: "Every newsroom agent: when it fires, what each wake did, and what it asks for.")
            HStack {
                FreshnessLabel(updated: dashboard?.date ?? data.dashboard.updated, failed: data.dashboard.failed)
                Spacer()
                if !me.isEmpty { Toggle("Mine only", isOn: $mineOnly).fixedSize() }
            }
            if dashboard == nil {
                StateView(phase: data.dashboard.phase, hasData: false, title: "agents") {
                    Task { await data.refreshNewsroom(force: true) }
                }
            } else {
                counts
                TitledCard("Where they fire", kicker: "Last 24 hours, UTC") {
                    WakeGrid(agents: agents, hours: dashboard?.gridHours ?? [], highlight: isMine)
                }
                Columns {
                    RunsChart(runs: status?.runs ?? [])
                    HandoffChart(handoffs: dashboard?.handoffs ?? [])
                } trailing: {
                    TitledCard("Latest runs", kicker: "\(status?.runs?.count ?? 0) recorded") {
                        ForEach((status?.runs ?? []).prefix(12)) { run in
                            InfoRow(title: run.what ?? run.id, detail: [run.by, run.kind].compactMap { $0 }.joined(separator: " · "),
                                    date: run.date, symbol: run.kind == "desk" ? "tray.full" : "arrow.triangle.branch",
                                    tint: Palette.stable(run.kind ?? ""))
                        }
                    }
                }
                TitledCard("Every agent", kicker: "\(agents.count) shown") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Space.m)], spacing: Space.m) {
                        ForEach(agents) { AgentWakeDetail(agent: $0) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Find an agent")
        .navigationTitle("Agents")
        .refreshable { await data.refreshNewsroom(force: true) }
        .task { await data.refreshNewsroom() }
        .webTwin(FeedClient.site.appendingPathComponent("newsroom/dashboard/"), title: "Newsroom dashboard")
    }

    private var counts: some View {
        let all = dashboard?.agents ?? []
        let cells = all.flatMap(\.cells)
        let wakeKinds: Set<WakeCell> = [.ok, .partial, .idle, .failed]
        let wakes = cells.filter { wakeKinds.contains($0) }.count
        let good = cells.filter { $0 == .ok }.count
        return StatGrid {
            StatTile(label: "Agents", value: "\(all.count)", detail: "\(status?.counts?["agents_running"] ?? 0) running")
            StatTile(label: "Wakes, 24 h", value: "\(wakes)", detail: wakes > 0 ? "\(good * 100 / max(wakes, 1))% went well" : nil,
                     tone: .good)
            StatTile(label: "Failed, 24 h", value: "\(cells.filter { $0 == .failed }.count)",
                     tone: cells.contains(.failed) ? .bad : .good)
            StatTile(label: "Stale agents", value: "\(all.filter { $0.stale == true }.count)", tone: .warn)
            StatTile(label: "Asks for a person", value: "\(dashboard?.asks?.count ?? 0)", tone: .warn)
        }
    }
}

/// Runs per hour, coloured by kind.
struct RunsChart: View {
    let runs: [Wire.Run]

    var body: some View {
        let dated = runs.filter { $0.date != nil }
        TitledCard("Runs over time", kicker: "Commits and desk reports") {
            if dated.isEmpty {
                Text("No dated runs in the feed.").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Chart(dated) { run in
                    BarMark(x: .value("Hour", run.date ?? .now, unit: .hour), y: .value("Runs", 1))
                        .foregroundStyle(by: .value("Kind", run.kind ?? "other"))
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 180)
            }
        }
    }
}

/// Who hands work to whom: the top pairs.
struct HandoffChart: View {
    let handoffs: [Wire.Handoff]

    var body: some View {
        let top = handoffs.sorted { ($0.n ?? 0) > ($1.n ?? 0) }.prefix(10)
        TitledCard("Hand-offs", kicker: "Who hands work to whom") {
            if top.isEmpty {
                Text("No hand-offs in the feed.").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Chart(Array(top.enumerated()), id: \.offset) { item in
                    BarMark(x: .value("Hand-offs", item.element.n ?? 0),
                            y: .value("Pair", "\(item.element.from ?? "?") → \(item.element.to ?? "?")"))
                        .foregroundStyle(Palette.stable(item.element.from ?? ""))
                        .annotation(position: .trailing) {
                            Text("\(item.element.n ?? 0)").font(.caption2).foregroundStyle(Palette.muted)
                        }
                }
                .frame(height: CGFloat(top.count) * 28 + 20)
            }
        }
    }
}

#Preview("Agents") {
    NavigationStack { AgentsDashboardView() }.environment(PreviewSamples.data())
}
