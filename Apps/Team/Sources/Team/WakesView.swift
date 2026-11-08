import SwiftUI

/// Every agent's schedule and its wakes, native, from the team site's `/wakes/` twin (git history, newest first).
struct WakesView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @State private var query = ""

    private var agents: [AgentWakes] {
        team.wakes
            .filter { query.isEmpty || $0.agent.localizedStandardContains(query) }
            .sorted { ($0.lastWake ?? .distantPast) > ($1.lastWake ?? .distantPast) }
    }

    var body: some View {
        let shown = agents
        List {
            if team.wakes.isEmpty {
                Section {
                    if team.refreshing {
                        ProgressView("Loading the wakes…")
                    } else {
                        ContentUnavailableView("The wakes are unavailable", systemImage: "wifi.slash",
                                               description: Text("Connect to the internet and pull to refresh."))
                    }
                }
            }
            if !shown.isEmpty {
                Section("\(shown.count) agents") {
                    ForEach(shown) { agent in
                        NavigationLink {
                            AgentWakesView(agent: agent)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(agent.agent).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(agent.schedule).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                Text(Self.lastLine(agent)).font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            Section {
                Link(destination: TeamEndpoints.base.appendingPathComponent("wakes/")) {
                    Label("Open the web page", systemImage: "safari")
                }
            } footer: {
                Text("From web-summit.sgit.ai, public data, kept on this device for offline use.")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Find an agent")
        .navigationTitle("Wakes")
        .refreshable { await team.refresh(person: identity.current?.id) }
        .task { if team.wakes.isEmpty { await team.refresh(person: identity.current?.id) } }
    }

    static func lastLine(_ agent: AgentWakes) -> String {
        guard let last = agent.lastWake else { return "\(agent.wakes.count) wakes" }
        return "\(agent.wakes.count) wakes · last " + last.formatted(.relative(presentation: .named))
    }
}

/// One agent's wakes, newest first, each with the commit that recorded it.
struct AgentWakesView: View {
    let agent: AgentWakes

    var body: some View {
        List {
            Section {
                Text(agent.schedule).font(.subheadline)
            }
            Section("Wakes") {
                ForEach(Array(agent.wakes.prefix(100).enumerated()), id: \.offset) { _, wake in
                    VStack(alignment: .leading, spacing: 3) {
                        if let at = wake.at {
                            Text(at.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(wake.text).font(.subheadline)
                        if let link = wake.link {
                            Link("The commit", destination: link).font(.caption)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(agent.agent)
        .navigationBarTitleDisplayMode(.inline)
    }
}
