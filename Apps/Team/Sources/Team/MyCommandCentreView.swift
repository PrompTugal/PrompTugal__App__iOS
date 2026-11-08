import SwiftUI

/// "My command centre", native: what needs me (decisions, late and open issues), my workstreams and agents, and what
/// happened lately. Read from `people/<id>/app/data.json` through `TeamStore`, kept on the device; the web command
/// centre stays one tap away as a fallback.
struct MyCommandCentreView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity

    var body: some View {
        Group {
            if let current = identity.current {
                content(for: current.id)
            } else {
                WhoAreYouView()
            }
        }
        .navigationTitle("My command centre")
        .task(id: identity.current?.id) {
            guard let id = identity.current?.id else { return }
            if team.me == nil { await team.refresh(person: id) } else { await team.refreshCentre(for: id) }
        }
    }

    @ViewBuilder
    private func content(for id: String) -> some View {
        let person = team.me?.person(id)
        let state = team.status["centre.\(id)"]
        if let centre = team.centre(for: id) {
            CentreList(centre: centre, person: person, updated: state?.updated, failed: state?.failed ?? false)
                .refreshable { await team.refreshCentre(for: id) }
        } else {
            List {
                Section {
                    if state?.failed == true {
                        ContentUnavailableView("Your command centre is unavailable", systemImage: "wifi.slash",
                                               description: Text("Connect to the internet and pull to refresh."))
                    } else {
                        ProgressView("Loading your command centre…")
                    }
                }
                Section { webLink(person?.centreURL ?? TeamEndpoints.base.appendingPathComponent("people/\(id)/app/")) }
            }
            .listStyle(.insetGrouped)
            .refreshable { await team.refreshCentre(for: id) }
        }
    }

    private func webLink(_ url: URL) -> some View {
        Link(destination: url) { Label("Open the web command centre", systemImage: "safari") }
    }
}

private struct CentreList: View {
    let centre: CommandCentre
    let person: TeamPerson?
    let updated: Date?
    let failed: Bool

    private var openIssues: [CommandCentre.Issue] { centre.issues.filter { ($0.mine || $0.named) && !$0.isDone } }
    private var lateIssues: [CommandCentre.Issue] { openIssues.filter(\.isLate) }

    var body: some View {
        List {
            header
            if !centre.decisions.isEmpty {
                Section("Decisions waiting (\(centre.decisions.count))") {
                    ForEach(centre.decisions, id: \.self) { decision in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(decision.what).font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                if !decision.issue.isEmpty { Text(decision.issue) }
                                if let since = decision.since {
                                    Text("since " + since.formatted(.relative(presentation: .named)))
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if !decision.recommend.isEmpty {
                                Text("Recommended: " + decision.recommend).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(4)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Section("Issues") {
                NavigationLink {
                    CentreIssuesView(centre: centre, title: "My issues", issueIDs: nil)
                } label: {
                    LabeledContent("Open", value: "\(openIssues.count)")
                }
                if !lateIssues.isEmpty {
                    NavigationLink {
                        CentreIssuesView(centre: centre, title: "Overdue", issueIDs: nil, initial: .overdue)
                    } label: {
                        LabeledContent("Overdue", value: "\(lateIssues.count)").foregroundStyle(.red)
                    }
                }
            }
            if !centre.workstreams.isEmpty {
                Section("Workstreams") {
                    ForEach(centre.workstreams) { stream in
                        NavigationLink {
                            CentreIssuesView(centre: centre, title: stream.name, issueIDs: Set(stream.issues))
                        } label: {
                            workstreamRow(stream)
                        }
                    }
                }
            }
            if !centre.agents.isEmpty {
                Section("My agents") {
                    ForEach(centre.agents) { agent in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(agent.short.isEmpty ? agent.name : agent.short).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(agent.status).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(Self.agentLine(agent)).font(.caption).foregroundStyle(.secondary)
                            if !agent.lastSubject.isEmpty { Text(agent.lastSubject).font(.caption).lineLimit(2) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if !centre.activity.isEmpty {
                Section("Recent activity") {
                    ForEach(Array(centre.activity.prefix(12))) { commit in commitRow(commit) }
                }
            }
            if !centre.messages.isEmpty {
                Section("Messages") {
                    ForEach(Array(centre.messages.prefix(8))) { commit in commitRow(commit) }
                }
            }
            if !centre.sessions.isEmpty {
                Section("Summit sessions picked for me (\(centre.sessions.count))") {
                    ForEach(Array(centre.sessions.prefix(10))) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                            Text([session.day, String(session.time.prefix(11)), session.stage]
                                .filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Section {
                Link(destination: person?.centreURL ?? TeamEndpoints.base.appendingPathComponent("people/\(centre.person.id)/app/")) {
                    Label("Open the web command centre", systemImage: "safari")
                }
            } footer: {
                Text("From web-summit.sgit.ai \(centre.version), public data, kept on this device for offline use.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var header: some View {
        Section {
            HStack(spacing: 12) {
                PersonBadge(name: centre.person.name, colour: person?.colour ?? "#666666")
                VStack(alignment: .leading) {
                    Text(centre.person.name).font(.headline)
                    if !centre.person.role.isEmpty {
                        Text(centre.person.role).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            if let person {
                HStack {
                    CentreStat(value: person.onlyYou, label: "only you")
                    CentreStat(value: person.decide, label: "decide")
                    CentreStat(value: person.overdue, label: "overdue")
                    CentreStat(value: person.soon, label: "soon")
                }
            }
            if let updated {
                Text((failed ? "Could not refresh; showing " : "Updated ") + updated.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundStyle(failed ? .red : .secondary)
            }
        }
    }

    private func workstreamRow(_ stream: CommandCentre.Workstream) -> some View {
        let ids = Set(stream.issues)
        let open = centre.issues.filter { ids.contains($0.id) && !$0.isDone }
        let late = open.filter(\.isLate).count
        let parts: [String?] = ["\(open.count) open", late > 0 ? "\(late) overdue" : nil,
                               stream.agent.isEmpty ? nil : stream.agent]
        return VStack(alignment: .leading, spacing: 2) {
            Text(stream.name).font(.subheadline.weight(.semibold))
            if !stream.goal.isEmpty { Text(stream.goal).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            Text(parts.compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(late > 0 ? .red : .secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private static func agentLine(_ agent: CommandCentre.Agent) -> String {
        let last = agent.lastAt.map { "last " + $0.formatted(.relative(presentation: .named)) } ?? "never run"
        return ["\(agent.commits24h) commits in 24 h", "\(agent.commits7d) in 7 days", last].joined(separator: " · ")
    }

    private func commitRow(_ commit: CommandCentre.Activity) -> some View {
        let meta: [String?] = [commit.agent, commit.at.map { $0.formatted(.relative(presentation: .named)) }]
        return VStack(alignment: .leading, spacing: 2) {
            Text(commit.subject).font(.subheadline).lineLimit(3)
            Text(meta.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CentreStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack {
            Text("\(value)").font(.title2.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The issues behind a count: filtered, searchable, soonest due first.
struct CentreIssuesView: View {
    let centre: CommandCentre
    let title: String
    /// Only these issues (a workstream's); nil for every issue that is mine or names me.
    let issueIDs: Set<String>?
    var initial: Filter = .open

    @State private var filter: Filter?
    @State private var query = ""

    enum Filter: String, CaseIterable, Identifiable {
        case open = "Open", overdue = "Overdue", named = "Named for me", done = "Done", all = "All"
        var id: Self { self }
    }

    private var current: Filter { filter ?? initial }

    private var issues: [CommandCentre.Issue] {
        centre.issues
            .filter { issue in
                (issueIDs?.contains(issue.id) ?? (issue.mine || issue.named)) && matches(issue)
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private func matches(_ issue: CommandCentre.Issue) -> Bool {
        if !query.isEmpty, !issue.title.localizedStandardContains(query), !issue.id.localizedStandardContains(query) {
            return false
        }
        switch current {
        case .open: return !issue.isDone
        case .overdue: return issue.isLate
        case .named: return issue.named && !issue.isDone
        case .done: return issue.isDone
        case .all: return true
        }
    }

    var body: some View {
        let shown = issues
        List {
            Section {
                Picker("Show", selection: Binding(get: { current }, set: { filter = $0 })) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section("\(shown.count) issues") {
                if shown.isEmpty { Text("Nothing here.").foregroundStyle(.secondary) }
                ForEach(Array(shown.prefix(300))) { CentreIssueRow(issue: $0) }
                if shown.count > 300 {
                    Text("and \(shown.count - 300) more").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Find an issue")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CentreIssueRow: View {
    let issue: CommandCentre.Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(issue.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                if issue.named {
                    Image(systemName: "person.fill.checkmark").font(.caption2).accessibilityLabel("Named for me")
                }
                Spacer()
                Text(issue.status).font(.caption2).foregroundStyle(issue.isDone ? .green : .secondary)
            }
            Text(issue.title).font(.subheadline).strikethrough(issue.isDone)
            if !issue.due.isEmpty {
                Label(issue.due, systemImage: issue.isLate ? "exclamationmark.circle.fill" : "calendar")
                    .font(.caption2).foregroundStyle(issue.isLate ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
