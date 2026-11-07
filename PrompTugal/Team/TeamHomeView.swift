import SwiftUI

/// Entry view for the team: "Who are you?" until a person is chosen, then their home: what needs them, the next
/// stand-up and briefing, their agents, and my day. The design session's dashboards build on the same models.
struct TeamHomeView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let current = identity.current {
                home(for: current.id)
            } else {
                WhoAreYouView()
            }
        }
        .task(id: identity.current?.id) {
            if team.me == nil || identity.current != nil { await team.refresh(person: identity.current?.id) }
        }
    }

    private func home(for id: String) -> some View {
        let person = team.me?.person(id)
        let centre = team.centre(for: id)
        return List {
            Section {
                HStack(spacing: 12) {
                    PersonBadge(name: person?.name ?? identity.current?.name ?? id,
                                colour: person?.colour ?? identity.current?.colour ?? "#666666")
                    VStack(alignment: .leading) {
                        Text(person?.name ?? identity.current?.name ?? id).font(.headline)
                        Text(identity.verified ? "Verified by your team vault" : "Chosen on this device (a view, not a sign-in)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let person {
                    HStack {
                        Counter(value: person.onlyYou, label: "only you")
                        Counter(value: person.decide, label: "decide")
                        Counter(value: person.overdue, label: "overdue")
                        Counter(value: person.soon, label: "soon")
                    }
                }
            }

            if let standup = team.upcomingStandups().first {
                Section("Next stand-up") {
                    Button {
                        openURL(standup.briefingURL(for: id))
                    } label: {
                        Label("\(Lisbon.dayLabel(Lisbon.day(standup.at))) · \(Lisbon.timeLabel(standup.at)) Lisbon · my briefing",
                              systemImage: "person.3")
                    }
                }
            }

            Section {
                NavigationLink { MyDayView() } label: { Label("My day", systemImage: "star") }
                NavigationLink { WhereIsEveryoneView() } label: { Label("Where is everyone", systemImage: "person.3.sequence") }
                NavigationLink { PlannerView() } label: { Label("Plan my day", systemImage: "wand.and.stars") }
                if let url = person?.centreURL {
                    Button { openURL(url) } label: { Label("My command centre (web)", systemImage: "rectangle.grid.2x2") }
                }
            }

            if let person, !person.urgent.isEmpty {
                Section("Urgent") {
                    ForEach(person.urgent, id: \.self) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.id) · \(item.due)").font(.caption).foregroundStyle(item.late ? .red : .secondary)
                            Text(item.title)
                        }
                    }
                }
            }

            if let decisions = centre?.decisions, !decisions.isEmpty {
                Section("Decisions waiting") {
                    ForEach(decisions, id: \.self) { decision in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(decision.what).font(.subheadline.weight(.semibold))
                            if !decision.recommend.isEmpty {
                                Text(decision.recommend).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }
                    }
                }
            } else if let person, !person.decisions.isEmpty {
                Section("Decisions waiting") {
                    ForEach(person.decisions, id: \.self) { Text($0.what) }
                }
            }

            if let person, !person.agents.isEmpty {
                Section("My agents") {
                    ForEach(person.agents, id: \.self) { agent in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.name).font(.subheadline.weight(.semibold))
                            Text([agent.status, agent.lastAt.map { $0.formatted(.relative(presentation: .named)) } ?? "never"]
                                .joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            if !agent.last.isEmpty { Text(agent.last).font(.caption).lineLimit(2) }
                        }
                    }
                }
            }

            Section {
                Button("I am someone else") { identity.clear() }
            } footer: {
                if let me = team.me {
                    Text("From web-summit.sgit.ai \(me.version), public data, kept on this device for offline use.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(person?.first ?? "Team")
        .refreshable { await team.refresh(person: id) }
    }
}

/// "Who are you?": picks a person from the team's people list.
struct WhoAreYouView: View {
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity

    var body: some View {
        List {
            Section {
                if let people = team.me?.people {
                    ForEach(people) { person in
                        Button {
                            identity.choose(person)
                        } label: {
                            HStack(spacing: 12) {
                                PersonBadge(name: person.name, colour: person.colour)
                                VStack(alignment: .leading) {
                                    Text(person.name).font(.headline).foregroundStyle(.primary)
                                    Text(person.role).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                if person.badge > 0 {
                                    Text("\(person.badge)").font(.caption.monospacedDigit().bold())
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                }
                            }
                        }
                    }
                } else if team.refreshing {
                    ProgressView("Loading the team…")
                } else {
                    ContentUnavailableView("The team list is unavailable", systemImage: "wifi.slash",
                                           description: Text("Connect to the internet and pull to refresh."))
                }
            } header: {
                Text("Who are you?")
            } footer: {
                Text("This chooses what the app shows you, as on the team site. It is not a sign-in. Opening your team vault verifies it.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Team")
        .refreshable { await team.refresh() }
    }
}

struct PersonBadge: View {
    let name: String
    let colour: String

    var body: some View {
        Text(name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased())
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color(teamHex: colour) ?? .gray))
            .accessibilityHidden(true)
    }
}

private struct Counter: View {
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

extension Color {
    /// "#RRGGBB", as the team site writes colours.
    init?(teamHex hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
