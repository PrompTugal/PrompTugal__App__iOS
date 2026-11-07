import SwiftUI

/// The summit agenda, native and offline: what is on now, then every session by day, with a
/// pick button that writes to the one schedule (the team session's ScheduleStore, shared with
/// the website's "Add to my day").
///
/// Built for 200+ sessions on older iPhones and for VoiceOver: the grouping, filtering, labels and
/// times are worked out once per change into `AgendaModel`, not in `body`; rows are small views
/// with stable ids; each row is one accessibility element with a short label and two actions.
struct AgendaView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @State private var day = "all"
    @State private var query = ""
    @State private var picksOnly = false
    @State private var now = Date.now
    @State private var model = AgendaModel.empty
    @State private var opened: Event?

    /// Everything that changes what the list shows. When it changes, the model is rebuilt once.
    private var inputs: AgendaModel.Inputs {
        .init(count: store.agenda.count, updated: store.agendaUpdated, day: day, query: query,
              picksOnly: picksOnly, picks: picksOnly ? schedule.picks.count : 0,
              minute: Int(now.timeIntervalSince1970 / 60))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker("Web Summit Lisbon · 9–12 Nov")
                    Text("Lisbon time \(model.clock)").font(Typo.data).foregroundStyle(Palette.muted)
                    FreshnessLabel(updated: store.agendaUpdated, staleAfter: 3600)
                }
                Picker("Day", selection: $day) {
                    Text("All days").tag("all")
                    ForEach(model.days) { Text($0.label).tag($0.id) }
                }
                Toggle("My picks only", isOn: $picksOnly)
            }
            if !model.running.isEmpty {
                Section("Happening now") {
                    ForEach(model.running) { row in rowView(row) }
                }
            }
            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in rowView(row) }
                }
            }
            if store.agenda.isEmpty {
                StateView(phase: store.agendaUnavailable ? .failed("The agenda could not be reached.") : .loading,
                          hasData: false, title: "agenda") { Task { await store.refresh() } }
            } else if model.isEmpty {
                ContentUnavailableView("No matching sessions", systemImage: "magnifyingglass",
                                       description: Text("Try another day, filter or search."))
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Sessions or venues")
        .navigationTitle("Agenda")
        .navigationDestination(item: $opened) { event in
            if let url = event.url { WebPage(url: url, title: "Session") }
        }
        .onChange(of: inputs, initial: true) { _, _ in
            model = AgendaModel(events: store.agenda, day: day, query: query, picksOnly: picksOnly,
                                isPicked: schedule.isPicked, now: now)
        }
        .task {
            await store.refresh()
            // One tick a minute moves "Happening now" along, without redrawing per second.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = .now
            }
        }
        .refreshable { await store.refresh() }
        .webTwin(FeedClient.fullAgenda, title: "Agenda")
    }

    private func rowView(_ row: AgendaModel.Row) -> some View {
        AgendaRow(row: row, picked: schedule.isPicked(row.event),
                  open: { opened = row.event }, toggle: { schedule.toggle(row.event) })
    }
}

/// One session. Small, with no formatting work: every string is ready in `row`.
private struct AgendaRow: View {
    let row: AgendaModel.Row
    let picked: Bool
    let open: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.event.time).font(.caption.monospacedDigit()).foregroundStyle(Palette.red)
                Text(row.event.title).font(.headline).foregroundStyle(Palette.ink)
                Text(row.detail).font(.caption).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
            Button(action: toggle) {
                Image(systemName: picked ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(picked ? Palette.red : Palette.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
        }
        // One element for VoiceOver and UI tests: a short label, open by default, pick as an action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(picked ? "In my schedule" : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .accessibilityAction(named: picked ? "Remove from my schedule" : "Add to my schedule", toggle)
    }
}

/// The agenda as the list shows it, worked out once per change.
struct AgendaModel {
    struct Inputs: Equatable {
        let count: Int
        let updated: Date?
        let day: String
        let query: String
        let picksOnly: Bool
        let picks: Int
        let minute: Int
    }

    struct Row: Identifiable {
        let event: Event
        let detail: String
        let accessibilityLabel: String
        var id: String { event.id }
    }

    struct Day: Identifiable {
        let id: String
        let label: String
    }

    struct DaySection: Identifiable {
        let id: String
        let title: String
        let rows: [Row]
    }

    var clock: String
    var days: [Day]
    var running: [Row]
    var sections: [DaySection]
    var isEmpty: Bool { running.isEmpty && sections.isEmpty }

    static let empty = AgendaModel(clock: "", days: [], running: [], sections: [])

    init(clock: String, days: [Day], running: [Row], sections: [DaySection]) {
        self.clock = clock
        self.days = days
        self.running = running
        self.sections = sections
    }

    init(events: [Event], day: String, query: String, picksOnly: Bool, isPicked: (Event) -> Bool, now: Date) {
        clock = Lisbon.timeLabel(now)
        let dates = Array(Set(events.map(\.date))).sorted()
        var labels: [String: String] = [:]
        for date in dates { labels[date] = Lisbon.dayLabel(date) }
        days = dates.map { Day(id: $0, label: labels[$0] ?? $0) }

        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = events.filter { event in
            (day == "all" || event.date == day)
                && (!picksOnly || isPicked(event))
                && (search.isEmpty || event.title.localizedStandardContains(search)
                    || event.place.localizedStandardContains(search))
        }

        func row(_ event: Event) -> Row {
            let kind = event.official ? "Official programme" : "Side event"
            let detail = event.place.isEmpty ? kind : "\(event.place) · \(kind)"
            return Row(event: event, detail: detail,
                       accessibilityLabel: "\(labels[event.date] ?? event.date), \(event.time). \(event.title). \(event.place)")
        }

        var running: [Row] = []
        var byDay: [String: [Row]] = [:]
        for event in shown {
            if let start = event.start, let end = event.end, start <= now, now < end {
                running.append(row(event))
            } else {
                byDay[event.date, default: []].append(row(event))
            }
        }
        self.running = running
        sections = dates.compactMap { date in
            guard let rows = byDay[date], !rows.isEmpty else { return nil }
            return DaySection(id: date, title: "\(labels[date] ?? date) · \(rows.count)", rows: rows)
        }
    }
}
