import PTCore
import SwiftUI

/// Views the app plugs in, because they live in packages PTExplore cannot see. All are optional.
public struct ExploreHooks {
    /// The Talks segment, e.g. the agenda list from PTAgenda. Without it, Talks is PTExplore's own list.
    public var talks: (@MainActor () -> AnyView)?
    /// The detail of a talk (with the pick star and Add to Calendar). Without it, the generic detail shows.
    public var talkDetail: (@MainActor (ExploreItem) -> AnyView)?
    /// A card above the search, e.g. "Your graph" (shown by the app only with three or more picks).
    public var header: (@MainActor () -> AnyView)?
    /// The graph screen, opened by `ExploreStart.graph`.
    public var graph: (@MainActor () -> AnyView)?
    /// The pick and calendar controls shown on PTExplore's own talk detail.
    public var talkActions: TalkActions

    public init(talks: (@MainActor () -> AnyView)? = nil,
                talkDetail: (@MainActor (ExploreItem) -> AnyView)? = nil,
                header: (@MainActor () -> AnyView)? = nil,
                graph: (@MainActor () -> AnyView)? = nil,
                talkActions: TalkActions = TalkActions()) {
        self.talks = talks
        self.talkDetail = talkDetail
        self.header = header
        self.graph = graph
        self.talkActions = talkActions
    }
}

/// Where the screen opens. The shell passes one for each destination id it routes:
/// `explore` → `.talks`, `explore.people` → `.speakers`, `explore.talk` → `.talk(nil)` (or a talk's reference),
/// `explore.graph` → `.graph`.
public enum ExploreStart: Equatable, Sendable {
    case talks, speakers, companies, places
    /// A talk's detail. `nil` opens the first talk of 10 Nov (or the first talk there is).
    case talk(ref: String?)
    /// The graph screen from `ExploreHooks.graph`.
    case graph

    var kind: ExploreKind {
        switch self {
        case .talks, .talk, .graph: .event
        case .speakers: .person
        case .companies: .company
        case .places: .place
        }
    }
}

struct ExploreGraphRoute: Hashable {}

/// The Explore screen: search across talks, speakers, companies and places, a segment for each, and a detail page.
/// Open it with `ExploreScreen()`; it brings its own navigation stack.
public struct ExploreScreen: View {
    @State private var store: ExploreStore
    @State private var path = NavigationPath()
    @State private var started = false
    let hooks: ExploreHooks
    let start: ExploreStart

    public init(store: ExploreStore? = nil, hooks: ExploreHooks = ExploreHooks(), start: ExploreStart = .talks) {
        let store = store ?? ExploreStore()
        store.kind = start.kind
        _store = State(initialValue: store)
        self.hooks = hooks
        self.start = start
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ExploreListView(store: store, hooks: hooks)
                .navigationTitle(String(localized: "Explore", bundle: .module))
                .navigationDestination(for: ExploreGraphRoute.self) { _ in
                    if let graph = hooks.graph { graph() }
                }
                .navigationDestination(for: ExploreItem.self) { item in
                    if item.kind == .event, let talkDetail = hooks.talkDetail {
                        talkDetail(item)
                    } else if item.kind == .event {
                        TalkDetailView(talk: TalkRef(item), store: store, actions: hooks.talkActions)
                    } else {
                        ExploreDetailView(item: item, store: store)
                    }
                }
        }
        .task(id: store.index?.items.count) { openStart() }
    }

    /// Pushes the start destination once, when it can be shown.
    private func openStart() {
        guard !started else { return }
        switch start {
        case .graph:
            started = true
            if hooks.graph != nil { path.append(ExploreGraphRoute()) }
        case .talk(let ref):
            guard let index = store.index else { return }
            started = true
            let talks = ExploreSearch.search(index, query: "", kind: .event)
            let pick = ref.flatMap { index.item(ref: $0) }
                ?? talks.first { $0.day == "2026-11-10" } ?? talks.first
            if let pick { path.append(pick) }
        default:
            started = true
        }
    }
}

public struct ExploreListView: View {
    @Bindable var store: ExploreStore
    let hooks: ExploreHooks

    public init(store: ExploreStore, hooks: ExploreHooks = ExploreHooks()) {
        self.store = store
        self.hooks = hooks
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let header = hooks.header { header().padding(.horizontal, Space.l).padding(.top, Space.s) }
            Picker(String(localized: "Show", bundle: .module), selection: $store.kind) {
                ForEach(ExploreKind.browsable) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            content
        }
        .searchable(text: $store.query, prompt: String(localized: "Search talks, speakers, companies, places", bundle: .module))
        .task { if store.index == nil { await store.load() } }
        .refreshable { await store.load() }
    }

    @ViewBuilder private var content: some View {
        if store.isSearching {
            searchResults
        } else if store.kind == .event, let talks = hooks.talks {
            talks()
        } else if store.index == nil {
            if case .failed(let message) = store.phase {
                ContentUnavailableView {
                    Label(String(localized: "Nothing to show yet", bundle: .module), systemImage: "wifi.slash")
                } description: {
                    Text(String(localized: "The summit data loads once online, then works offline. \(message)", bundle: .module))
                } actions: {
                    Button(String(localized: "Try again", bundle: .module)) { Task { await store.load() } }
                }
            } else {
                ProgressView(String(localized: "Loading…", bundle: .module)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if store.kind == .event {
            talkList
        } else {
            alphabetical
        }
    }

    @ViewBuilder private var searchResults: some View {
        let groups = store.grouped()
        if store.index == nil {
            ProgressView(String(localized: "Loading…", bundle: .module)).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groups.isEmpty {
            ContentUnavailableView.search(text: store.query)
        } else {
            List {
                ForEach(groups, id: \.kind) { group in
                    Section(group.kind.title) {
                        ForEach(group.items) { row($0) }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var talkList: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section(ExploreFormat.day(group.day)) {
                    ForEach(group.items) { row($0) }
                }
            }
        }
        .listStyle(.plain)
    }

    private var alphabetical: some View {
        let sections = ExploreStore.letterSections(store.results)
        return List {
            ForEach(sections, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.items) { row($0) }
                }
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
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                if let time = ExploreFormat.time(item) {
                    Text(time).font(Typo.dataSmall).foregroundStyle(Palette.red)
                        .frame(width: 64, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Typo.headline)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle).font(Typo.meta).foregroundStyle(Palette.muted).lineLimit(2)
                    }
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
                    Label(item.kind.title, systemImage: item.kind.symbol)
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
                                Text(fact.label).font(Typo.meta).foregroundStyle(Palette.muted)
                                Text(fact.value)
                            }
                        }
                    }
                }
                if !detail.speakers.isEmpty {
                    Section(String(localized: "Speakers", bundle: .module)) {
                        ForEach(detail.speakers) { link in
                            if let target = store.index?.item(ref: link.ref) {
                                NavigationLink(value: target) { Text(link.label) }
                            } else {
                                Text(link.label)
                            }
                        }
                    }
                }
                if !detail.otherLinks.isEmpty {
                    Section(String(localized: "Connections", bundle: .module)) {
                        ForEach(detail.otherLinks) { link in
                            if let target = store.index?.item(ref: link.ref) {
                                NavigationLink(value: target) { linkRow(link) }
                            } else {
                                linkRow(link)
                            }
                        }
                    }
                }
                if let website = detail.website {
                    Section { Link(destination: website) { Label(String(localized: "Website", bundle: .module), systemImage: "safari") } }
                }
            } else if failed {
                Section { Text(item.kind == .event ? String(localized: "Connect to see speakers", bundle: .module) : String(localized: "Saved details not available offline yet", bundle: .module)).foregroundStyle(Palette.muted) }
            } else {
                Section { ProgressView() }
            }
            if let page = item.page {
                Section { Link(destination: page) { Label(String(localized: "Open on promptugal.news", bundle: .module), systemImage: "arrow.up.right.square") } }
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
