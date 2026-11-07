import SwiftUI

/// "Help me plan my presence": the day's picks and stand-ups, clashes, gaps, and a proposed day to accept.
struct PlannerView: View {
    @Environment(PlannerStore.self) private var planner
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(\.horizontalSizeClass) private var width
    @State private var rejected: Set<String> = []
    @State private var swapped: [String: DayPlanner.Proposal] = [:]
    @State private var accepted = 0

    var body: some View {
        @Bindable var planner = planner
        let plan = planner.plan
        let bases = plan.proposals.filter { !rejected.contains($0.id) }
        let proposals = bases.map { swapped[$0.id] ?? $0 }
        HStack(spacing: 0) {
        List {
            Section {
                Picker("Day", selection: $planner.day) {
                    ForEach(planner.days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
                }
                Toggle("Official programme only", isOn: $planner.preferences.officialOnly)
            } footer: {
                Text("Walking times are estimates: 5 minutes between rooms at the venue, 25 to anywhere else. All times are Lisbon time.")
            }

            if !plan.clashes.isEmpty {
                Section("Clashes") {
                    ForEach(plan.clashes, id: \.self) { clash in
                        Label {
                            Text(clash.travel
                                 ? "\(clash.first.title) → \(clash.second.title): \(clash.minutes) min short to walk between them"
                                 : "\(clash.first.title) and \(clash.second.title) overlap by \(clash.minutes) min")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Your day") {
                if plan.fixed.isEmpty {
                    Text("No picks or stand-ups on this day yet.").foregroundStyle(.secondary)
                }
                ForEach(plan.fixed) { item in itemRow(item, symbol: item.kind == .standup ? "person.3" : "star.fill") }
            }

            if !plan.gaps.isEmpty {
                Section("Free time") {
                    ForEach(plan.gaps, id: \.self) { gap in
                        Text("\(Lisbon.timeLabel(gap.start)) to \(Lisbon.timeLabel(gap.end)) · \(gap.minutes) min")
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }

            Section {
                if proposals.isEmpty {
                    Text(planner.agenda.isEmpty ? "The agenda is still loading." : "Nothing more fits this day.")
                        .foregroundStyle(.secondary)
                }
                ForEach(bases) { base in
                    let proposal = swapped[base.id] ?? base
                    let options = [base] + (plan.alternatives[base.id] ?? [])
                    VStack(alignment: .leading, spacing: 6) {
                        itemRow(proposal.item, symbol: "sparkles")
                        if !proposal.reasons.isEmpty {
                            Text(proposal.reasons.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Add") { planner.accept([proposal]); accepted += 1 }
                                .buttonStyle(.borderedProminent)
                            if options.count > 1 {
                                Button("Another") {
                                    let index = options.firstIndex { $0.id == proposal.id } ?? 0
                                    swapped[base.id] = options[(index + 1) % options.count]
                                }
                                .buttonStyle(.bordered)
                            }
                            Button("Skip") { rejected.insert(base.id) }.buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Proposed")
            } footer: {
                if identity.current != nil {
                    Text("Sessions the team picked for you rank first, then sessions teammates have, then ones like your picks.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(maxWidth: width == .regular ? 440 : .infinity)
        if width == .regular {
            Divider()
            // iPad: the proposed day drawn as a time line beside the list
            DayTimelineView(day: planner.day, items: plan.fixed + proposals.map(\.item))
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
        }
        }
        .navigationTitle("Plan my day")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add all") {
                    planner.accept(proposals)
                    accepted += proposals.count
                }
                .disabled(proposals.isEmpty)
            }
        }
        .sensoryFeedback(.success, trigger: accepted)
        .task { if identity.current != nil { await planner.loadTeam() } }
        .onChange(of: planner.day) { rejected = []; swapped = [:] }
    }

    private func itemRow(_ item: DayPlanner.Item, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Lisbon.timeLabel(item.start))–\(Lisbon.timeLabel(item.end))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(item.title).font(.headline)
                if !item.place.isEmpty { Text(item.place).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }
}
