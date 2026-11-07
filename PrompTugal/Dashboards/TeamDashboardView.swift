import Charts
import SwiftUI

/// What the team is doing: everyone's load at a glance, and a chart of who needs help.
struct TeamDashboardView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @State private var sort: Sort = .attention

    enum Sort: String, CaseIterable, Identifiable {
        case attention = "Needs attention", name = "Name", level = "Level"
        var id: Self { self }
    }

    private var people: [Wire.Person] {
        let all = data.team.value?.sortedPeople ?? []
        switch sort {
        case .attention: return all.sorted { $0.attention > $1.attention }
        case .name: return all.sorted { $0.displayName < $1.displayName }
        case .level: return all.sorted { ($0.level ?? 0) > ($1.level ?? 0) }
        }
    }

    var body: some View {
        Page {
            ScreenHeader(kicker: "Team", title: "What the team is doing",
                         summary: "Everyone's load from the board: what only they can do, what waits on their decision, what is late.")
            HStack {
                FreshnessLabel(updated: data.team.updated, failed: data.team.failed)
                Spacer()
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }
            if people.isEmpty {
                StateView(phase: data.team.phase, hasData: false, title: "team") {
                    Task { await data.refreshTeam(force: true) }
                }
            } else {
                totals
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: Space.m)], spacing: Space.m) {
                    ForEach(people) { person in
                        NavigationLink {
                            PersonBriefView(person: person, isMe: person.id == me)
                        } label: {
                            PersonCard(person: person, isMe: person.id == me)
                        }
                        .buttonStyle(.plain)
                    }
                }
                LoadChart(people: people)
                StandupTimeline(people: people)
            }
        }
        .navigationTitle("Team")
        .refreshable { await data.refreshTeam(force: true) }
        .task { await data.refreshTeam() }
        .webTwin(TeamSite.base.appendingPathComponent("team/"), title: "Team")
    }

    private var totals: some View {
        let all = data.team.value?.sortedPeople ?? []
        return StatGrid {
            StatTile(label: "People", value: "\(all.count)")
            StatTile(label: "Only one person can do", value: "\(all.reduce(0) { $0 + ($1.onlyYou ?? 0) })", tone: .bad)
            StatTile(label: "Decisions waiting", value: "\(all.reduce(0) { $0 + ($1.decide ?? 0) })", tone: .warn)
            StatTile(label: "Overdue", value: "\(all.reduce(0) { $0 + ($1.overdue ?? 0) })", tone: .bad)
            StatTile(label: "Agents active", value: "\(all.reduce(0) { $0 + $1.activeAgents })", tone: .good)
        }
    }
}

/// One person: avatar, role, level, counts, and their activity over ten days.
struct PersonCard: View {
    let person: Wire.Person
    var isMe = false

    var body: some View {
        Card(padding: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                Avatar(initials: person.initials, colour: person.tint, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(person.displayName).font(.headline).foregroundStyle(Palette.ink)
                        if isMe { Text("you").font(.caption2.weight(.bold)).foregroundStyle(Palette.red) }
                        if person.focus == true {
                            Image(systemName: "scope").font(.caption).foregroundStyle(Palette.red)
                                .accessibilityLabel("In focus")
                        }
                    }
                    Text(person.role ?? "").font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                }
            }
            LevelBar(level: person.level ?? 0, name: person.levelName)
            HStack(spacing: Space.xs) {
                CountPill(count: person.onlyYou ?? 0, label: "only you")
                CountPill(count: person.decide ?? 0, label: "decide", color: Palette.amber)
                CountPill(count: person.overdue ?? 0, label: "overdue")
            }
            HStack {
                if let daily = person.daily, daily.count > 1 {
                    Sparkline(values: daily, color: person.tint).frame(height: 18)
                }
                Text("\(person.activeAgents)/\(person.agents?.count ?? 0) agents")
                    .font(.caption2).foregroundStyle(Palette.muted).fixedSize()
            }
            if let next = person.next?.step {
                Label("Next: \(next)", systemImage: "arrow.forward.circle").font(.caption).foregroundStyle(Palette.green)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(person.displayName)'s day")
    }
}

/// Onboarding level, 1 to 6, as six segments.
struct LevelBar: View {
    let level: Int
    let name: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                ForEach(1...6, id: \.self) { step in
                    Capsule().fill(step <= level ? Palette.green : Palette.rule).frame(height: 4)
                }
            }
            if let name { Text(name).font(.caption2).foregroundStyle(Palette.muted).lineLimit(1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of 6\(name.map { ", \($0)" } ?? "")")
    }
}

/// Stacked bars: only-you, decide and overdue per person.
struct LoadChart: View {
    let people: [Wire.Person]

    private struct Bar: Identifiable {
        let id = UUID()
        let person: String
        let kind: String
        let count: Int
    }

    private var bars: [Bar] {
        people.flatMap { person in
            [Bar(person: person.first ?? person.displayName, kind: "Only you", count: person.onlyYou ?? 0),
             Bar(person: person.first ?? person.displayName, kind: "Decide", count: person.decide ?? 0),
             Bar(person: person.first ?? person.displayName, kind: "Overdue", count: person.overdue ?? 0)]
        }
    }

    var body: some View {
        TitledCard("Who needs help", kicker: "Load by person") {
            Chart(bars) { bar in
                BarMark(x: .value("Count", bar.count), y: .value("Person", bar.person))
                    .foregroundStyle(by: .value("Kind", bar.kind))
            }
            .chartForegroundStyleScale(["Only you": Palette.red, "Decide": Palette.amber, "Overdue": Palette.muted])
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: CGFloat(max(people.count, 1)) * 30 + 40)
        }
    }
}

/// Everyone's next stand-up on one time line.
struct StandupTimeline: View {
    let people: [Wire.Person]

    private struct Slot: Identifiable {
        let id: String
        let name: String
        let date: Date
        let tint: Color
    }

    var body: some View {
        let slots = people.compactMap { person in
            person.standupDate.map { Slot(id: person.id, name: person.first ?? person.displayName, date: $0, tint: person.tint) }
        }
        if !slots.isEmpty {
            TitledCard("Stand-ups", kicker: "Next for each person") {
                Chart {
                    ForEach(slots) { slot in
                        PointMark(x: .value("Time", slot.date), y: .value("Person", slot.name))
                            .foregroundStyle(slot.tint)
                            .symbolSize(90)
                    }
                    RuleMark(x: .value("Now", Date.now))
                        .foregroundStyle(Palette.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .frame(height: CGFloat(slots.count) * 26 + 40)
            }
        }
    }
}

#Preview("Team") {
    NavigationStack { TeamDashboardView() }.environment(DashboardData())
}
