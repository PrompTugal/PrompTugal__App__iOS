import Charts
import SwiftUI

/// The newsroom at a glance: the pipeline from research to front page, the story
/// board as columns, the desks' funnel, the build order and what waits on a person.
struct NewsroomStatusView: View {
    @Environment(DashboardData.self) private var data

    var body: some View {
        Page {
            ScreenHeader(kicker: "Newsroom", title: "How the news is made",
                         summary: "Every story from idea to published, the desks that feed them, and what is blocked.")
            FreshnessLabel(updated: data.status.updated, failed: data.status.failed)
            if let status = data.status.value {
                countTiles(status)
                if let pipeline = status.pipeline, !pipeline.isEmpty { PipelineStrip(stages: pipeline) }
            } else {
                StateView(phase: data.status.phase, hasData: false, title: "newsroom") {
                    Task { await data.refreshNewsroom(force: true) }
                }
            }
            if let board = data.board.value { StoryBoardView(board: board) }
            Columns {
                if let desks = data.desks.value { DeskFunnel(desks: desks) }
                if let steps = data.status.value?.buildOrder, !steps.isEmpty {
                    TitledCard("Build order", kicker: "\(steps.filter { $0.state == "done" }.count) of \(steps.count) done") {
                        ForEach(steps) { step in
                            InfoRow(title: "\(step.step). \(step.title ?? "")",
                                    detail: [step.due, step.note].compactMap { $0 }.joined(separator: " · "),
                                    symbol: step.state == "done" ? "checkmark.circle.fill" : "circle.dashed",
                                    tint: step.state == "done" ? Palette.green : Palette.muted)
                        }
                    }
                }
            } trailing: {
                if let waiting = data.status.value?.waiting, !waiting.isEmpty {
                    TitledCard("Waiting on a person", kicker: "\(waiting.count) blocked") {
                        ForEach(waiting, id: \.self) { item in
                            InfoRow(title: item.what ?? "", detail: [item.who.map { "Who: \($0)" }, item.unblocks.map { "Unblocks: \($0)" }]
                                .compactMap { $0 }.joined(separator: "\n"),
                                    symbol: "hourglass", tint: Palette.amber)
                        }
                    }
                }
                if let agents = data.status.value?.agents, !agents.isEmpty {
                    AgentStatusChart(agents: agents)
                }
            }
        }
        .navigationTitle("Newsroom")
        .refreshable { await data.refreshNewsroom(force: true) }
        .task { await data.refreshNewsroom() }
        .webTwin(FeedClient.site.appendingPathComponent("newsroom/"), title: "Newsroom")
    }

    private func countTiles(_ status: Wire.NewsroomStatus) -> some View {
        let counts = status.counts ?? [:]
        let tiles: [(String, String)] = [("stories", "Stories"), ("articles", "Articles"), ("agents_running", "Agents running"),
                                         ("runs", "Runs"), ("pages", "Pages"), ("nodes", "Graph nodes"), ("edges", "Graph edges"),
                                         ("companies", "Companies"), ("people", "People"), ("agenda", "Agenda items")]
        return StatGrid(minimum: 120) {
            ForEach(tiles, id: \.0) { key, label in
                if let value = counts[key] { StatTile(label: label, value: value.formatted()) }
            }
        }
    }
}

/// The desks in order, research to front page, as connected stages.
struct PipelineStrip: View {
    let stages: [Wire.Stage]

    var body: some View {
        TitledCard("The pipeline", kicker: "Research to front page") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        if index > 0 {
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.rule)
                                .padding(.horizontal, 4).accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Circle().fill(color(stage.state)).frame(width: 8, height: 8)
                                Text(stage.label ?? stage.stage).font(.subheadline.weight(.semibold))
                            }
                            Text(stage.state ?? "").font(.caption2).foregroundStyle(Palette.muted)
                            if let run = stage.lastRun, let date = WireDate.parse(run.when) {
                                Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                                    .font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(Space.s)
                        .frame(minWidth: 110, alignment: .leading)
                        .background(color(stage.state).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func color(_ state: String?) -> Color {
        switch state {
        case "running", "live", "done": Palette.green
        case "waiting", "blocked", "held": Palette.amber
        case "off", "stopped", "failed": Palette.red
        default: Palette.muted
        }
    }
}

/// The story board: one column per stage, each story a card. Scrolls sideways on iPhone.
struct StoryBoardView: View {
    let board: Wire.StoryBoard

    var body: some View {
        let columns = board.columns ?? []
        let stories = board.stories ?? []
        TitledCard("The story board", kicker: "\(stories.count) stories") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Space.m) {
                    ForEach(columns) { column in
                        let items = stories.filter { $0.column == column.id }
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack {
                                Text(column.name ?? column.id).font(.caption.weight(.semibold))
                                Spacer()
                                Text("\(items.count)").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                            .accessibilityAddTraits(.isHeader)
                            ForEach(items.prefix(8)) { story in
                                StoryChip(story: story)
                            }
                            if items.count > 8 {
                                Text("+\(items.count - 8) more").font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                        .frame(width: 210, alignment: .topLeading)
                        .padding(Space.s)
                        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

private struct StoryChip: View {
    let story: Wire.BoardStory

    var body: some View {
        let label = VStack(alignment: .leading, spacing: 3) {
            Text(story.title ?? story.id).font(.caption).foregroundStyle(Palette.ink).lineLimit(3)
            if let assignee = story.assignee {
                Text(assignee.components(separatedBy: "@").first ?? assignee).font(.caption2).foregroundStyle(Palette.stable(assignee))
            }
            if let next = story.next { Text(next).font(.caption2).foregroundStyle(Palette.muted).lineLimit(2) }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 8))

        if let url = story.url {
            NavigationLink { WebPage(url: url, title: story.title ?? "Story") } label: { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}

/// From captures to published: how much research turns into stories.
struct DeskFunnel: View {
    let desks: Wire.Desks

    private struct Step: Identifiable {
        let id: String
        let label: String
        let value: Int
    }

    var body: some View {
        let funnel = desks.funnel ?? [:]
        let steps = [("captures", "Captures"), ("feeding_a_candidate", "Feeding a candidate"),
                     ("candidates", "Candidates"), ("published", "Published")]
            .compactMap { key, label in funnel[key].map { Step(id: key, label: label, value: $0) } }
        TitledCard("The desks' funnel", kicker: "\(desks.runs?.count ?? 0) desk runs") {
            Chart(steps) { step in
                BarMark(x: .value("Count", step.value), y: .value("Step", step.label))
                    .foregroundStyle(step.id == "published" ? Palette.green : Palette.red.opacity(0.75))
                    .annotation(position: .trailing) { Text("\(step.value)").font(.caption2) }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(steps.count) * 34 + 10)
            if let gaps = desks.gapsOpen, !gaps.isEmpty {
                Text("Open questions").font(.caption.weight(.semibold))
                ForEach(gaps, id: \.self) { gap in
                    Text("• \(gap.text ?? "")").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

/// Agents by status and by kind.
struct AgentStatusChart: View {
    let agents: [Wire.StatusAgent]

    private struct Slice: Identifiable {
        let id: String
        let count: Int
    }

    var body: some View {
        let slices = Dictionary(grouping: agents, by: { $0.status ?? "unknown" })
            .map { Slice(id: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        TitledCard("Agents by status", kicker: "\(agents.count) agents") {
            Chart(slices) { slice in
                SectorMark(angle: .value("Agents", slice.count), innerRadius: .ratio(0.6), angularInset: 1.5)
                    .foregroundStyle(by: .value("Status", slice.id))
                    .cornerRadius(3)
            }
            .chartLegend(position: .trailing, alignment: .center)
            .frame(height: 180)
        }
    }
}

#Preview("Newsroom · iPhone") {
    NavigationStack { NewsroomStatusView() }.environment(PreviewSamples.previewData()).phonePreview()
}

#Preview("Newsroom · iPad") {
    NavigationStack { NewsroomStatusView() }.environment(PreviewSamples.previewData()).padPreview()
}
