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
                Picker(String(localized: "Remind me", bundle: .module), selection: $reminders.leadMinutes) {
                    ForEach(ReminderScheduler.leadChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? String(localized: "At the start", bundle: .module) : String(localized: "\(minutes) minutes before", bundle: .module)).tag(minutes)
                    }
                }
                Toggle(String(localized: "Before my picks", bundle: .module), isOn: $reminders.picksOn)
                Toggle(String(localized: "Before team stand-ups", bundle: .module), isOn: $reminders.standupsOn)
                    .disabled(identity?.currentID == nil)
            } footer: {
                Text(identity?.currentID == nil
                     ? "Stand-up reminders need a team identity (Team → Who are you?)."
                     : "Stand-ups come from the team site, with a link to your briefing.")
            }

            Section {
                switch reminders.authorization {
                case .allowed:
                    Label(String(localized: "Notifications are on", bundle: .module), systemImage: "bell.badge")
                case .denied:
                    Button(String(localized: "Turn on notifications in Settings", bundle: .module)) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                case .unknown:
                    Button(String(localized: "Allow reminders", bundle: .module)) {
                        Task {
                            _ = await reminders.requestAuthorization()
                            await reminders.reschedule()
                        }
                    }
                }
            }

            Section {
                if reminders.planned.isEmpty {
                    Text(String(localized: "No reminders to schedule.", bundle: .module)).foregroundStyle(.secondary)
                }
                ForEach(reminders.planned) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Lisbon.dayLabel(Lisbon.day(item.fire))) · \(Lisbon.timeLabel(item.fire))")
                            .font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor)
                        Text(item.title)
                    }
                }
            } header: {
                Text(String(localized: "Scheduled (\(reminders.planned.count) of at most \(ReminderPlan.limit))", bundle: .module))
            } footer: {
                Text(String(localized: "iOS keeps 64 reminders per app; the soonest \(ReminderPlan.limit) are scheduled and the rest follow as these pass. Lisbon time.", bundle: .module))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Reminders", bundle: .module))
        .task { await reminders.reschedule() }
    }
}
