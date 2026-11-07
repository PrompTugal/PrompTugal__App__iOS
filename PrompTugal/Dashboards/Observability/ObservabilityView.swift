import Charts
import SwiftUI

/// Observability, native: newsroom activity by hour, runs by kind, the team's ten days,
/// and the health of the endpoints this app reads, measured by the app itself.
/// Reader traffic is sealed in a vault; the screen says so and points at the web view of it.
struct ObservabilityView: View {
    @Environment(DashboardData.self) private var data
    private let http = HTTPLog.shared

    var body: some View {
        Page {
            ScreenHeader(kicker: "Observability", title: "What ran, and what is read",
                         summary: "Agent activity and newsroom metrics from the public JSON, and the health of every endpoint the app reads.")
            HStack(spacing: Space.l) {
                FreshnessLabel(updated: data.status.updated, failed: data.status.failed)
                if let version = data.status.value?.version {
                    Text("promptugal.news \(version)").font(Typo.dataSmall).foregroundStyle(Palette.muted)
                }
                if let version = data.team.value?.version {
                    Text("team site \(version)").font(Typo.dataSmall).foregroundStyle(Palette.muted)
                }
            }
            GapNote(title: "Reader traffic is sealed",
                    text: "Each page view on the websites is encrypted in the reader's browser and written to a write-only vault lane. It is read back from the public observability vault with a read key, so there is no public JSON for it. The native vault reader (night/vault) will open that vault here; until then, the web original shows it.")
            Columns {
                WakesByHourChart(dashboard: data.dashboard.value)
                RunsByKindChart(runs: data.status.value?.runs ?? [])
            } trailing: {
                TeamActivityChart(people: data.team.value?.sortedPeople ?? [])
                DeskRunsChart(runs: data.desks.value?.runs ?? [])
            }
            EndpointHealth(records: http.records)
        }
        .navigationTitle("Observability")
        .refreshable { await data.refreshAll(force: true) }
        .task { await data.refreshAll() }
        .webTwin(FeedClient.site.appendingPathComponent("newsroom/observability/"), title: "Observability")
    }
}

/// How many agents woke in each of the last 24 hours, stacked by outcome.
struct WakesByHourChart: View {
    let dashboard: Wire.NewsroomDashboard?

    private struct Cell: Identifiable {
        let id: String
        let hour: String
        let order: Int
        let outcome: String
        let count: Int
    }

    var body: some View {
        let hours = dashboard?.gridHours ?? []
        let agents = dashboard?.agents ?? []
        let outcomes: [WakeCell] = [.ok, .partial, .idle, .failed, .commit]
        let cells: [Cell] = hours.enumerated().flatMap { column, hour in
            outcomes.map { outcome in
                Cell(id: "\(column)-\(outcome.label)", hour: hour, order: column, outcome: outcome.label,
                     count: agents.filter { $0.cells.indices.contains(column) && $0.cells[column] == outcome }.count)
            }
        }
        TitledCard("Agent wakes by hour", kicker: "Last 24 hours, UTC") {
            if cells.isEmpty {
                StateView(phase: .loading, hasData: false, title: "wake grid")
            } else {
                Chart(cells) { cell in
                    BarMark(x: .value("Hour", cell.hour), y: .value("Agents", cell.count))
                        .foregroundStyle(by: .value("Outcome", cell.outcome))
                }
                .chartForegroundStyleScale([WakeCell.ok.label: Palette.green, WakeCell.partial.label: Palette.amber,
                                            WakeCell.idle.label: Palette.muted, WakeCell.failed.label: Palette.red,
                                            WakeCell.commit.label: Palette.blue])
                .chartXAxis {
                    AxisMarks(values: hours.enumerated().filter { $0.offset % 3 == 0 }.map(\.element))
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 200)
            }
        }
    }
}

/// Runs recorded in status.json, by day and kind.
struct RunsByKindChart: View {
    let runs: [Wire.Run]

    var body: some View {
        TitledCard("Runs by day", kicker: "\(runs.count) runs in the ledger") {
            let dated = runs.filter { $0.date != nil }
            if dated.isEmpty {
                StateView(phase: .loading, hasData: false, title: "runs")
            } else {
                Chart(dated) { run in
                    BarMark(x: .value("Day", run.date ?? .now, unit: .day), y: .value("Runs", 1))
                        .foregroundStyle(by: .value("Kind", run.kind ?? "other"))
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 200)
            }
        }
    }
}

/// Each person's daily activity on the board over ten days (me.json `daily`).
struct TeamActivityChart: View {
    let people: [Wire.Person]

    private struct Point: Identifiable {
        let id: String
        let person: String
        let day: Date
        let value: Double
    }

    var body: some View {
        let points: [Point] = people.flatMap { person in
            zip(person.days ?? [], person.daily ?? []).compactMap { day, value in
                Lisbon.instant(day: day).map { Point(id: "\(person.id)-\(day)", person: person.first ?? person.displayName, day: $0, value: value) }
            }
        }
        TitledCard("The team, ten days", kicker: "Activity per person per day") {
            if points.isEmpty {
                StateView(phase: .loading, hasData: false, title: "team activity")
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Day", point.day, unit: .day), y: .value("Activity", point.value))
                        .foregroundStyle(by: .value("Person", point.person))
                        .interpolationMethod(.monotone)
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 200)
            }
        }
    }
}

/// The desks' runs: captures, candidates and gaps per run.
struct DeskRunsChart: View {
    let runs: [Wire.DeskRun]

    private struct Bar: Identifiable {
        let id: String
        let date: Date
        let series: String
        let value: Int
    }

    var body: some View {
        let bars: [Bar] = runs.compactMap { run -> [Bar]? in
            guard let date = run.date else { return nil }
            return [Bar(id: run.id + "c", date: date, series: "New captures", value: run.capturesNew ?? 0),
                    Bar(id: run.id + "s", date: date, series: "Candidates", value: run.candidates ?? 0),
                    Bar(id: run.id + "g", date: date, series: "Gaps", value: run.gaps ?? 0)]
        }.flatMap { $0 }
        TitledCard("Desk runs", kicker: "\(runs.count) runs") {
            if bars.isEmpty {
                StateView(phase: .loading, hasData: false, title: "desk runs")
            } else {
                Chart(bars) { bar in
                    BarMark(x: .value("Run", bar.date, unit: .hour), y: .value("Count", bar.value))
                        .foregroundStyle(by: .value("Series", bar.series))
                        .position(by: .value("Series", bar.series))
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 200)
            }
        }
    }
}

/// The endpoints this app reads: requests, median time and failures, measured on this device.
struct EndpointHealth: View {
    let records: [HTTPRequestRecord]

    private struct Row: Identifiable {
        let id: String
        let count: Int
        let median: Double
        let failures: Int
        let bytes: Int
    }

    var body: some View {
        let rows = Dictionary(grouping: records, by: { $0.label ?? $0.host }).map { label, items in
            let times = items.map(\.durationMs).sorted()
            return Row(id: label, count: items.count, median: times[times.count / 2],
                       failures: items.filter { !$0.succeeded }.count, bytes: items.reduce(0) { $0 + $1.bytes })
        }
        .sorted { $0.median > $1.median }
        TitledCard("Endpoint health", kicker: "Measured by this app, since launch") {
            if rows.isEmpty {
                Text("No requests yet.").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Chart(rows) { row in
                    BarMark(x: .value("Median ms", row.median), y: .value("Endpoint", row.id))
                        .foregroundStyle(row.failures > 0 ? Palette.red : Palette.green)
                        .annotation(position: .trailing) {
                            Text("\(Int(row.median)) ms · \(row.count)× · \(Bytes.format(row.bytes))\(row.failures > 0 ? " · \(row.failures) failed" : "")")
                                .font(.caption2).foregroundStyle(Palette.muted)
                        }
                }
                .frame(height: CGFloat(rows.count) * 30 + 20)
            }
        }
    }
}

#Preview("Observability · iPhone") {
    NavigationStack { ObservabilityView() }.environment(PreviewSamples.data()).phonePreview()
}

#Preview("Observability · iPad") {
    NavigationStack { ObservabilityView() }.environment(PreviewSamples.data()).padPreview()
}
