import SwiftUI
import UIKit
import PTCore
import PTWeb

/// Entry view for reminders: how long before, which kinds, and what is scheduled.
public struct ReminderSettingsView: View {
    public init() {}

    @Environment(ReminderScheduler.self) private var reminders
    @Environment(\.agendaIdentity) private var identity
    @Environment(\.openURL) private var openURL

    public var body: some View {
        @Bindable var reminders = reminders
        List {
            Section {
                Picker("Remind me", selection: $reminders.leadMinutes) {
                    ForEach(ReminderScheduler.leadChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "At the start" : "\(minutes) minutes before").tag(minutes)
                    }
                }
                Toggle("Before my picks", isOn: $reminders.picksOn)
                Toggle("Before team stand-ups", isOn: $reminders.standupsOn)
                    .disabled(identity?.currentID == nil)
            } footer: {
                Text(identity?.currentID == nil
                     ? "Stand-up reminders need a team identity (Team → Who are you?)."
                     : "Stand-ups come from the team site, with a link to your briefing.")
            }

            Section {
                switch reminders.authorization {
                case .allowed:
                    Label("Notifications are on", systemImage: "bell.badge")
                case .denied:
                    Button("Turn on notifications in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                case .unknown:
                    Button("Allow reminders") {
                        Task {
                            _ = await reminders.requestAuthorization()
                            await reminders.reschedule()
                        }
                    }
                }
            }

            Section {
                if reminders.planned.isEmpty {
                    Text("No reminders to schedule.").foregroundStyle(.secondary)
                }
                ForEach(reminders.planned) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Lisbon.dayLabel(Lisbon.day(item.fire))) · \(Lisbon.timeLabel(item.fire))")
                            .font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor)
                        Text(item.title)
                    }
                }
            } header: {
                Text("Scheduled (\(reminders.planned.count) of at most \(ReminderPlan.limit))")
            } footer: {
                Text("iOS keeps 64 reminders per app; the soonest \(ReminderPlan.limit) are scheduled and the rest follow as these pass. Lisbon time.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reminders")
        .task { await reminders.reschedule() }
    }
}
