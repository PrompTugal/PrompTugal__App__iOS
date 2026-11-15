import PTCore
import SwiftUI

/// The newsroom in action: the board of agents (pulses, sparks, handoffs in flight), the ticker of what they did,
/// "this story, these agents", and where each fired in the last 24 hours. Reads dashboard.json every minute while
/// open and animates what changed between reads. Read-only: nothing here starts, stops or steers an agent.
public struct NewsroomLiveView: View {
    @State private var model = LiveNewsroom.shared
    @State private var selected: String?
    @State private var story: TownStory?
    @Namespace private var storyChip
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `selecting` opens the board with that agent selected ("place.faro").
    public init(selecting role: String? = nil) {
        _selected = State(initialValue: role)
    }

    private var highlighted: Set<String> {
        guard let story else { return [] }
        return Set(StoryAgents.credits(for: story.story, places: model.places, dashboard: model.dashboard).map(\.role))
    }

    public var body: some View {
        Page {
            ScreenHeader(kicker: "Command centre · live", title: "The newsroom in action",
                         summary: "Every agent behind PrompTugal.news, read every minute from the newsroom's own dashboard. A pulse is an agent that showed a sign of life in the last half hour; a spark, one you saw change. Read-only.")
            status
            if model.dashboard != nil {
                NewsroomBoard(model: model, selected: $selected, highlighted: highlighted)
                NewsroomBoardLegend()
                if let role = selected, let agent = model.agent(role) {
                    selectedCard(agent)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                storyCard
                NavigationLink {
                    AlgarveMapsView()
                } label: {
                    Card {
                        Label("The towns, four ways", systemImage: "map").font(.headline)
                        Text("The Algarve on the map, in 3D flying town to town, as a tile grid, and as a cartogram sized by what each agent found.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                .buttonStyle(.plain)
                Columns {
                    LiveTicker(model: model, selected: $selected)
                } trailing: {
                    if let extras = model.extras { WakeGrid(model: model, extras: extras, selected: $selected) }
                }
                GapNote(title: "What is real here",
                        text: "Every node, pulse and line is read from promptugal.news/api/v1/newsroom/dashboard.json and the place files. Handoffs are the dashboard's 24-hour counts, drawn as a flow, not one particle per handoff. Times an agent wrote ahead of the clock are shown as now.")
            } else {
                StateView(phase: model.phase, hasData: false, title: "newsroom") {
                    Task { await model.poll() }
                }
            }
        }
        .navigationTitle("Live")
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: selected)
        .task { await model.run() }
        .refreshable { await model.poll() }
    }

    // MARK: Status line

    private var status: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: Space.s) {
                ProvenanceLabel(provenance: model.provenance, phase: model.phase)
                Spacer(minLength: Space.s)
                if let last = model.lastPoll {
                    let left = max(0, Int(60 - context.date.timeIntervalSince(last)))
                    Text("next read in \(left)s").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                }
                if let built = model.dashboard?.built {
                    Text("site \(built)").font(.caption.monospaced()).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    // MARK: The selected agent

    private func selectedCard(_ agent: NewsroomDashboard.Agent) -> some View {
        TitledCard(agent.handle, kicker: agent.placeName ?? "Desk") {
            AgentSummary(agent: agent)
            if let fired = model.extras?.agents[agent.role] {
                HStack(spacing: Space.s) {
                    Text("Last 24 h").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    HourStrip(fired: fired.fired, color: StatusDot(status: agent.status).color,
                              currentHour: model.extras.flatMap { WakeGrid.currentIndex(hours: $0.gridHours) })
                        .frame(height: 10)
                    if fired.commits24h > 0 { CountPill(count: fired.commits24h, label: "commits", color: Palette.blue) }
                }
            }
            if let id = agent.placeID, PlaceDirectory.info(id) != nil, id != PlaceDirectory.country.id {
                NavigationLink {
                    if id == PlaceDirectory.region.id { AlgarveView() } else { TownView(id: id) }
                } label: {
                    Label("Open \(agent.placeName ?? id)'s page", systemImage: "newspaper")
                }
                .font(.footnote)
            }
        }
    }

    // MARK: This story, these agents

    private var storyCard: some View {
        let latest = LocalStore.shared.latestFromTowns(limit: 10)
        return TitledCard("This story, these agents", kicker: "Who brought it in") {
            Text("Pick a story: the agents that found it light up on the board.")
                .font(.caption).foregroundStyle(Palette.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(latest) { item in
                        Button {
                            story = story == item ? nil : item
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.town.name).font(.caption2.weight(.bold)).foregroundStyle(Palette.red)
                                Text(item.story.title).font(.caption).foregroundStyle(Palette.ink)
                                    .lineLimit(3).multilineTextAlignment(.leading)
                            }
                            .padding(Space.s)
                            .frame(width: 180, height: 76, alignment: .topLeading)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.paper2)
                                    if story == item {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Palette.sun, lineWidth: 3)
                                            .matchedGeometryEffect(id: "chip", in: storyChip)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(story == item ? .isSelected : [])
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.3), value: story)
            if let story {
                StoryRow(story: story.story, town: story.town.name)
                let credits = StoryAgents.credits(for: story.story, places: model.places, dashboard: model.dashboard)
                ForEach(credits) { credit in
                    Button { selected = credit.role } label: {
                        HStack(alignment: .top, spacing: Space.s) {
                            Image(systemName: credit.how == .wrote ? "pencil.and.scribble" : "text.magnifyingglass")
                                .foregroundStyle(credit.how == .wrote ? Palette.green : Palette.blue)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(credit.address).font(.footnote.monospaced()).foregroundStyle(Palette.ink)
                                Text(credit.note).font(.caption).foregroundStyle(Palette.muted)
                                if let agent = model.agent(credit.role), let state = agent.state {
                                    Text("Now: \(state)").font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if credits.isEmpty {
                    Text("No agent is named for this story in the data.").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

// MARK: - Ticker

/// The latest wakes and changes, newest first; lines seen to change while watching slide in at the top.
struct LiveTicker: View {
    let model: LiveNewsroom
    @Binding var selected: String?
    @State private var showAll = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let events = showAll ? model.events : Array(model.events.prefix(12))
        TitledCard("What the agents just did", kicker: kicker) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(events) { event in
                        Button { selected = event.role } label: { row(event, now: context.date) }
                            .buttonStyle(.plain)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.45), value: model.events.first?.id)
            if model.events.count > 12 {
                Button(showAll ? "Show fewer" : "Show all \(model.events.count)") { showAll.toggle() }.font(.footnote)
            }
        }
    }

    private var kicker: String {
        let watched = model.events.filter { $0.origin == .watched }.count
        return watched > 0 ? "\(watched) seen live" : "From the latest dashboard"
    }

    private func row(_ event: LiveEvent, now: Date) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: event.symbol)
                .font(.caption)
                .foregroundStyle(color(event))
                .frame(width: 18, height: 18)
                .background(color(event).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(event.text).font(.footnote.weight(.medium)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 4)
                    Text(Self.ago(event.date, now: now)).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                }
                if let detail = event.detail {
                    Text(detail).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                }
                switch event.origin {
                case .watched: Text("NEW · seen while watching").font(.caption2.weight(.bold)).foregroundStyle(Palette.green)
                case .sinceLastVisit: Text("since your last visit").font(.caption2.weight(.semibold)).foregroundStyle(Palette.amber)
                case .latest: EmptyView()
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func color(_ event: LiveEvent) -> Color {
        switch event.kind {
        case .ask: Palette.amber
        case .handoff: Palette.blue
        case .stories, .mapped, .live, .done: Palette.green
        case .wake: Palette.series(4)
        case .update, .joined: Palette.muted
        }
    }

    /// "now", "4 min ago", "3 h ago", "2 d ago".
    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86400 { return "\(seconds / 3600) h ago" }
        return "\(seconds / 86400) d ago"
    }
}

// MARK: - Where they fired

/// Where each agent fired in the last 24 hours (the dashboard's grid), the busiest first.
struct WakeGrid: View {
    let model: LiveNewsroom
    let extras: LiveDashboardExtras
    @Binding var selected: String?

    var body: some View {
        let rows = Self.rows(extras)
        let current = Self.currentIndex(hours: extras.gridHours)
        TitledCard("Where they fired", kicker: "Last 24 hours, UTC") {
            if rows.isEmpty {
                Text("No agent fired in the last 24 hours.").font(.caption).foregroundStyle(Palette.muted)
            }
            ForEach(rows.prefix(24), id: \.role) { row in
                Button { selected = row.role } label: {
                    HStack(spacing: Space.s) {
                        Text(row.role).font(.caption2.monospaced()).foregroundStyle(Palette.ink)
                            .lineLimit(1).frame(width: 118, alignment: .leading)
                        HourStrip(fired: row.fired, color: color(row.role), currentHour: current).frame(height: 10)
                    }
                }
                .buttonStyle(.plain)
            }
            if let first = extras.gridHours.first, let last = extras.gridHours.last {
                HStack {
                    Spacer().frame(width: 118)
                    Text(first + ":00"); Spacer(); Text(last + ":00")
                }
                .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
            }
        }
    }

    private func color(_ role: String) -> Color {
        model.agent(role).map { StatusDot(status: $0.status).color } ?? Palette.blue
    }

    struct Row { let role: String; let fired: [Bool] }

    static func rows(_ extras: LiveDashboardExtras) -> [Row] {
        extras.agents
            .map { Row(role: $0.key, fired: $0.value.fired) }
            .filter { $0.fired.contains(true) }
            .sorted { a, b in
                let na = a.fired.filter { $0 }.count, nb = b.fired.filter { $0 }.count
                return na != nb ? na > nb : a.role < b.role
            }
    }

    /// The column of the current UTC hour, if the grid labels hours.
    static func currentIndex(hours: [String], now: Date = Date()) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let hour = String(format: "%02d", calendar.component(.hour, from: now))
        return hours.firstIndex(of: hour)
    }
}

/// 24 little cells, filled where the agent fired; the current hour outlined.
struct HourStrip: View {
    let fired: [Bool]
    let color: Color
    var currentHour: Int?

    var body: some View {
        Canvas { context, size in
            guard !fired.isEmpty else { return }
            let gap: CGFloat = 1.5
            let w = (size.width - gap * CGFloat(fired.count - 1)) / CGFloat(fired.count)
            for (i, on) in fired.enumerated() {
                let rect = CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: size.height)
                let path = Path(roundedRect: rect, cornerRadius: 2)
                context.fill(path, with: .color(on ? color : Palette.rule.opacity(0.5)))
                if i == currentHour { context.stroke(path, with: .color(Palette.ink), lineWidth: 1) }
            }
        }
        .accessibilityLabel("Fired in \(fired.filter { $0 }.count) of the last \(fired.count) hours")
    }
}
