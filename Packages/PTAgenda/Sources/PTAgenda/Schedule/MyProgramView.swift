import SwiftUI
import PTCore

/// My program (spec PROG-1): the person's picks for one day in time order, clashes marked, free time shown, with
/// reminders and "Add to Calendar". The model does the work; this draws it.
public struct MyProgramView: View {
    public init(chooseTalks: @escaping () -> Void = {}, open: @escaping (URL) -> Void = { _ in }) {
        self.chooseTalks = chooseTalks
        self.open = open
    }

    private let chooseTalks: () -> Void
    private let open: (URL) -> Void

    @Environment(ScheduleStore.self) private var schedule
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(PickFeedback.self) private var feedback: PickFeedback?
    @State private var day: String?
    @State private var calendarMessage: String?

    public var body: some View {
        TimelineView(.everyMinute) { _ in
            let selected = day ?? ProgramModel.defaultDay(picks: schedule.picks, now: AgendaClock.now)
            let model = ProgramModel(picks: schedule.picks, day: selected)
            content(model)
        }
        .navigationTitle("My program")
        .alert("Calendar", isPresented: Binding(get: { calendarMessage != nil }, set: { if !$0 { calendarMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(calendarMessage ?? "") }
    }

    @ViewBuilder
    private func content(_ model: ProgramModel) -> some View {
        if model.isEmpty {
            ContentUnavailableView {
                Label("Your program is empty", systemImage: "star")
            } description: {
                Text("Star talks in Explore or on Now. They appear here in time order, with clashes marked.")
            } actions: {
                Button("Choose talks", action: chooseTalks).buttonStyle(.borderedProminent)
            }
        } else {
            List {
                Section {
                    Picker("Day", selection: Binding(get: { model.day }, set: { day = $0 })) {
                        ForEach(model.days) { Text($0.label).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                    reminderRow
                }
                if model.rows.isEmpty {
                    Section { Text("Nothing picked for this day.").foregroundStyle(Palette.muted) }
                }
                ForEach(model.rows) { row in rowView(row) }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add to Calendar") { addToCalendar(model) }
                        .disabled(model.dayEntries.isEmpty)
                }
            }
        }
    }

    private var reminderRow: some View {
        @Bindable var reminders = reminders
        return VStack(alignment: .leading, spacing: Space.s) {
            Toggle("Remind me before each talk", isOn: $reminders.picksOn)
            if reminders.picksOn {
                Picker("Lead time", selection: $reminders.leadMinutes) {
                    ForEach(ReminderScheduler.leadChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "At start" : "\(minutes) min before").tag(minutes)
                    }
                }
                if reminders.authorization == .denied {
                    Text("Notifications are off for this app. Turn them on in Settings to get reminders.")
                        .font(.caption).foregroundStyle(Palette.amber)
                }
            }
        }
        .task(id: reminders.picksOn) {
            _ = await reminders.currentAuthorization()
            if reminders.picksOn { _ = await reminders.requestAuthorization() }
            _ = await reminders.reschedule()
        }
    }

    @ViewBuilder
    private func rowView(_ row: ProgramModel.Row) -> some View {
        switch row {
        case .session(let entry):
            Section { sessionRow(entry) }
        case .clash(let group):
            Section {
                ForEach(group.entries) { entry in
                    sessionRow(entry)
                        .swipeActions(edge: .trailing) {
                            Button("Keep this one") { keep(entry, in: group) }.tint(Palette.red)
                        }
                }
            } header: {
                Label("Clash · choose one", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Palette.amber)
            }
        case .free(let start, let end):
            Text("Free · \(Int(end.timeIntervalSince(start) / 60)) min")
                .font(.caption).foregroundStyle(Palette.muted)
                .listRowBackground(Color.clear)
        }
    }

    private func sessionRow(_ entry: NowModel.Entry) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeRange(entry)).font(.caption.monospacedDigit()).foregroundStyle(Palette.red)
                Text(entry.title).font(.headline).foregroundStyle(Palette.ink)
                if !entry.place.isEmpty { Text(entry.place).font(.caption).foregroundStyle(Palette.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if let url = entry.url { open(url) } }
            Button { unpick(entry) } label: {
                Image(systemName: "star.fill").font(.title3).foregroundStyle(Palette.red).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove from my program")
        }
        .accessibilityElement(children: .combine)
    }

    private func timeRange(_ entry: NowModel.Entry) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Lisbon.zone)
        return "\(entry.start.formatted(style)) – \(entry.end.formatted(style))"
    }

    private func unpick(_ entry: NowModel.Entry) {
        guard let event = schedule.picks.first(where: { $0.id == entry.id })?.event else { return }
        if let feedback { feedback.toggle(event, in: schedule) } else { schedule.toggle(event) }
    }

    /// "Keep this one": the other picks in the clash are removed.
    private func keep(_ entry: NowModel.Entry, in group: ProgramModel.ClashGroup) {
        for id in group.others(than: entry.id) {
            if let event = schedule.picks.first(where: { $0.id == id })?.event { schedule.toggle(event) }
        }
    }

    private func addToCalendar(_ model: ProgramModel) {
        let ids = Set(model.dayEntries.map(\.id))
        let picks = schedule.picks.filter { ids.contains($0.id) }
        Task {
            switch await CalendarExport.add(picks) {
            case .added(let count): calendarMessage = "Added \(count) to your calendar."
            case .denied: calendarMessage = "Calendar access is off for this app. Turn it on in Settings."
            case .failed(let reason): calendarMessage = reason
            }
        }
    }
}
