import SwiftUI

/// The stand-ups, native: what is open on each agenda, and one tap away the agenda itself. Read from the team
/// site's `/meetings/` twins and kept on the device; the web page stays one tap away as a fallback.
struct StandupsView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity

    var body: some View {
        let now = Date.now
        let upcoming = team.standupSummaries.filter { ($0.end ?? .distantPast) > now }
        let earlier = Array(team.standupSummaries.filter { ($0.end ?? .distantPast) <= now }.reversed())
        List {
            if team.standupSummaries.isEmpty {
                Section {
                    if team.refreshing {
                        ProgressView("Loading the stand-ups…")
                    } else {
                        ContentUnavailableView("The stand-ups are unavailable", systemImage: "wifi.slash",
                                               description: Text("Connect to the internet and pull to refresh."))
                    }
                }
            }
            if !upcoming.isEmpty {
                Section("Upcoming") { ForEach(upcoming) { row($0) } }
            }
            if !earlier.isEmpty {
                Section("Earlier") { ForEach(earlier) { row($0) } }
            }
            Section {
                Link(destination: TeamEndpoints.base.appendingPathComponent("meetings/")) {
                    Label("Open the web page", systemImage: "safari")
                }
            } footer: {
                Text("From web-summit.sgit.ai, public data, kept on this device for offline use.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Stand-ups")
        .refreshable { await team.refresh(person: identity.current?.id) }
        .task { if team.standupSummaries.isEmpty { await team.refresh(person: identity.current?.id) } }
    }

    private func row(_ summary: StandupSummary) -> some View {
        NavigationLink {
            StandupDetailView(slot: summary.slot)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(Self.title(summary)).font(.headline)
                    if summary.isNext {
                        Text("next").font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
                Text(Self.summaryLine(summary)).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "Sun 8 Nov · 12:00", Lisbon time, from the stand-up's own time (or its label when that is not readable).
    static func title(_ summary: StandupSummary) -> String {
        guard let at = summary.at else { return summary.label }
        return "\(Lisbon.dayLabel(Lisbon.day(at))) · \(Lisbon.timeLabel(at))"
    }

    /// "21 decisions · 6 questions · 1 idea · 7 syncs · 0 decided"
    static func summaryLine(_ summary: StandupSummary) -> String {
        func plural(_ count: Int, _ one: String, _ many: String) -> String { "\(count) \(count == 1 ? one : many)" }
        return [plural(summary.decisions, "decision", "decisions"), plural(summary.questions, "question", "questions"),
                plural(summary.ideas, "idea", "ideas"), plural(summary.syncs, "sync", "syncs"),
                "\(summary.decided) decided"].joined(separator: " · ")
    }
}

/// One stand-up's agenda: decisions first, then questions, ideas and quick syncs, then everyone's briefing.
struct StandupDetailView: View {
    let slot: String

    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(\.openURL) private var openURL
    @State private var onlyMine = false

    private var summary: StandupSummary? { team.standupSummaries.first { $0.slot == slot } }
    private var standup: TeamStandup? { TeamStandup(slot: slot) }

    var body: some View {
        List {
            Section {
                if let summary { Text(StandupsView.summaryLine(summary)).font(.subheadline) }
                if identity.current != nil { Toggle("Only items for me", isOn: $onlyMine) }
            }
            if let agenda = team.agenda(for: slot) {
                ForEach(AgendaItem.Kind.allCases, id: \.self) { kind in
                    let items = agenda.items(kind).filter(visible)
                    if !items.isEmpty {
                        Section("\(kind.rawValue) (\(items.count))") {
                            ForEach(items) { item in
                                NavigationLink {
                                    StandupItemView(item: item)
                                } label: {
                                    StandupItemRow(item: item)
                                }
                            }
                        }
                    }
                }
                if agenda.items.isEmpty {
                    Section { Text("Nothing on this agenda yet.").foregroundStyle(.secondary) }
                }
                if !agenda.briefings.isEmpty { briefings(agenda.briefings) }
            } else if team.status["agenda.\(slot)"]?.failed == true {
                Section {
                    ContentUnavailableView("The agenda is unavailable", systemImage: "wifi.slash",
                                           description: Text("Connect to the internet and pull to refresh."))
                }
            } else {
                Section { ProgressView("Loading the agenda…") }
            }
            Section {
                if let url = TeamEndpoints.url("meetings/\(slot)/index.html") {
                    Link(destination: url) { Label("Open the web page", systemImage: "safari") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(summary.map(StandupsView.title) ?? slot)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await team.refreshAgenda(slot: slot) }
        .task { await team.refreshAgenda(slot: slot) }
    }

    private func visible(_ item: AgendaItem) -> Bool {
        guard onlyMine, let me = identity.current?.id else { return true }
        return item.isFor(me)
    }

    private func briefings(_ all: [AgendaBriefing]) -> some View {
        let mine = identity.current?.id
        let ordered = all.sorted { ($0.person == mine ? 0 : 1) < ($1.person == mine ? 0 : 1) }
        return Section("Briefings, read before") {
            ForEach(ordered) { briefing in
                Button {
                    if let url = standup?.briefingURL(for: briefing.person) { openURL(url) }
                } label: {
                    HStack {
                        Text(briefing.person == mine ? "\(briefing.name) (me)" : briefing.name)
                        Spacer()
                        Text("\(briefing.items) items").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct StandupItemRow: View {
    let item: AgendaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(3)
            Text(meta).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        var parts: [String] = []
        if !item.forWhom.isEmpty { parts.append("For " + item.forWhom.joined(separator: ", ")) }
        if item.carriedFrom != nil { parts.append("carried over") }
        if let issue = item.issue { parts.append(issue) }
        return parts.joined(separator: " · ")
    }
}

/// One agenda item in full: who it is for, the detail, the options and the recommendation.
struct StandupItemView: View {
    let item: AgendaItem

    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text(item.title).font(.headline)
                if !item.forWhom.isEmpty { LabeledContent("For", value: item.forWhom.joined(separator: ", ")) }
                if !item.addedBy.isEmpty { LabeledContent("Added by", value: item.addedBy) }
                if let slot = item.carriedFrom {
                    LabeledContent("First added to", value: TeamStandup(slot: slot).map(Self.when) ?? slot)
                }
            }
            if !item.detail.isEmpty {
                Section("Detail") { Text(item.detail).textSelection(.enabled) }
            }
            if !item.options.isEmpty {
                Section("Options") {
                    ForEach(Array(item.options.enumerated()), id: \.offset) { index, option in
                        Text("\(index + 1). \(option)")
                    }
                }
            }
            if !item.recommended.isEmpty {
                Section("Recommended") { Text(item.recommended).textSelection(.enabled) }
            }
            if let issue = item.issue, let url = item.issueURL {
                Section {
                    Button { openURL(url) } label: { Label("\(issue) on the board", systemImage: "link") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func when(_ standup: TeamStandup) -> String {
        "\(Lisbon.dayLabel(Lisbon.day(standup.at))) · \(Lisbon.timeLabel(standup.at))"
    }
}
