import Charts
import SwiftUI

/// A person's command centre, native: every board issue that is theirs, by workstream,
/// with filters for open, overdue and "named for me". From people/<id>/app/data.json.
struct CommandCentreView: View {
    @Environment(DashboardData.self) private var data
    let personID: String
    var name: String = ""
    @State private var filter: Filter = .open
    @State private var query = ""

    enum Filter: String, CaseIterable, Identifiable {
        case open = "Open", overdue = "Overdue", named = "Named for me", done = "Done", all = "All"
        var id: Self { self }
    }

    private var feed: RemoteFeed<Wire.CommandCentre> { data.commandCentre(personID) }

    private func matches(_ issue: Wire.CCIssue) -> Bool {
        let late = !issue.isDone && (issue.dueDate.map { $0 < .now } ?? false)
        let text = query.isEmpty || (issue.title ?? "").localizedStandardContains(query) || issue.id.localizedStandardContains(query)
        guard text, issue.mine != false else { return false }
        switch filter {
        case .open: return !issue.isDone
        case .overdue: return late
        case .named: return issue.named == true && !issue.isDone
        case .done: return issue.isDone
        case .all: return true
        }
    }

    var body: some View {
        let issues = (feed.value?.issues ?? []).filter(matches)
        let groups = Dictionary(grouping: issues, by: { $0.stream ?? "other" }).sorted { $0.value.count > $1.value.count }
        Page {
            ScreenHeader(kicker: "Command centre", title: name.isEmpty ? personID.capitalized : name,
                         summary: "Every board issue that is \(name.isEmpty ? "theirs" : name + "'s"), by workstream.")
            FreshnessLabel(updated: feed.updated, failed: feed.failed)
            if let all = feed.value?.issues {
                statusChart(all.filter { $0.mine != false })
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Filter.allCases) { item in
                        FilterChip(title: item.rawValue, isOn: filter == item) { filter = item }
                    }
                }
            }
            if feed.value == nil {
                StateView(phase: feed.phase, hasData: false, title: "command centre") {
                    Task { await feed.load(force: true) }
                }
            } else if issues.isEmpty {
                Text("Nothing here.").font(.footnote).foregroundStyle(Palette.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: Space.m)], alignment: .leading, spacing: Space.m) {
                ForEach(groups, id: \.key) { stream, rows in
                    TitledCard(stream.capitalized, kicker: "\(rows.count) issues") {
                        ForEach(rows.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.prefix(25)) { issue in
                            IssueRow(issue: issue)
                        }
                        if rows.count > 25 {
                            Text("and \(rows.count - 25) more").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Find an issue")
        .navigationTitle("Command centre")
        .refreshable { await feed.load(force: true) }
        .task { await feed.load() }
        .webTwin(TeamSite.base.appendingPathComponent("people/\(personID)/app/"), title: "Command centre")
    }

    private func statusChart(_ issues: [Wire.CCIssue]) -> some View {
        let counts = Dictionary(grouping: issues, by: { $0.status ?? "unknown" }).map { (status: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        return Chart(counts, id: \.status) { item in
            BarMark(x: .value("Issues", item.count), y: .value("Board", "issues"))
                .foregroundStyle(by: .value("Status", item.status))
        }
        .chartForegroundStyleScale(domain: counts.map(\.status),
                                   range: counts.map { color(for: $0.status) })
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 64)
        .accessibilityLabel(counts.map { "\($0.count) \($0.status)" }.joined(separator: ", "))
    }

    private func color(for status: String) -> Color {
        switch status {
        case "done", "closed": Palette.green
        case "in progress": Palette.blue
        case "picked": Palette.amber
        case "open": Palette.red
        default: Palette.muted
        }
    }
}

/// One board issue: id, title, due date (red when late), status.
struct IssueRow: View {
    let issue: Wire.CCIssue

    var body: some View {
        let late = !issue.isDone && (issue.dueDate.map { $0 < .now } ?? false)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.s) {
                Text(issue.id).font(Typo.dataSmall).foregroundStyle(Palette.muted)
                if issue.named == true {
                    Image(systemName: "person.fill.checkmark").font(.caption2).foregroundStyle(Palette.red)
                        .accessibilityLabel("Named for me")
                }
                Spacer()
                Text(issue.status ?? "").font(.caption2).foregroundStyle(issue.isDone ? Palette.green : Palette.muted)
            }
            Text(issue.title ?? "").font(.subheadline).foregroundStyle(issue.isDone ? Palette.muted : Palette.ink)
                .strikethrough(issue.isDone)
            if let due = issue.due, !due.isEmpty {
                Label(due, systemImage: late ? "exclamationmark.circle.fill" : "calendar")
                    .font(.caption2).foregroundStyle(late ? Palette.red : Palette.muted)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
