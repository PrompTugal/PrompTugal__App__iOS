import SwiftUI

/// The summit agenda, native and offline: what is on now, then every session by day, with a
/// pick button that writes to the one schedule (the team session's ScheduleStore, shared with
/// the website's "Add to my day"). Replaces the old reader inside the shell, which had its own
/// split view and tabs and so nested badly.
struct AgendaView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @State private var day = "all"
    @State private var query = ""
    @State private var picksOnly = false

    private var days: [String] { Array(Set(store.agenda.map(\.date))).sorted() }

    private var filtered: [Event] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.agenda.filter { event in
            (day == "all" || event.date == day)
                && (!picksOnly || schedule.isPicked(event))
                && (search.isEmpty || event.title.localizedStandardContains(search)
                    || event.place.localizedStandardContains(search))
        }
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                Section {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Kicker("Web Summit Lisbon · 9–12 Nov")
                        Text("Lisbon time \(Lisbon.timeLabel(context.date))").font(Typo.data).foregroundStyle(Palette.muted)
                        FreshnessLabel(updated: store.agendaUpdated, staleAfter: 3600)
                    }
                    Picker("Day", selection: $day) {
                        Text("All days").tag("all")
                        ForEach(days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
                    }
                    Toggle("My picks only", isOn: $picksOnly)
                }
                let running = filtered.filter { ($0.start ?? .distantFuture) <= context.date && context.date < ($0.end ?? .distantPast) }
                if !running.isEmpty {
                    Section("Happening now") { ForEach(running) { row($0, now: context.date) } }
                }
                ForEach(days.filter { day == "all" || $0 == day }, id: \.self) { date in
                    let rows = filtered.filter { $0.date == date && !running.contains($0) }
                    if !rows.isEmpty {
                        Section("\(Lisbon.dayLabel(date)) · \(rows.count)") { ForEach(rows) { row($0, now: context.date) } }
                    }
                }
                if store.agenda.isEmpty {
                    StateView(phase: store.agendaUnavailable ? .failed("The agenda could not be reached.") : .loading,
                              hasData: false, title: "agenda") { Task { await store.refresh() } }
                } else if filtered.isEmpty {
                    ContentUnavailableView("No matching sessions", systemImage: "magnifyingglass",
                                           description: Text("Try another day, filter or search."))
                }
            }
            .listStyle(.insetGrouped)
        }
        .searchable(text: $query, prompt: "Sessions or venues")
        .navigationTitle("Agenda")
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .webTwin(FeedClient.fullAgenda, title: "Agenda")
    }

    private func row(_ event: Event, now: Date) -> some View {
        let picked = schedule.isPicked(event)
        return HStack(alignment: .top, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.time).font(.caption.monospacedDigit()).foregroundStyle(Palette.red)
                if let url = event.url {
                    NavigationLink { WebPage(url: url, title: "Session") } label: {
                        Text(event.title).font(.headline).foregroundStyle(Palette.ink)
                    }
                } else {
                    Text(event.title).font(.headline)
                }
                Text([event.place, event.official ? "Official programme" : "Side event"].filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: Space.s)
            Button { schedule.toggle(event) } label: {
                Image(systemName: picked ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(picked ? Palette.red : Palette.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(picked ? "Remove from my schedule" : "Add to my schedule")
        }
    }
}
