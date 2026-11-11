import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// The events with filters for day, type and topic.
struct EventsView: View {
    @Environment(FringeStore.self) private var store
    // In Lisbon starts on: the list also holds events elsewhere in Portugal and online.
    @State private var filter = FringeFilter(lisbonOnly: true)

    var body: some View {
        NavigationStack {
            let shown = filter.apply(store.events)
            List {
                Section { filters }
                if shown.isEmpty {
                    Section { Text("No events match these filters.").foregroundStyle(Palette.muted) }
                }
                ForEach(groups(shown)) { group in
                    Section(FringeFilter.dayLabel(group.day)) {
                        ForEach(group.events) { event in
                            NavigationLink(value: event) { EventRow(event: event) }
                        }
                    }
                }
                Section { FreshnessNote() }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .refreshable { await store.refresh(force: true) }
            .navigationTitle("Events")
            .navigationDestination(for: FringeEvent.self) { EventDetail(event: $0) }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Picker("When", selection: $filter.day) {
                Text("All").tag(String?.none)
                ForEach(FringeFilter.quickDays(now: AgendaClock.now)) { Text($0.label).tag(String?.some($0.id)) }
            }
            .pickerStyle(.segmented)
            Picker("Type", selection: $filter.kind) {
                Text("All types").tag(String?.none)
                ForEach(FringeFilter.kinds(in: store.events), id: \.self) { Text(FringeFilter.kindLabel($0)).tag(String?.some($0)) }
            }
            .pickerStyle(.menu)
            Picker("Topic", selection: $filter.topic) {
                Text("All topics").tag(String?.none)
                ForEach(FringeFilter.topics(in: store.events), id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .pickerStyle(.menu)
            Toggle("In Lisbon", isOn: $filter.lisbonOnly)
            Toggle("Moved by the storm", isOn: $filter.stormMoved)
            if filter.isActive {
                Button("Clear filters") { filter = FringeFilter(lisbonOnly: true) }
            }
        }
    }

    private struct DayGroup: Identifiable {
        let day: String
        let events: [FringeEvent]
        var id: String { day }
    }

    private func groups(_ events: [FringeEvent]) -> [DayGroup] {
        Dictionary(grouping: events, by: \.date).map { DayGroup(day: $0.key, events: $0.value) }.sorted { $0.day < $1.day }
    }
}
