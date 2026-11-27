import PTCore
import SwiftUI

/// The newsroom's command centre, read-only: who the agents are, what each says it is doing, its last wake and next
/// step, what waits on a person, and who hands work to whom. From promptugal.news/api/v1/newsroom/dashboard.json.
/// Nothing here acts on an agent. The one simulated part, the city newsroom's flow, is marked "Simulated".
public struct NewsroomCentreView: View {
    @State private var store = LocalStore.shared
    @State private var group: Filter = .places
    @State private var query = ""

    enum Filter: String, CaseIterable, Identifiable {
        case places = "Places", newsroom = "Newsroom", all = "All"
        var id: Self { self }
        var title: String {
            switch self {
            case .places: LocalText.string("Places")
            case .newsroom: LocalText.string("Newsroom")
            case .all: LocalText.string("All")
            }
        }
    }

    public init() {}

    private var dashboard: NewsroomDashboard? { store.dashboard }

    private var agents: [NewsroomDashboard.Agent] {
        (dashboard?.agents ?? [])
            .filter { agent in
                switch group {
                case .places: agent.group == .places
                case .newsroom: agent.group == .newsroom
                case .all: true
                }
            }
            .filter { query.isEmpty || $0.agent.localizedStandardContains(query) || ($0.focus ?? "").localizedStandardContains(query) }
            .sorted { a, b in
                let ra = rank(a.status), rb = rank(b.status)
                return ra != rb ? ra < rb : a.agent < b.agent
            }
    }

    private func rank(_ status: NewsroomDashboard.Status) -> Int {
        NewsroomDashboard.Status.allCases.firstIndex(of: status) ?? 9
    }

    public var body: some View {
        Page {
            ScreenHeader(kicker: LocalText.string("Command centre"), title: LocalText.string("The newsroom"),
                         summary: LocalText.string("Every agent behind PrompTugal.news: what it is doing, what it did last, what it needs. Read-only."))
            HStack {
                ProvenanceLabel(provenance: store.dashboardProvenance, phase: store.dashboardPhase,
                                readAt: dashboard?.updated)
                Spacer()
                if let built = dashboard?.built { Text(LocalText.string("site \(String(describing: built))")).font(.caption.monospaced()).foregroundStyle(Palette.muted) }
            }
            if let dashboard {
                NavigationLink {
                    NewsroomLiveView()
                } label: {
                    Card {
                        Label(LocalText.string("Watch the newsroom in action"), systemImage: "waveform.path.ecg").font(.headline)
                        Text(LocalText.string("The agents on a live board: pulses when one wakes, handoffs in flight, the latest changes as they land."))
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                .buttonStyle(.plain)
                tiles(dashboard)
                CityNewsroomFlow(store: store)
                Picker(LocalText.string("Agents"), selection: $group) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                TitledCard(LocalText.string("The agents"), kicker: LocalText.string("\(String(describing: agents.count)) shown")) {
                    Text(LocalText.string("Status is read from what each agent writes about itself on the dashboard."))
                        .font(.caption).foregroundStyle(Palette.muted)
                    ForEach(agents) { agent in
                        NavigationLink {
                            AgentDetailView(agent: agent)
                        } label: {
                            AgentRow(agent: agent)
                        }
                        .buttonStyle(.plain)
                        if agent != agents.last { Divider() }
                    }
                }
                Columns {
                    if !dashboard.asks.isEmpty {
                        TitledCard(LocalText.string("Waiting on a person"), kicker: LocalText.string("\(String(describing: dashboard.asks.count)) asks")) {
                            ForEach(dashboard.asks.prefix(12)) { ask in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ask.ask ?? "").font(.footnote).lineLimit(4)
                                    Text([ask.from, ask.since.map { LocalText.string("since \(String(describing: $0))") }].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption2).foregroundStyle(Palette.muted)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } trailing: {
                    if !dashboard.handoffs.isEmpty {
                        TitledCard(LocalText.string("Who hands work to whom"), kicker: LocalText.string("Last 24 hours")) {
                            ForEach(dashboard.handoffs) { handoff in
                                HStack {
                                    Text(handoff.from).font(.footnote.weight(.medium))
                                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(Palette.muted)
                                    Text(handoff.to).font(.footnote.weight(.medium))
                                    Spacer()
                                    CountPill(count: handoff.n, label: handoff.n == 1 ? "handoff" : "handoffs", color: Palette.blue)
                                }
                            }
                        }
                    }
                }
                GapNote(title: LocalText.string("Read-only, and only the public newsroom"),
                        text: LocalText.string("This shows the agents PrompTugal.news publishes. Connecting your own conductor, to see every session of yours, comes next; nothing here can steer an agent yet."))
            } else {
                StateView(phase: store.dashboardPhase, hasData: false, title: LocalText.string("newsroom")) {
                    Task { await store.refreshDashboard() }
                }
            }
        }
        .navigationTitle(LocalText.string("Newsroom"))
        .searchable(text: $query, prompt: LocalText.string("Find an agent"))
        .task { if !store.dashboardProvenance.isLive { await store.refreshDashboard() } }
        .refreshable { await store.refreshAll() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { CreditChip() } }
    }

    private func tiles(_ dashboard: NewsroomDashboard) -> some View {
        let all = dashboard.agents
        let count = { (status: NewsroomDashboard.Status) in all.filter { $0.status == status }.count }
        return StatGrid(minimum: 120) {
            StatTile(label: LocalText.string("Agents"), value: "\(all.count)")
            StatTile(label: LocalText.string("Town agents"), value: "\(all.filter { $0.group == .places }.count)")
            StatTile(label: LocalText.string("Working"), value: "\(count(.working))", tone: .good)
            StatTile(label: LocalText.string("Waiting on a person"), value: "\(count(.waiting))", tone: count(.waiting) > 0 ? .warn : .neutral)
            StatTile(label: LocalText.string("Quiet or stopped"), value: "\(count(.stale) + count(.stopped))", tone: .neutral)
        }
    }
}

// MARK: - Agents

struct StatusDot: View {
    let status: NewsroomDashboard.Status
    var color: Color {
        switch status {
        case .working: Palette.green
        case .waiting: Palette.amber
        case .stale: Palette.muted
        case .stopped: Palette.red
        case .idle: Palette.blue
        }
    }
    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9).accessibilityLabel(status.label)
    }
}

struct AgentRow: View {
    let agent: NewsroomDashboard.Agent

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            StatusDot(status: agent.status).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(content: agent.role).font(.body.weight(.semibold).monospaced()).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(agent.status.label).font(.caption2.weight(.semibold)).foregroundStyle(StatusDot(status: agent.status).color)
                }
                if let state = agent.state { Text(content: state).font(.footnote).foregroundStyle(Palette.ink).lineLimit(2) }
                if let next = agent.next.first {
                    Text(LocalText.string("Next: \(String(describing: next))")).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                }
                if let updated = agent.updatedDate {
                    Text(updated, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted).padding(.top, 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The short version for a town page.
struct AgentSummary: View {
    let agent: NewsroomDashboard.Agent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.s) {
                StatusDot(status: agent.status)
                Text(content: agent.agent).font(.footnote.monospaced())
                Spacer()
                Text(agent.status.label).font(.caption2.weight(.semibold))
            }
            if let state = agent.state { Text(content: state).font(.footnote) }
            if !agent.next.isEmpty {
                Text(LocalText.string("Next")).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                ForEach(agent.next.prefix(4), id: \.self) { Text("• \($0)").font(.caption) }
            }
            if !agent.asks.isEmpty {
                Text(LocalText.string("Asks")).font(.caption.weight(.semibold)).foregroundStyle(Palette.amber)
                ForEach(agent.asks.prefix(3), id: \.self) { Text("• \($0)").font(.caption).lineLimit(4) }
            }
            NavigationLink(LocalText.string("Everything it reports")) { AgentDetailView(agent: agent) }.font(.footnote)
        }
    }
}

struct AgentDetailView: View {
    let agent: NewsroomDashboard.Agent

    var body: some View {
        List {
            Section {
                LabeledContent(LocalText.string("Agent")) { Text(content: agent.agent).font(.footnote.monospaced()) }
                LabeledContent(LocalText.string("Status")) { HStack { StatusDot(status: agent.status); Text(agent.status.label) } }
                if let minute = agent.minute { LabeledContent(LocalText.string("Wakes"), value: agent.scheduled ? LocalText.string("hourly at :\(String(describing: String(format: "%02d", minute)))") : LocalText.string("not scheduled")) }
                if let updated = agent.updatedDate {
                    LabeledContent(LocalText.string("Updated")) { Text(updated, format: .dateTime.day().month().hour().minute()) }
                }
            }
            if let focus = agent.focus { Section(LocalText.string("Focus")) { Text(content: focus) } }
            if let state = agent.state { Section(LocalText.string("What it says now")) { Text(content: state) } }
            if let wake = agent.lastWake {
                Section(LocalText.string("Last wake")) {
                    if let started = wake.started { LabeledContent(LocalText.string("Started"), value: started) }
                    if let outcome = wake.outcome { LabeledContent(LocalText.string("Outcome"), value: outcome) }
                    if let line = wake.line { Text(content: line) }
                }
            }
            if !agent.next.isEmpty { Section(LocalText.string("Next")) { ForEach(agent.next, id: \.self) { Text($0) } } }
            if !agent.asks.isEmpty { Section(LocalText.string("Asks")) { ForEach(agent.asks, id: \.self) { Text($0) } } }
            if !agent.done.isEmpty { Section(LocalText.string("What it has done")) { ForEach(agent.done.reversed(), id: \.self) { Text($0).font(.footnote) } } }
            Section {
                Text(LocalText.string("Read-only: from the newsroom dashboard on promptugal.news.")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(agent.role)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - The city newsroom's flow (partly simulated)

/// The flow a town's newsroom is growing into: research → verify ("is this correct?") → write → edit and publish.
/// Research, write and publish are read from the town's real site. Verification does not exist yet, so its numbers
/// are simulated and marked so.
struct CityNewsroomFlow: View {
    let store: LocalStore
    @State private var town = "faro"

    var body: some View {
        let site = store.site(town)
        TitledCard(LocalText.string("A town's newsroom, step by step"), kicker: LocalText.string("The flow")) {
            Picker(LocalText.string("Town"), selection: $town) {
                ForEach(PlaceDirectory.towns) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Space.s) { stages(site) }
                VStack(alignment: .leading, spacing: Space.s) { stages(site) }
            }
            Text(LocalText.string("Today one agent per town does all four steps. The verify step (asking each organisation \"is this correct?\", drafted by agents and sent by a person) is not running yet: its numbers are simulated."))
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private func stages(_ site: PlaceSite?) -> some View {
        let mapped = site?.aiMap.count ?? 0
        FlowStage(step: "1", title: LocalText.string("Research"), value: "\(site?.sources.count ?? 0) sources · \(mapped) mapped", simulated: false)
        FlowArrow()
        FlowStage(step: "2", title: LocalText.string("Verify"), value: "\(Self.simulatedAsked(mapped)) asked · \(Self.simulatedConfirmed(mapped)) confirmed", simulated: true)
        FlowArrow()
        FlowStage(step: "3", title: LocalText.string("Write"), value: LocalText.string("\(String(describing: site?.aiNews.count ?? 0)) local stories"), simulated: false)
        FlowArrow()
        FlowStage(step: "4", title: LocalText.string("Edit and publish"), value: site?.isLive == true ? "Live" : "Researching", simulated: false)
    }

    /// Deterministic stand-ins, so the screen does not jump on every redraw. Not real data.
    static func simulatedAsked(_ mapped: Int) -> Int { mapped * 2 / 3 }
    static func simulatedConfirmed(_ mapped: Int) -> Int { mapped / 3 }
}

struct FlowStage: View {
    let step: String
    let title: String
    let value: String
    let simulated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step).font(.caption2.weight(.bold).monospacedDigit())
                .frame(width: 18, height: 18)
                .background(Palette.ink.opacity(0.08), in: Circle())
            Text(title).font(.subheadline.weight(.semibold))
            Text(value).font(.caption).foregroundStyle(Palette.muted)
            if simulated { SimulatedBadge() }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if simulated {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.series(4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FlowArrow: View {
    var body: some View {
        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Palette.muted)
            .frame(maxHeight: .infinity).accessibilityHidden(true)
    }
}
