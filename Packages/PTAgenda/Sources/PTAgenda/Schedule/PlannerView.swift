import SwiftUI
import PTCore
import PTWeb

/// "Help me plan my presence": the day's picks and stand-ups, clashes, gaps, and a proposed day to accept.
public struct PlannerView: View {
    public init() {}

    @Environment(PlannerStore.self) private var planner
    @Environment(\.agendaIdentity) private var identity
    @Environment(\.horizontalSizeClass) private var width
    @State private var rejected: Set<String> = []
    @State private var swapped: [String: DayPlanner.Proposal] = [:]
    @State private var accepted = 0

    public var body: some View {
        @Bindable var planner = planner
        let plan = planner.plan
        let bases = plan.proposals.filter { !rejected.contains($0.id) }
        let proposals = bases.map { swapped[$0.id] ?? $0 }
        HStack(spacing: 0) {
        List {
            Section {
                Picker(String(localized: "Day", bundle: .module), selection: $planner.day) {
                    ForEach(planner.days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
                }
                Toggle(String(localized: "Official programme only", bundle: .module), isOn: $planner.preferences.officialOnly)
            } footer: {
                Text(String(localized: "Walking times are estimates: 5 minutes between rooms at the venue, 25 to anywhere else. All times are Lisbon time.", bundle: .module))
            }

            if !plan.clashes.isEmpty {
                Section(String(localized: "Clashes", bundle: .module)) {
                    ForEach(plan.clashes, id: \.self) { clash in
                        Label {
                            Text(clash.travel
                                 ? String(localized: "\(clash.first.title) → \(clash.second.title): \(clash.minutes) min short to walk between them", bundle: .module)
                                 : String(localized: "\(clash.first.title) and \(clash.second.title) overlap by \(clash.minutes) min", bundle: .module))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section(String(localized: "Your day", bundle: .module)) {
                if plan.fixed.isEmpty {
                    Text(String(localized: "No picks or stand-ups on this day yet.", bundle: .module)).foregroundStyle(.secondary)
                }
                ForEach(plan.fixed) { item in itemRow(item, symbol: item.kind == .standup ? "person.3" : "star.fill") }
            }

            if !plan.gaps.isEmpty {
                Section(String(localized: "Free time", bundle: .module)) {
                    ForEach(plan.gaps, id: \.self) { gap in
                        Text(String(localized: "\(Lisbon.timeLabel(gap.start)) to \(Lisbon.timeLabel(gap.end)) · \(gap.minutes) min", bundle: .module))
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }

            Section {
                if proposals.isEmpty {
                    Text(planner.agenda.isEmpty ? String(localized: "The agenda is still loading.", bundle: .module) : String(localized: "Nothing more fits this day.", bundle: .module))
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
                            Button(String(localized: "Add", bundle: .module)) { planner.accept([proposal]); accepted += 1 }
                                .buttonStyle(.borderedProminent)
                            if options.count > 1 {
                                Button(String(localized: "Another", bundle: .module)) {
                                    let index = options.firstIndex { $0.id == proposal.id } ?? 0
                                    swapped[base.id] = options[(index + 1) % options.count]
                                }
                                .buttonStyle(.bordered)
                            }
                            Button(String(localized: "Skip", bundle: .module)) { rejected.insert(base.id) }.buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(String(localized: "Proposed sessions", bundle: .module))
            } footer: {
                if identity?.currentID != nil {
                    Text(String(localized: "Sessions the team picked for you rank first, then sessions teammates have, then ones like your picks.", bundle: .module))
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
        .navigationTitle(String(localized: "Plan my day", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Add all", bundle: .module)) {
                    planner.accept(proposals)
                    accepted += proposals.count
                }
                .disabled(proposals.isEmpty)
            }
        }
        .sensoryFeedback(.success, trigger: accepted)
        .task { if identity?.currentID != nil { await planner.loadTeam() } }
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
