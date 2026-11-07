import SwiftUI

/// My day: who I am, when my stand-up is, what waits on me, what my agents did.
/// Built from the team site's me.json; opens offline from the cache.
struct TodayView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""

    var body: some View {
        Group {
            if me == SampleMode.readerID {
                // Not on the team: the reader's day is the agenda (and News is one tab away).
                AgendaView()
            } else if let person = data.person(me) {
                PersonBriefView(person: person, isMe: true)
            } else if me.isEmpty {
                ChooseIdentityView()
            } else {
                Page { StateView(phase: data.team.phase, hasData: false, title: "team") { reload() } }
            }
        }
        .navigationTitle(me == SampleMode.readerID ? "Today" : "My day")
        .refreshable { await data.refreshAll(force: true) }
        .task { await data.refreshTeam() }
    }

    private func reload() { Task { await data.refreshTeam(force: true) } }
}

/// Asks who is using the device, from the team list.
struct ChooseIdentityView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @AppStorage(SampleMode.key) private var sampleMode = false

    var body: some View {
        Page(maxWidth: 760) {
            ScreenHeader(kicker: "Today", title: "Who are you?",
                         summary: "Pick yourself once. The app then shows your stand-up, what waits on you and your agents. You can change it in Settings.")
            if let people = data.team.value?.sortedPeople, !people.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: Space.m)], spacing: Space.m) {
                    ForEach(people) { person in
                        Button { me = person.id } label: {
                            Card(padding: Space.m) {
                                HStack(spacing: Space.m) {
                                    Avatar(initials: person.initials, colour: person.tint)
                                    VStack(alignment: .leading) {
                                        Text(person.displayName).font(.headline).foregroundStyle(Palette.ink)
                                        Text(person.role ?? "").font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                StateView(phase: data.team.phase, hasData: false, title: "team") {
                    Task { await data.refreshTeam(force: true) }
                }
            }
            // Two ways in for anyone without a team identity, both always shown (also offline).
            VStack(alignment: .leading, spacing: Space.m) {
                Button {
                    sampleMode = true
                    me = SampleMode.samplePersonID
                } label: {
                    Label("Try with sample data", systemImage: "theatermasks")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Fills the app with made-up people and agents, so you can see every screen")
                .accessibilityIdentifier("pt.trySampleData")
                Button("I am not on the team") { me = SampleMode.readerID }
                    .accessibilityHint("Opens the summit agenda and the news")
                    .accessibilityIdentifier("pt.notOnTeam")
            }
            .padding(.top, Space.s)
        }
    }
}

/// One person's day, used for "My day" and for a teammate opened from the team grid.
struct PersonBriefView: View {
    @Environment(DashboardData.self) private var data
    let person: Wire.Person
    var isMe = false
    @AppStorage(SampleMode.key) private var sampleMode = false

    var body: some View {
        Page {
            HStack(alignment: .center, spacing: Space.l) {
                Avatar(initials: person.initials, colour: person.tint, size: 56)
                ScreenHeader(kicker: isMe ? greeting : (person.role ?? "Team"),
                             title: isMe ? (person.first ?? person.displayName) : person.displayName,
                             summary: person.levelName)
            }
            FreshnessLabel(updated: data.team.updated, failed: data.team.failed)

            StandupCard(person: person)
            if isMe {
                // The team session's "my next 3 hours": picks and stand-ups with a Lisbon countdown.
                NextHoursCard()
            }

            StatGrid {
                StatTile(label: "Only you", value: "\(person.onlyYou ?? 0)", detail: "nobody else can do these",
                         tone: (person.onlyYou ?? 0) > 0 ? .bad : .good)
                StatTile(label: "Decide", value: "\(person.decide ?? 0)", detail: "decisions waiting",
                         tone: (person.decide ?? 0) > 0 ? .warn : .good)
                StatTile(label: "Overdue", value: "\(person.overdue ?? 0)", detail: "of \(person.open ?? 0) open",
                         tone: (person.overdue ?? 0) > 0 ? .bad : .good)
                StatTile(label: "Due soon", value: "\(person.soon ?? 0)")
                StatTile(label: "Agents active", value: "\(person.activeAgents)",
                         detail: "of \(person.agents?.count ?? 0)", tone: .good, trend: person.daily ?? [])
            }

            Columns {
                if let urgent = person.urgent, !urgent.isEmpty {
                    TitledCard("Most urgent", kicker: "\(urgent.count) items") {
                        ForEach(urgent) { item in
                            InfoRow(title: "\(item.id) · \(item.title ?? "")",
                                    detail: [item.due, item.status].compactMap { $0 }.joined(separator: " · "),
                                    symbol: item.late == true ? "exclamationmark.circle.fill" : "circle",
                                    tint: item.late == true ? Palette.red : Palette.muted)
                        }
                    }
                }
                if let decisions = person.decisions, !decisions.isEmpty {
                    TitledCard("Decisions waiting", kicker: "Decide") {
                        ForEach(decisions, id: \.self) { decision in
                            if let url = decision.sourceURL {
                                WebLinkRow(title: decision.what ?? "Decision", url: url, symbol: "checkmark.circle")
                            } else {
                                InfoRow(title: decision.what ?? "Decision", detail: decision.issue, symbol: "checkmark.circle")
                            }
                        }
                    }
                }
            } trailing: {
                if let agents = person.agents, !agents.isEmpty {
                    TitledCard(isMe ? "What my agents did" : "Their agents", kicker: "\(person.activeAgents) active") {
                        ForEach(agents.sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }.prefix(8), id: \.self) { agent in
                            InfoRow(title: agent.name ?? "agent", detail: agent.last, date: agent.lastDate,
                                    symbol: agent.status == "active" ? "bolt.fill" : "moon.zzz",
                                    tint: agent.status == "active" ? Palette.green : Palette.muted)
                        }
                    }
                }
                if let messages = person.messages, !messages.isEmpty {
                    TitledCard("Messages", kicker: "Inbox") {
                        ForEach(messages, id: \.self) { message in
                            InfoRow(title: message.subject ?? "", detail: message.from, date: message.date, symbol: "envelope")
                        }
                    }
                }
            }

            if !sampleMode {
            Card {
                NavigationLink {
                    CommandCentreView(personID: person.id, name: person.first ?? person.displayName)
                } label: {
                    Label("All \(person.open ?? 0) open issues, by workstream", systemImage: "rectangle.3.group")
                        .font(.subheadline)
                }
                WebLinkRow(title: "The command centre on the web", url: person.commandCentreURL, symbol: "globe")
            }
            }
        }
        .navigationTitle(isMe ? "My day" : person.displayName)
        .webTwin(person.commandCentreURL, title: "Command centre")
    }

    private var greeting: String {
        let hour = Lisbon.calendar.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
    }
}

/// When the next stand-up is, counting down, with the briefing one tap away.
struct StandupCard: View {
    let person: Wire.Person
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let date = person.standupDate {
            Card {
                // Side by side normally; stacked at accessibility text sizes or on a narrow screen.
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: Space.l))
                layout {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Kicker("Next stand-up", color: Palette.green)
                        Text(date, format: .dateTime.weekday(.wide).hour().minute())
                            .font(Typo.title)
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            // The relative format already says "in 1 day" or "2 hours ago".
                            Text(date, format: .relative(presentation: .numeric, unitsStyle: .wide))
                        }
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                    }
                    if !typeSize.isAccessibilitySize { Spacer() }
                    if let briefing = person.briefingURL {
                        NavigationLink {
                            WebPage(url: briefing, title: "Briefing")
                        } label: {
                            Label("My briefing", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

#Preview("My day · iPhone") {
    NavigationStack { TodayView() }.environment(PreviewSamples.data()).teamFeatures().phonePreview()
}

#Preview("My day · iPad") {
    NavigationStack { TodayView() }.environment(PreviewSamples.data()).teamFeatures().padPreview()
}
