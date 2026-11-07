import SwiftUI

/// Entry view for the schedule: my picks (website and app, one list) and, for the team, my stand-ups, by Lisbon day.
struct MyDayView: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(TeamStore.self) private var team
    @Environment(TeamIdentityStore.self) private var identity
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(PlannerStore.self) private var planner
    @Environment(AppBridge.self) private var bridge
    @Environment(\.openURL) private var openURL

    private struct Row: Identifiable {
        let id: String
        let start: Date?
        let title: String
        let detail: String
        let url: URL?
        let pick: SchedulePick?
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                header(now: context.date)
                let days = rowsByDay(now: context.date)
                if days.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing in your day yet", systemImage: "star")
                    } description: {
                        Text("Add sessions from the agenda here or with “Add to my day” on promptugal.news. Both make one list.")
                    } actions: {
                        NavigationLink("Help me plan my day") { PlannerView() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                ForEach(days, id: \.0) { day, rows in
                    Section(day == "" ? "No time yet" : Lisbon.dayLabel(day)) {
                        ForEach(rows) { row in rowView(row, now: context.date) }
                    }
                }
                Section {
                    NavigationLink { PlannerView() } label: {
                        Label("Help me plan my presence", systemImage: "wand.and.stars")
                    }
                    NavigationLink { ReminderSettingsView() } label: {
                        Label("Reminders", systemImage: "bell")
                            .badge(reminders.planned.count)
                    }
                } footer: {
                    Text(footer)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("My day")
        .refreshable { await team.refresh(person: identity.current?.id) }
    }

    @ViewBuilder private func header(now: Date) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lisbon time · \(Lisbon.timeLabel(now))")
                    .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                if let next = nextRow(now: now) {
                    Text("Next: \(next.title)").font(.headline)
                    if let start = next.start {
                        Text("\(Lisbon.timeLabel(start)) · in \(minutesText(start.timeIntervalSince(now)))")
                            .font(.subheadline).foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text("\(schedule.picks.count) picks").font(.headline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func rowView(_ row: Row, now: Date) -> some View {
        let past = (row.start ?? .distantFuture) < now
        return Button {
            if let url = row.url { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.start.map(Lisbon.timeLabel) ?? "Time not known")
                    .font(.caption.monospacedDigit()).foregroundStyle(Color.accentColor)
                Text(row.title).font(.headline).foregroundStyle(.primary)
                if !row.detail.isEmpty {
                    Text(row.detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .opacity(past ? 0.5 : 1)
        }
        .swipeActions {
            if let pick = row.pick {
                Button("Remove", role: .destructive) { schedule.toggle(pick.id) }
            }
        }
        .accessibilityHint(row.pick == nil ? "Opens your briefing" : "Opens the session")
    }

    private func rowsByDay(now: Date) -> [(String, [Row])] {
        var rows: [Row] = schedule.picks.map { pick in
            let going = planner.teammates(for: pick.id)
            let detail = [pick.event?.place ?? "", going.isEmpty ? "" : "Also going: \(going.joined(separator: ", "))"]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            return Row(id: "pick.\(pick.id)", start: pick.start, title: pick.title, detail: detail, url: pick.url, pick: pick)
        }
        if let me = identity.current?.id {
            rows += team.upcomingStandups(after: now.addingTimeInterval(-12 * 3600)).map {
                Row(id: "standup.\($0.slot)", start: $0.at, title: "Team stand-up", detail: "Your briefing",
                    url: $0.briefingURL(for: me), pick: nil)
            }
        }
        let grouped = Dictionary(grouping: rows) { row in row.start.map(DayPlanner.lisbonDay) ?? "" }
        return grouped.keys.sorted { a, b in a.isEmpty ? false : b.isEmpty ? true : a < b }.map { day in
            (day, grouped[day]!.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) })
        }
    }

    private func nextRow(now: Date) -> Row? {
        rowsByDay(now: now).flatMap(\.1).first { ($0.start ?? .distantPast) > now }
    }

    private func minutesText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(max(1, minutes)) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private var footer: String {
        var parts = ["Kept on this device in the website’s format (nr.schedule.v1), and synced with promptugal.news when you open it in the app."]
        if let last = bridge.lastScheduleSync {
            parts.append("Last synced with the website at \(Lisbon.timeLabel(last)).")
        }
        return parts.joined(separator: " ")
    }
}
