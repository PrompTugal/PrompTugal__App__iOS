import SwiftUI

@main @MainActor
struct PrompTugalApp: App {
    @State private var store = ReaderStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Background tasks must be registered before the app finishes launching.
        VaultBackground.register()
    }

    var body: some Scene {
        WindowGroup {
            WebsiteView()
                .environment(store)
                .tint(Color("AccentColor"))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { VaultBackground.schedule() }
        }
    }
}

private enum ReaderSection: String, CaseIterable, Identifiable {
    case now = "Now"
    case agenda = "Agenda"
    case saved = "Saved"
    case news = "News"

    var id: Self { self }
    var icon: String {
        switch self {
        case .now: "clock"
        case .agenda: "calendar"
        case .saved: "bookmark"
        case .news: "newspaper"
        }
    }
}

private enum ReaderDestination: Hashable {
    case event(String)
    case story(Story)
}

struct ReaderView: View {
    @Environment(ReaderStore.self) private var store
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: ReaderSection = .now
    @State private var selection: ReaderDestination?
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if width == .regular {
                splitView
            } else {
                TabView(selection: $section) {
                    ForEach(ReaderSection.allCases) { tab in
                        NavigationStack {
                            ReaderSectionView(section: tab)
                                .navigationDestination(for: ReaderDestination.self, destination: detail)
                        }
                        .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                        .tag(tab)
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .onChange(of: section) { _, _ in selection = nil }
        .alert("PrompTugal", isPresented: Binding(
            get: { store.storageMessage != nil },
            set: { if !$0 { store.storageMessage = nil } }
        )) {
            Button("OK") { store.storageMessage = nil }
        } message: {
            Text(store.storageMessage ?? "")
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: Binding<ReaderSection?>(
                get: { section },
                set: { if let newSection = $0 { section = newSection } }
            )) {
                ForEach(ReaderSection.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
                Section {
                    Link("About this coverage", destination: FeedClient.disclosure)
                } footer: {
                    Text("Independent coverage from Lisbon")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("PrompTugal")
        } content: {
            ReaderSectionView(section: section, selection: $selection)
                .id(section)
                .navigationSplitViewColumnWidth(min: 260, ideal: 330, max: 420)
        } detail: {
            if let selection {
                detail(selection)
            } else {
                ContentUnavailableView("Select an item", systemImage: section.icon,
                                       description: Text("Choose a session or story to see more."))
            }
        }
    }

    @ViewBuilder private func detail(_ destination: ReaderDestination) -> some View {
        switch destination {
        case .event(let id):
            if let event = store.event(id: id) {
                ReaderEventDetailView(event: event)
            } else {
                ContentUnavailableView("Session unavailable", systemImage: "calendar.badge.exclamationmark",
                                       description: Text("This session is missing from the current agenda."))
            }
        case .story(let story):
            ReaderStoryDetailView(story: story)
        }
    }
}

private struct ReaderSectionView: View {
    @Environment(ReaderStore.self) private var store
    let section: ReaderSection
    let selection: Binding<ReaderDestination?>?
    @State private var query = ""
    @State private var day = "all"
    @State private var sideOnly = false

    init(section: ReaderSection, selection: Binding<ReaderDestination?>? = nil) {
        self.section = section
        self.selection = selection
    }

    var body: some View {
        Group {
            if section == .agenda {
                content.searchable(text: $query, prompt: "Search sessions or venues")
            } else {
                content
            }
        }
        .navigationTitle(section.rawValue)
        .refreshable { await store.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.refreshing)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .now:
            TimelineView(.everyMinute) { context in
                List(selection: selection) { nowRows(at: context.date) }
                    .listStyle(.insetGrouped)
            }
        case .agenda:
            List(selection: selection) { agendaRows }
                .listStyle(.insetGrouped)
        case .saved:
            List(selection: selection) { savedRows }
                .listStyle(.insetGrouped)
        case .news:
            List(selection: selection) { newsRows }
                .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder private func nowRows(at time: Date) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 7) {
                Text("PROMPTUGAL.NEWS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(Color.accentColor)
                Text("Web Summit Lisbon")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Independent coverage · 9–12 November 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Lisbon time · \(Lisbon.timeLabel(time))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
        feedStatus(updated: store.agendaUpdated, failed: store.agendaUnavailable, title: "Agenda")
        let running = store.agenda.filter { event in
            guard let start = event.start, let end = event.end else { return false }
            return start <= time && time < end
        }
        let upcoming = store.agenda.filter { ($0.start ?? .distantPast) > time }
        if !running.isEmpty {
            Section("Happening now") { ForEach(running) { eventRow($0) } }
        }
        if !upcoming.isEmpty {
            Section("Up next") { ForEach(upcoming.prefix(6)) { eventRow($0) } }
        } else if running.isEmpty, store.agendaUpdated != nil {
            Section {
                Text(store.agenda.isEmpty
                    ? "There are no sessions in the current feed."
                    : "There are no upcoming sessions in this feed. Past sessions are in Agenda.")
                    .foregroundStyle(.secondary)
            }
        }
        if !store.news.isEmpty {
            Section("Latest news") { ForEach(store.news.prefix(3)) { storyRow($0) } }
        }
        Section {
            Link("Full agenda on the web", destination: FeedClient.fullAgenda)
            Link("About this coverage", destination: FeedClient.disclosure)
        }
    }

    @ViewBuilder private var agendaRows: some View {
        feedStatus(updated: store.agendaUpdated, failed: store.agendaUnavailable, title: "Agenda")
        if !store.agenda.isEmpty {
            let days = Set(store.agenda.map(\.date)).sorted()
            let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let filtered = store.agenda.filter { event in
                return (day == "all" || !days.contains(day) || event.date == day)
                    && (!sideOnly || !event.official)
                    && (search.isEmpty || event.title.localizedStandardContains(search)
                        || event.place.localizedStandardContains(search))
            }
            Section {
                Picker("Day", selection: $day) {
                    Text("All days").tag("all")
                    ForEach(days, id: \.self) { Text(Lisbon.dayLabel($0)).tag($0) }
                }
                Toggle("Side events only", isOn: $sideOnly)
            } footer: {
                Text("Times are in Lisbon. The full website agenda includes more side events.")
            }
            ForEach(days, id: \.self) { date in
                let rows = filtered.filter { $0.date == date }
                if !rows.isEmpty {
                    Section(Lisbon.dayLabel(date)) { ForEach(rows) { eventRow($0) } }
                }
            }
            if filtered.isEmpty {
                ContentUnavailableView("No matching sessions", systemImage: "magnifyingglass",
                                       description: Text("Try another day, filter, or search."))
            }
        } else if store.agendaUpdated != nil {
            Text("There are no sessions in the current feed.").foregroundStyle(.secondary)
        }
        Section { Link("Full agenda on the web", destination: FeedClient.fullAgenda) }
    }

    @ViewBuilder private var savedRows: some View {
        if store.saved.isEmpty {
            ContentUnavailableView("No saved sessions", systemImage: "bookmark",
                                   description: Text("Open a session and tap Save to keep it here."))
        } else {
            Section {
                ForEach(store.saved) { eventRow($0) }
            } footer: {
                Text("Saved sessions are available offline on this device.")
            }
        }
    }

    @ViewBuilder private var newsRows: some View {
        feedStatus(updated: store.newsUpdated, failed: store.newsUnavailable, title: "News")
        if !store.news.isEmpty {
            Section("Latest stories") { ForEach(store.news) { storyRow($0) } }
        } else if store.newsUpdated != nil {
            Text("There are no stories in the current feed.").foregroundStyle(.secondary)
        }
        Section { Link("All articles on the web", destination: FeedClient.articleIndex) }
    }

    @ViewBuilder private func feedStatus(updated: Date?, failed: Bool, title: String) -> some View {
        if let updated {
            Label(
                "\(failed ? "Refresh failed · last synced" : "Last synced") \(Lisbon.dayLabel(lisbonDay(updated))) · \(Lisbon.timeLabel(updated)) Lisbon",
                systemImage: failed ? "wifi.slash" : "clock"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else if failed {
            ContentUnavailableView("\(title) unavailable", systemImage: "wifi.slash",
                                   description: Text("Connect to the internet and tap Refresh."))
        } else {
            ProgressView("Loading \(title.lowercased())…")
        }
    }

    private func lisbonDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Lisbon.calendar
        formatter.timeZone = Lisbon.zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func eventRow(_ event: Event) -> some View {
        route(.event(event.id)) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(Lisbon.dayLabel(event.date)) · \(event.time)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                Text(event.title).font(.headline)
                Text([event.place, event.official ? "Official programme" : "Side event"]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func storyRow(_ story: Story) -> some View {
        route(.story(story)) {
            VStack(alignment: .leading, spacing: 5) {
                if !story.category.isEmpty {
                    Text(story.category).font(.caption).foregroundStyle(Color.accentColor)
                }
                Text(story.title).font(.headline)
                if !story.summary.isEmpty {
                    Text(story.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private func route<Label: View>(_ destination: ReaderDestination, @ViewBuilder label: () -> Label) -> some View {
        if selection != nil {
            label().tag(destination)
        } else {
            NavigationLink(value: destination, label: label)
        }
    }
}

private struct ReaderEventDetailView: View {
    @Environment(ReaderStore.self) private var store
    let event: Event

    var body: some View {
        let detail = store.detail(for: event)
        let venue = detail?.whereText ?? event.place
        let saved = store.isSaved(event)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(event.official ? "Official programme" : "Side event")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(event.title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Label("\(Lisbon.dayLabel(event.date)) · \(event.time) Lisbon", systemImage: "clock")
                if !venue.isEmpty { Label(venue, systemImage: "mappin.and.ellipse") }
                Button {
                    store.toggleSaved(event)
                } label: {
                    Label(saved ? "Remove from Saved" : "Save session", systemImage: saved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.borderedProminent)
                Divider()
                if let source = detail?.sourceURL ?? detail?.sessionURL {
                    Link(destination: source) { Label("Open original source", systemImage: "arrow.up.right.square") }
                }
                if let checkedOn = detail?.checkedOn {
                    Text("Source checked \(checkedOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let page = event.url {
                    Link("Open on PrompTugal.news", destination: page)
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: event.id) { await store.refreshDetail(for: event) }
    }
}

private struct ReaderStoryDetailView: View {
    let story: Story

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !story.category.isEmpty {
                    Text(story.category).font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
                Text(story.title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let published = story.published {
                    Text(published.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !story.summary.isEmpty { Text(story.summary).font(.body) }
                Link(destination: story.url) { Label("Read on PrompTugal.news", systemImage: "arrow.up.right.square") }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
    }
}
