import SwiftUI
import PTCore
import PTWeb

/// The summit agenda, native and offline: what is on now, then every session by day, with a
/// pick button that writes to the one schedule (the team session's ScheduleStore, shared with
/// the website's "Add to my day").
///
/// Built for 200+ sessions on older iPhones and for VoiceOver: the grouping, filtering, labels and
/// times are worked out once per change into `AgendaModel`, not in `body`; rows are small views
/// with stable ids; each row is one accessibility element with a short label and two actions.
public struct AgendaView: View {
    /// `openSession`: the app's native session detail (works offline). Without it a row opens the session's web page.
    public init(openSession: ((Event) -> Void)? = nil) {
        self.openSession = openSession
        _day = State(initialValue: Self.initialDay(now: AgendaClock.now))
    }

    private let openSession: ((Event) -> Void)?

    /// During the summit the agenda opens on today (Lisbon time); otherwise on all days.
    static func initialDay(now: Date) -> String {
        let today = Lisbon.day(now)
        return ProgramModel.summitDays.contains(today) ? today : "all"
    }

    @Environment(ReaderStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @Environment(PickFeedback.self) private var feedback: PickFeedback?
    @State private var day: String
    @State private var query = ""
    @State private var picksOnly = false
    @State private var now = AgendaClock.now
    @State private var model = AgendaModel.empty
    @State private var opened: Event?

    /// Everything that changes what the list shows. When it changes, the model is rebuilt once.
    private var inputs: AgendaModel.Inputs {
        .init(count: store.agenda.count, updated: store.agendaUpdated, day: day, query: query,
              picksOnly: picksOnly, picks: picksOnly ? schedule.picks.count : 0,
              minute: Int(now.timeIntervalSince1970 / 60))
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(String(localized: "Lisbon · 9–12 Nov", bundle: .module))
                    Text(String(localized: "Lisbon time · \(model.clock)", bundle: .module)).font(Typo.data).foregroundStyle(Palette.muted)
                    FreshnessLabel(updated: store.agendaUpdated, staleAfter: 3600)
                }
                Picker(String(localized: "Day", bundle: .module), selection: $day) {
                    Text(String(localized: "All days", bundle: .module)).tag("all")
                    ForEach(model.days) { Text($0.label).tag($0.id) }
                }
                Toggle(String(localized: "My picks only", bundle: .module), isOn: $picksOnly)
            }
            if !model.running.isEmpty {
                Section(String(localized: "Happening now", bundle: .module)) {
                    ForEach(model.running) { row in rowView(row) }
                }
            }
            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in rowView(row) }
                }
            }
            if store.agenda.isEmpty {
                StateView(phase: store.agendaUnavailable ? .failed(String(localized: "The agenda could not be reached.", bundle: .module)) : .loading,
                          hasData: false, title: String(localized: "the agenda", bundle: .module)) { Task { await store.refresh() } }
            } else if model.isEmpty {
                ContentUnavailableView(String(localized: "No matching sessions", bundle: .module), systemImage: "magnifyingglass",
                                       description: Text(String(localized: "Try another day, filter or search.", bundle: .module)))
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: String(localized: "Sessions or venues", bundle: .module))
        .navigationTitle(String(localized: "Agenda", bundle: .module))
        .navigationDestination(item: $opened) { event in
            if let url = event.url { WebPage(url: url, title: String(localized: "Session", bundle: .module)) }
        }
        .onChange(of: inputs, initial: true) { _, _ in
            model = AgendaModel(events: store.agenda, day: day, query: query, picksOnly: picksOnly,
                                isPicked: schedule.isPicked, now: now)
        }
        .task {
            await store.refresh()
            // One tick a minute moves String(localized: "Happening now", bundle: .module) along, without redrawing per second.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = AgendaClock.now
            }
        }
        .refreshable { await store.refresh() }
        .webTwin(FeedClient.fullAgenda, title: String(localized: "Agenda", bundle: .module))
    }

    private func rowView(_ row: AgendaModel.Row) -> some View {
        AgendaRow(row: row, picked: schedule.isPicked(row.event),
                  open: { if let openSession { openSession(row.event) } else { opened = row.event } }, toggle: { togglePick(row.event) })
    }

    /// Picks or un-picks with the star's feedback (a toast, a clash warning) when the app shows toasts.
    private func togglePick(_ event: Event) {
        if let feedback { feedback.toggle(event, in: schedule) } else { schedule.toggle(event) }
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
        .accessibilityValue(picked ? String(localized: "In my program", bundle: .module) : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .accessibilityAction(named: picked ? String(localized: "Remove from my program", bundle: .module) : String(localized: "Add to my program", bundle: .module), toggle)
    }
}

/// The agenda as the list shows it, worked out once per change.
public struct AgendaModel {
    public struct Inputs: Equatable {
        public init(count: Int, updated: Date?, day: String, query: String, picksOnly: Bool, picks: Int, minute: Int) {
            self.count = count
            self.updated = updated
            self.day = day
            self.query = query
            self.picksOnly = picksOnly
            self.picks = picks
            self.minute = minute
        }

        public let count: Int
        public let updated: Date?
        public let day: String
        public let query: String
        public let picksOnly: Bool
        public let picks: Int
        public let minute: Int
    }

    public struct Row: Identifiable {
        public init(event: Event, detail: String, accessibilityLabel: String) {
            self.event = event
            self.detail = detail
            self.accessibilityLabel = accessibilityLabel
        }

        public let event: Event
        public let detail: String
        public let accessibilityLabel: String
        public var id: String { event.id }
    }

    public struct Day: Identifiable {
        public init(id: String, label: String) {
            self.id = id
            self.label = label
        }

        public let id: String
        public let label: String
    }

    public struct DaySection: Identifiable {
        public init(id: String, title: String, rows: [Row]) {
            self.id = id
            self.title = title
            self.rows = rows
        }

        public let id: String
        public let title: String
        public let rows: [Row]
    }

    public var clock: String
    public var days: [Day]
    public var running: [Row]
    public var sections: [DaySection]
    public var isEmpty: Bool { running.isEmpty && sections.isEmpty }

    public static let empty = AgendaModel(clock: "", days: [], running: [], sections: [])

    public init(clock: String, days: [Day], running: [Row], sections: [DaySection]) {
        self.clock = clock
        self.days = days
        self.running = running
        self.sections = sections
    }

    public init(events: [Event], day: String, query: String, picksOnly: Bool, isPicked: @escaping (Event) -> Bool, now: Date) {
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
