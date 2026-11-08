import SwiftUI
import PTCore
import PTWeb

/// Entry view for the schedule: my picks (website and app, one list) and, for the team, my stand-ups, by Lisbon day.
public struct MyDayView: View {
    public init() {}

    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.agendaTeam) private var team
    @Environment(\.agendaIdentity) private var identity
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(PlannerStore.self) private var planner
    @Environment(AppBridge.self) private var bridge
    @Environment(ScheduleVaultLink.self) private var vaultLink
    @Environment(\.openURL) private var openURL
    @State private var calendarMessage: String?
    @State private var timelineDay = Lisbon.day(AgendaClock.now)
    @Environment(\.horizontalSizeClass) private var width

    private struct Row: Identifiable {
        let id: String
        let start: Date?
        let title: String
        let detail: String
        let url: URL?
        let pick: SchedulePick?
    }

    public var body: some View {
        HStack(spacing: 0) {
            dayList
                .frame(maxWidth: width == .regular ? 440 : .infinity)
            if width == .regular {
                Divider()
                timeline
            }
        }
        .navigationTitle(String(localized: "My day", bundle: .module))
        .refreshable { await team?.refresh(person: identity?.currentID) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        let upcoming = schedule.picks.filter { ($0.start ?? .distantPast) > AgendaClock.now }
                        switch await CalendarExport.add(upcoming) {
                        case .added(let count): calendarMessage = String(localized: "\(count) sessions added to your calendar.", bundle: .module)
                        case .denied: calendarMessage = String(localized: "Calendar access was not given. You can allow it in Settings.", bundle: .module)
                        case .failed(let message): calendarMessage = message
                        }
                    }
                } label: {
                    Label(String(localized: "Add to Calendar", bundle: .module), systemImage: "calendar.badge.plus")
                }
                .disabled(schedule.picks.isEmpty)
            }
        }
        .alert(String(localized: "Calendar", bundle: .module), isPresented: Binding(get: { calendarMessage != nil },
                                                set: { if !$0 { calendarMessage = nil } })) {
            Button(String(localized: "OK", bundle: .module)) { calendarMessage = nil }
        } message: {
            Text(calendarMessage ?? "")
        }
    }

    /// iPad: the chosen day as a time line, picks and stand-ups as blocks.
    private var timeline: some View {
        let now = AgendaClock.now
        let days = Array(Set(rowsByDay(now: now).map(\.0).filter { !$0.isEmpty } + [Lisbon.day(now)])).sorted()
        let day = days.contains(timelineDay) ? timelineDay : (days.first ?? timelineDay)
        let items: [DayPlanner.Item] = rowsByDay(now: now).first { $0.0 == day }?.1.compactMap { row in
            guard let start = row.start else { return nil }
            let end = row.pick?.end ?? start.addingTimeInterval(30 * 60)
            return DayPlanner.Item(id: row.id, kind: row.pick == nil ? .standup : .pick, title: row.title,
                                   start: start, end: end, place: row.pick?.event?.place ?? "", eventID: row.pick?.id)
        } ?? []
        return VStack(spacing: 0) {
            Picker("Day", selection: $timelineDay) {
                ForEach(days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            DayTimelineView(day: day, items: items) { item in
                if let row = rowsByDay(now: AgendaClock.now).flatMap(\.1).first(where: { $0.id == item.id }), let url = row.url {
                    openURL(url)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var dayList: some View {
        TimelineView(.everyMinute) { context in
            List {
                header(now: context.date)
                let days = rowsByDay(now: context.date)
                if days.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Nothing in your day yet", bundle: .module), systemImage: "star")
                    } description: {
                        Text(String(localized: "Add sessions from the agenda here or with “Add to my day” on promptugal.news. Both make one list.", bundle: .module))
                    } actions: {
                        NavigationLink(String(localized: "Help me plan my day", bundle: .module)) { PlannerView() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                ForEach(days, id: \.0) { day, rows in
                    Section(day == "" ? String(localized: "No time yet", bundle: .module) : Lisbon.dayLabel(day)) {
                        ForEach(rows) { row in rowView(row, now: context.date) }
                    }
                }
                if vaultLink.hasVault {
                    Section {
                        Button {
                            Task { await vaultLink.save() }
                        } label: {
                            Label(String(localized: "Save my day to the vault", bundle: .module), systemImage: "lock.doc")
                        }
                        .disabled(vaultLink.state == .working || !vaultLink.canSave)
                        switch vaultLink.state {
                        case .done(let message): Text(message).font(.footnote).foregroundStyle(.secondary)
                        case .failed(let message): Text(message).font(.footnote).foregroundStyle(.orange)
                        case .working: ProgressView()
                        default: EmptyView()
                        }
                    } header: {
                        Text(String(localized: "Your vault", bundle: .module))
                    } footer: {
                        Text(vaultLink.canSave
                             ? String(localized: "Picks are read from your vault when it opens. Saving asks for Face ID and puts them where the website reads them.", bundle: .module)
                             : String(localized: "Picks are read from your vault. To save, open it with its vault key and set an access token.", bundle: .module))
                    }
                }
                Section {
                    NavigationLink { PlannerView() } label: {
                        Label(String(localized: "Help me plan my presence", bundle: .module), systemImage: "wand.and.stars")
                    }
                    NavigationLink { ReminderSettingsView() } label: {
                        Label(String(localized: "Reminders", bundle: .module), systemImage: "bell")
                            .badge(reminders.planned.count)
                    }
                } footer: {
                    Text(footer)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder private func header(now: Date) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Lisbon time · \(Lisbon.timeLabel(now))", bundle: .module))
                    .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                if let next = nextRow(now: now) {
                    Text(String(localized: "Next: \(next.title)", bundle: .module)).font(.headline)
                    if let start = next.start {
                        Text(String(localized: "\(Lisbon.timeLabel(start)) · in \(minutesText(start.timeIntervalSince(now)))", bundle: .module))
                            .font(.subheadline).foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text(String(localized: "\(schedule.picks.count) picks", bundle: .module)).font(.headline)
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
                Text(row.start.map(Lisbon.timeLabel) ?? String(localized: "Time not known", bundle: .module))
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
                Button(String(localized: "Remove", bundle: .module), role: .destructive) { schedule.toggle(pick.id) }
            }
        }
        .accessibilityHint(row.pick == nil ? String(localized: "Opens your briefing", bundle: .module) : String(localized: "Opens the session", bundle: .module))
    }

    private func rowsByDay(now: Date) -> [(String, [Row])] {
        var rows: [Row] = schedule.picks.map { pick in
            let going = planner.teammates(for: pick.id)
            let detail = [pick.event?.place ?? "", going.isEmpty ? "" : "Also going: \(going.joined(separator: ", "))"]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            return Row(id: "pick.\(pick.id)", start: pick.start, title: pick.title, detail: detail, url: pick.url, pick: pick)
        }
        if let me = identity?.currentID {
            rows += (team?.upcomingStandups(after: now.addingTimeInterval(-12 * 3600)) ?? []).map {
                Row(id: "standup.\($0.slot)", start: $0.at, title: String(localized: "Team stand-up", bundle: .module), detail: String(localized: "Your briefing", bundle: .module),
                    url: $0.briefingURL(for: me), pick: nil)
            }
        }
        let grouped = Dictionary(grouping: rows) { row in row.start.map(Lisbon.day) ?? "" }
        return grouped.keys.sorted { a, b in a.isEmpty ? false : b.isEmpty ? true : a < b }.map { day in
            (day, grouped[day]!.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) })
        }
    }

    private func nextRow(now: Date) -> Row? {
        rowsByDay(now: now).flatMap(\.1).first { ($0.start ?? .distantPast) > now }
    }

    private func minutesText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? String(localized: "\(max(1, minutes)) min", bundle: .module) : String(localized: "\(minutes / 60) h \(minutes % 60) min", bundle: .module)
    }

    private var footer: String {
        var parts = [String(localized: "Kept on this device in the website’s format (nr.schedule.v1), and synced with promptugal.news when you open it in the app.", bundle: .module)]
        if let last = bridge.lastScheduleSync {
            parts.append(String(localized: "Last synced with the website at \(Lisbon.timeLabel(last)).", bundle: .module))
        }
        return parts.joined(separator: " ")
    }
}
