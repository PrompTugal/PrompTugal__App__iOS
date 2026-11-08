import PTCore
import SwiftUI

/// The Explore screen: search, a kind picker, results, and a detail page for each entry.
/// Open it with `ExploreScreen()`; it brings its own navigation stack.
public struct ExploreScreen: View {
    @State private var store: ExploreStore

    public init(store: ExploreStore? = nil) {
        _store = State(initialValue: store ?? ExploreStore())
    }

    public var body: some View {
        NavigationStack {
            ExploreListView(store: store)
                .navigationTitle("Explore")
                .navigationDestination(for: ExploreItem.self) { ExploreDetailView(item: $0, store: store) }
        }
    }
}

public struct ExploreListView: View {
    @Bindable var store: ExploreStore

    public init(store: ExploreStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $store.kind) {
                ForEach(ExploreKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            content
        }
        .searchable(text: $store.query, prompt: "Search talks, speakers, companies, places")
        .task { if store.index == nil { await store.load() } }
        .refreshable { await store.load() }
    }

    @ViewBuilder private var content: some View {
        if store.index == nil {
            if case .failed(let message) = store.phase {
                ContentUnavailableView {
                    Label("Nothing to show yet", systemImage: "wifi.slash")
                } description: {
                    Text("The summit data loads once online, then works offline. \(message)")
                } actions: {
                    Button("Try again") { Task { await store.load() } }
                }
            } else {
                ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if store.results.isEmpty {
            ContentUnavailableView.search(text: store.query)
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if store.kind == .event {
                ForEach(days, id: \.day) { group in
                    Section(ExploreFormat.day(group.day)) {
                        ForEach(group.items) { row($0) }
                    }
                }
            } else {
                ForEach(store.results) { row($0) }
            }
        }
        .listStyle(.plain)
    }

    private var days: [(day: String, items: [ExploreItem])] {
        var groups: [(day: String, items: [ExploreItem])] = []
        for item in store.results {
            let day = item.day ?? ""
            if let last = groups.last, last.day == day { groups[groups.count - 1].items.append(item) }
            else { groups.append((day, [item])) }
        }
        return groups
    }

    private func row(_ item: ExploreItem) -> some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 2) {
                if let time = ExploreFormat.time(item) {
                    Text(time).font(Typo.dataSmall).foregroundStyle(Palette.red)
                }
                Text(item.title).font(Typo.headline)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(Typo.meta).foregroundStyle(Palette.muted).lineLimit(2)
                }
            }
        }
    }
}

public struct ExploreDetailView: View {
    let item: ExploreItem
    let store: ExploreStore
    @State private var detail: ExploreDetail?
    @State private var failed = false

    public init(item: ExploreItem, store: ExploreStore) {
        self.item = item
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Label(String(localized: item.kind.title), systemImage: item.kind.symbol)
                        .font(Typo.kicker).foregroundStyle(Palette.red)
                    Text(item.title).font(Typo.title)
                    if let time = ExploreFormat.time(item) { Text(time).font(Typo.data).foregroundStyle(Palette.muted) }
                    if !item.subtitle.isEmpty { Text(item.subtitle).font(Typo.body).foregroundStyle(Palette.muted) }
                }
            }
            if let detail {
                if !detail.facts.isEmpty {
                    Section {
                        ForEach(detail.facts) { fact in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(fact.label)).font(Typo.meta).foregroundStyle(Palette.muted)
                                Text(fact.value)
                            }
                        }
                    }
                }
                if !detail.links.isEmpty {
                    Section("Connections") {
                        ForEach(detail.links) { link in
                            if let target = store.index?.item(ref: link.ref) {
                                NavigationLink(value: target) { linkRow(link) }
                            } else {
                                linkRow(link)
                            }
                        }
                    }
                }
                if let website = detail.website {
                    Section { Link(destination: website) { Label("Website", systemImage: "safari") } }
                }
            } else if failed {
                Section { Text("More detail is not available offline yet.").foregroundStyle(Palette.muted) }
            } else {
                Section { ProgressView() }
            }
            if let page = item.page {
                Section { Link(destination: page) { Label("Open on promptugal.news", systemImage: "arrow.up.right.square") } }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: item.id) {
            failed = false
            do { detail = try await store.source.detail(for: item) } catch is CancellationError {} catch { failed = true }
        }
    }

    private func linkRow(_ link: ExploreDetail.Link) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(link.verb).font(Typo.meta).foregroundStyle(Palette.muted)
            Text(link.label)
        }
    }
}

/// Dates and times in Lisbon time, which is how the site publishes them.
enum ExploreFormat {
    static let lisbon = TimeZone(identifier: "Europe/Lisbon") ?? .gmt

    static func day(_ day: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = lisbon
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return day }
        let out = DateFormatter()
        out.timeZone = lisbon
        out.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return out.string(from: date)
    }

    static func time(_ item: ExploreItem) -> String? {
        guard let start = item.start else { return nil }
        return item.end.map { "\(start)–\($0)" } ?? start
    }
}
