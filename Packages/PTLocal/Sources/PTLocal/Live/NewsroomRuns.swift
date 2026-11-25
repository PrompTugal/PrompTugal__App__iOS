import PTCore
import SwiftUI

/// The pipeline and the newest runs from the newsroom's status feed, on the live board. Each run opens its agent's
/// page on promptugal.news. Read-only: it shows what ran, nothing here starts, stops or steers an agent.
struct NewsroomRunsCard: View {
    let model: LiveNewsroom
    var limit = 8

    var body: some View {
        if let status = model.status {
            content(status, now: Date())
        }
    }

    private func content(_ status: NewsroomStatus, now: Date) -> some View {
        TitledCard("Pipeline and recent runs", kicker: "Newsroom status") {
            if !status.pipeline.isEmpty { pipeline(status.pipeline, now: now) }
            Divider()
            ForEach(status.recentRuns(limit: limit, now: now)) { run in
                runRow(run, link: status.link(for: run), now: now)
            }
            ledgerNote(status, now: now)
            ProvenanceLabel(provenance: model.statusProvenance, phase: .idle, readAt: status.builtAt)
            Link(destination: status.pageURL) {
                Label("The newsroom's status page", systemImage: "arrow.up.right.square")
            }
            .font(.footnote)
        }
    }

    private func pipeline(_ stages: [NewsroomStatus.Stage], now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(stages) { stage in
                stageRow(stage, now: now)
            }
        }
    }

    private func stageRow(_ stage: NewsroomStatus.Stage, now: Date) -> some View {
        let running = stage.state == "running"
        let color: Color = running ? Palette.green : Palette.muted
        return HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(stage.title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(stage.state ?? "").font(.caption).foregroundStyle(Palette.muted)
            Spacer(minLength: Space.s)
            if let last = stage.lastRun, let date = LiveClock.clamp(NewsroomDate.parse(last.when), now: now) {
                Text(NewsroomRunsCard.day(date)).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func runRow(_ run: NewsroomStatus.Run, link: URL, now: Date) -> some View {
        let date = LiveClock.clamp(NewsroomDate.parse(run.when), now: now)
        return Link(destination: link) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.s) {
                    Text(run.handle).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                    if let kind = run.kind { Text(kind).font(.caption2).foregroundStyle(Palette.muted) }
                    Spacer(minLength: Space.s)
                    if let date {
                        Text(NewsroomRunsCard.stamp(date)).font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                    }
                }
                Text(run.what).font(.footnote).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading).lineLimit(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the agent's page on promptugal.news")
    }

    @ViewBuilder private func ledgerNote(_ status: NewsroomStatus, now: Date) -> some View {
        if let newest = status.newestRun(now: now) {
            let freshness = Freshness.of(newest, now: now)
            if !freshness.isLive {
                let rebuilt = status.builtAt.map { "; the site last rebuilt this feed on \(NewsroomRunsCard.day($0))" } ?? ""
                Text("No runs since \(NewsroomRunsCard.day(newest)): the ledger's newest entry is from then\(rebuilt).")
                    .font(.caption).foregroundStyle(Palette.amber)
            }
        }
    }

    static func day(_ date: Date) -> String {
        Freshness.day(date, now: Date(), timeZone: .current)
    }

    static func stamp(_ date: Date) -> String {
        "\(Freshness.day(date, now: Date(), timeZone: .current)) \(Freshness.time(date, timeZone: .current))"
    }
}
