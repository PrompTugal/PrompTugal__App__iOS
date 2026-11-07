import SwiftUI
import UIKit

/// The wall: everything at once, for an iPad on a stand or a desk. The team's load, the agents'
/// last 24 hours, the newsroom pipeline, the latest runs and the next stand-up, refreshed every
/// five minutes with no taps. On iPhone the same tiles stack.
struct WallView: View {
    @Environment(DashboardData.self) private var data
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        TimelineView(.periodic(from: .now, by: 300)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header(context.date)
                    if width == .regular {
                        HStack(alignment: .top, spacing: Space.l) {
                            VStack(spacing: Space.l) { teamTile; standupTile; NextHoursCard() }
                                .frame(width: 360)
                            VStack(spacing: Space.l) { agentsTile; pipelineTile; runsTile }
                        }
                    } else {
                        standupTile
                        NextHoursCard()
                        teamTile
                        agentsTile
                        pipelineTile
                        runsTile
                    }
                }
                .padding(Space.l)
            }
            .background(Palette.paper.ignoresSafeArea())
            .task(id: context.date) { await data.refreshAll(force: true) }
        }
        .navigationTitle("Wall")
        .navigationBarTitleDisplayMode(.inline)
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func header(_ now: Date) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Kicker("PrompTugal · the team and its agents")
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(Typo.display)
            }
            Spacer()
            FreshnessLabel(updated: data.dashboard.updated, staleAfter: 900, failed: data.dashboard.failed)
        }
    }

    // MARK: Tiles

    private var teamTile: some View {
        let people = (data.team.value?.sortedPeople ?? []).sorted { $0.attention > $1.attention }
        return TitledCard("The team", kicker: "\(people.count) people") {
            ForEach(people) { person in
                HStack(spacing: Space.s) {
                    Avatar(initials: person.initials, colour: person.tint, size: 28)
                    Text(person.first ?? person.displayName).font(.subheadline.weight(.medium))
                    Spacer()
                    CountPill(count: person.onlyYou ?? 0, label: "only")
                    CountPill(count: person.decide ?? 0, label: "decide", color: Palette.amber)
                    CountPill(count: person.overdue ?? 0, label: "late")
                }
            }
            if people.isEmpty { StateView(phase: data.team.phase, hasData: false, title: "team") }
        }
    }

    private var standupTile: some View {
        let next = (data.team.value?.sortedPeople ?? []).compactMap(\.standupDate).filter { $0 > .now }.min()
        return Card {
            Kicker("Next stand-up", color: Palette.green)
            if let next {
                Text(next, format: .dateTime.hour().minute()).font(.system(size: 54, weight: .bold, design: .serif))
                    .monospacedDigit()
                Text(next, style: .relative).font(.title3).foregroundStyle(Palette.muted)
            } else {
                Text("None scheduled").font(Typo.title).foregroundStyle(Palette.muted)
            }
        }
    }

    private var agentsTile: some View {
        TitledCard("Where the agents fired", kicker: "Last 24 hours, UTC") {
            if let dashboard = data.dashboard.value {
                WakeGrid(agents: dashboard.agents ?? [], hours: dashboard.gridHours ?? [])
            } else {
                StateView(phase: data.dashboard.phase, hasData: false, title: "agents")
            }
        }
    }

    @ViewBuilder private var pipelineTile: some View {
        if let pipeline = data.status.value?.pipeline, !pipeline.isEmpty {
            PipelineStrip(stages: pipeline)
        }
    }

    private var runsTile: some View {
        TitledCard("Latest runs", kicker: "Newsroom") {
            ForEach((data.status.value?.runs ?? []).prefix(6)) { run in
                InfoRow(title: run.what ?? run.id, detail: run.by, date: run.date,
                        symbol: "arrow.triangle.branch", tint: Palette.stable(run.kind ?? ""))
            }
        }
    }
}

#Preview("Wall · iPad") {
    NavigationStack { WallView() }.environment(PreviewSamples.data()).padPreview()
}

#Preview("Wall · iPhone") {
    NavigationStack { WallView() }.environment(PreviewSamples.data()).phonePreview()
}
