import SwiftUI

/// "Where is everyone": the sessions teammates have on a day, from what the team publishes (each person's command
/// centre). Later, teammates' own picks come from the vaults they share (contracts §5).
struct WhereIsEveryoneView: View {
    @Environment(PlannerStore.self) private var planner
    @Environment(ScheduleStore.self) private var schedule

    var body: some View {
        @Bindable var planner = planner
        let rows = planner.teamSessions(on: planner.day)
        List {
            Section {
                Picker("Day", selection: $planner.day) {
                    ForEach(planner.days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
                }
            } footer: {
                Text("From each teammate's command centre on the team site: the sessions picked for them. Lisbon time.")
            }
            Section {
                if planner.loadingTeam && rows.isEmpty {
                    ProgressView("Loading the team…")
                } else if rows.isEmpty {
                    Text("No teammate has a session on this day yet.").foregroundStyle(.secondary)
                }
                ForEach(rows, id: \.event.id) { row in
                    let picked = schedule.isPicked(row.event)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.event.time).font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor)
                            Text(row.event.title).font(.headline)
                            Text("\(row.event.place) · \(row.people.joined(separator: ", "))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            schedule.toggle(row.event)
                        } label: {
                            Image(systemName: picked ? "star.fill" : "star")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(picked ? "Remove from my day" : "Add to my day")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Where is everyone")
        .task { await planner.loadTeam() }
    }
}
