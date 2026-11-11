import SwiftUI

/// Tab 1: "Plan your day". One day at a time, saved events marked.
struct AllEventsView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(SavedStore.self) private var saved
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var searching = false
    @State private var query = ""
    @State private var kindFilter: String?
    @State private var topicFilter: String?
    @State private var detail: FeedEvent?
    @FocusState private var searchFocused: Bool

    private var now: Date { Date() }

    private var inPerson: [FeedEvent] { feed.visibleEvents.filter { $0.category != .online } }
    private var online: [FeedEvent] { feed.visibleEvents.filter { $0.category == .online } }
    private var pool: [FeedEvent] { app.category == .online ? online : inPerson }
    private var days: [Day] { Planner.days(of: feed.visibleEvents) }
    private var selectedDay: String? { app.day ?? Self.defaultDay(days, now: now) }

    static func defaultDay(_ days: [Day], now: Date) -> String? {
        let today = FeedDate.dayString(now)
        return days.first { $0.key == today }?.key ?? days.first { $0.key > today }?.key ?? days.last?.key
    }

    private var filtered: [FeedEvent] {
        pool.filter { e in
            guard e.date == selectedDay else { return false }
            if let kindFilter, e.kindLabel != kindFilter { return false }
            if let topicFilter, !e.topics.contains(where: { $0.lowercased() == topicFilter }) { return false }
            let q = query.trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                let hay = [e.name, e.hostName, e.area, e.place ?? "", e.topics.joined(separator: " ")].joined(separator: " ")
                if hay.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) == nil { return false }
            }
            return true
        }
    }

    private var dayCount: Int { pool.filter { $0.date == selectedDay }.count }
    private var isToday: Bool { selectedDay == FeedDate.dayString(now) }

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        categoryPills
                        DayStrip(days: days, selected: $app.day.withDefault(selectedDay)) { day in
                            let n = pool.filter { $0.date == day.key }.count
                            return n == 0 ? "none" : n == 1 ? "1 event" : "\(n) events"
                        }
                        filterButtons
                        if searching { searchField }
                        let sections = Planner.sections(filtered, now: now, isToday: isToday)
                        partChips(sections, proxy: proxy)
                        if filtered.count != dayCount {
                            HStack {
                                Text("Showing \(filtered.count) of \(dayCount).").font(.subheadline).foregroundStyle(Palette.ink2)
                                Button("Clear filters") { clearFilters() }.buttonStyle(PillButtonStyle())
                            }
                        }
                        FreshnessLine()
                        if sections.isEmpty {
                            Text(dayCount == 0 ? "No events on this day." : "No events match. Try fewer filters.")
                                .font(.body).foregroundStyle(Palette.ink2).padding(.vertical, 20)
                        }
                        let savedEvents = saved.saved(in: feed.events)
                        ForEach(sections) { section in
                            PartHeader(title: section.part == .onNow ? "On now" : section.part.title,
                                       trailing: "\(section.events.count) \(section.events.count == 1 ? "event" : "events")")
                                .id(section.part)
                            ForEach(section.events) { e in
                                EventRow(event: e,
                                         isSaved: saved.isSaved(e),
                                         clashes: !saved.isSaved(e) && Planner.clashes(e, with: savedEvents),
                                         onToggle: { saved.toggle(e) },
                                         onOpen: { detail = e })
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Wordmark()
                            Text("Independent of Web Summit. Events from lisbontechfringe.com.")
                                .font(.footnote).foregroundStyle(Palette.ink2)
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    // Pin the content to the screen width, so it never drifts sideways while scrolling.
                    .containerRelativeFrame(.horizontal)
                }
                .refreshable { await feed.refresh(); saved.compare(with: feed.events) }
            }
            .background(Palette.bg)
            .navigationTitle("Plan your day")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .sheet(item: $detail) { EventDetailView(event: $0).environment(feed).environment(saved) }
        }
    }

    private var categoryPills: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            categoryButton(.inPerson, title: "In person · \(inPerson.count)", icon: "mappin.and.ellipse")
            categoryButton(.online, title: "Online · \(online.count)", icon: "display")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Event category")
    }

    private func categoryButton(_ choice: EventCategoryChoice, title: String, icon: String) -> some View {
        Button {
            app.category = choice
            app.day = nil
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(PillButtonStyle(kind: app.category == choice ? .accent : .plain, fullWidth: true))
        .accessibilityAddTraits(app.category == choice ? .isSelected : [])
    }

    private var filterButtons: some View {
        let kinds = Set(pool.map(\.kindLabel)).sorted()
        let topics = Set(pool.flatMap { $0.topics.map { $0.lowercased() } }).sorted()
        return WrapLayout(spacing: 6) {
            Button {
                searching.toggle()
                searchFocused = searching
                if !searching { query = "" }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(PillButtonStyle(kind: searching ? .teal : .plain))

            Menu {
                Button("All types") { kindFilter = nil }
                ForEach(kinds, id: \.self) { k in Button(k) { kindFilter = k } }
            } label: {
                Text(kindFilter.map { "Type: \($0)" } ?? "Type")
                    .pillLook(kindFilter == nil ? .plain : .teal)
            }

            Menu {
                Button("All topics") { topicFilter = nil }
                ForEach(topics, id: \.self) { t in Button(FeedEvent.capitalisedFirst(t)) { topicFilter = t } }
            } label: {
                Text(topicFilter.map { "Topic: \(FeedEvent.capitalisedFirst($0))" } ?? "Topic")
                    .pillLook(topicFilter == nil ? .plain : .teal)
            }
        }
    }

    private var searchField: some View {
        TextField("Event, host or area", text: $query)
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .submitLabel(.search)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Palette.panel, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.line))
            .accessibilityLabel("Search events")
    }

    private func partChips(_ sections: [DaySection], proxy: ScrollViewProxy) -> some View {
        let parts: [DayPart] = (isToday ? [.onNow] : []) + [.morning, .afternoon, .evening]
        return WrapLayout(spacing: 6) {
            ForEach(parts) { part in
                let count = sections.first { $0.part == part }?.events.count ?? 0
                Button {
                    withAnimation { proxy.scrollTo(part, anchor: .top) }
                } label: {
                    Text(part == .onNow ? "On now · \(count)" : part.title)
                }
                .buttonStyle(PillButtonStyle(kind: part == .onNow && count > 0 ? .teal : .plain))
                .disabled(count == 0)
                .accessibilityLabel("\(part.title), \(count) \(count == 1 ? "event" : "events")")
                .accessibilityHint("Jumps to this part of the day")
            }
        }
    }

    private func clearFilters() {
        query = ""; searching = false; kindFilter = nil; topicFilter = nil
    }
}

extension Binding where Value == String? {
    /// Reads the default when the stored value is nil, so the strip always shows a choice.
    func withDefault(_ fallback: String?) -> Binding<String?> {
        Binding(get: { wrappedValue ?? fallback }, set: { wrappedValue = $0 })
    }
}
