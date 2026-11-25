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
    /// Leading items for the screen's navigation bar, e.g. the app's language button.
    public var leadingToolbar: (@MainActor () -> AnyView)?
    /// Trailing items for the screen's navigation bar, e.g. the app's More button.
    public var trailingToolbar: (@MainActor () -> AnyView)?
    /// False leaves Talks out: no Talks segment and no talks in search. The screen then opens on Speakers.
    public var showsTalks: Bool
    /// True adds, at the end of each list, the "Lisbon summit 2026" row (the summit's index) and, with `graph`,
    /// the newsroom's graph. The newsroom's Explore sets it.
    public var showsSummit: Bool

    public init(talks: (@MainActor () -> AnyView)? = nil,
                talkDetail: (@MainActor (ExploreItem) -> AnyView)? = nil,
                header: (@MainActor () -> AnyView)? = nil,
                graph: (@MainActor () -> AnyView)? = nil,
                talkActions: TalkActions = TalkActions(),
                leadingToolbar: (@MainActor () -> AnyView)? = nil,
                trailingToolbar: (@MainActor () -> AnyView)? = nil,
                showsTalks: Bool = true,
                showsSummit: Bool = false) {
        self.talks = talks
        self.talkDetail = talkDetail
        self.header = header
        self.graph = graph
        self.talkActions = talkActions
        self.leadingToolbar = leadingToolbar
        self.trailingToolbar = trailingToolbar
        self.showsTalks = showsTalks
        self.showsSummit = showsSummit
    }
}

/// Where the screen opens. The shell passes one for each destination id it routes:
/// `explore` → `.talks`, `explore.people` → `.speakers`, `explore.talk` → `.talk(nil)` (or a talk's reference),
/// `explore.graph` → `.graph`.
public enum ExploreStart: Equatable, Sendable {
    case talks, speakers, companies, places
    /// The newsroom's segments.
    case stories, library
    /// The Lisbon summit 2026 index, behind its row.
    case summit
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
        case .stories, .summit: .article
        case .library: .library
        }
    }
}

struct ExploreGraphRoute: Hashable {}
struct ExploreSummitRoute: Hashable {}
/// An entry of the summit index, opened with the summit's store (so its links find the summit's entries).
struct ExploreSummitItemRoute: Hashable { let item: ExploreItem }

/// The Explore screen: search across the store's kinds (the newsroom's stories, companies, places and library, or the
/// summit's talks, speakers, companies and places), a segment for each, and a detail page.
/// Open it with `ExploreScreen()`; it brings its own navigation stack.
public struct ExploreScreen: View {
    @State private var store: ExploreStore
    @State private var summit: ExploreStore
    @State private var path = NavigationPath()
    @State private var started = false
    let hooks: ExploreHooks
    let start: ExploreStart

    public init(store: ExploreStore? = nil, hooks: ExploreHooks = ExploreHooks(), start: ExploreStart = .talks) {
        let store = store ?? ExploreStore()
        if !hooks.showsTalks { store.kinds.removeAll { $0 == .event } }
        store.kind = store.kinds.contains(start.kind) ? start.kind : (store.kinds.first ?? start.kind)
        _store = State(initialValue: store)
        _summit = State(initialValue: ExploreStore.summit())
        self.hooks = hooks
        self.start = start
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ExploreListView(store: store, hooks: hooks)
                .navigationTitle(String(localized: "Explore", bundle: .module))
                .toolbar {
                    if let leading = hooks.leadingToolbar {
                        ToolbarItem(placement: .topBarLeading) { leading() }
                    }
                    if let trailing = hooks.trailingToolbar {
                        ToolbarItem(placement: .topBarTrailing) { trailing() }
                    }
                }
                .navigationDestination(for: ExploreGraphRoute.self) { _ in
                    if let graph = hooks.graph { graph() }
                }
                .navigationDestination(for: ExploreSummitRoute.self) { _ in
                    ExploreListView(store: summit, hooks: hooks, inSummit: true)
                        .navigationTitle(String(localized: "Lisbon summit 2026", bundle: .module))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .navigationDestination(for: ExploreSummitItemRoute.self) { route in
                    ExploreDetailView(item: route.item, store: summit, inSummit: true)
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
        case .talk where !hooks.showsTalks:
            started = true
        case .graph:
            started = true
            if hooks.graph != nil { path.append(ExploreGraphRoute()) }
        case .summit:
            started = true
            path.append(ExploreSummitRoute())
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
    /// The summit's own list: rows open with the summit's store, and no summit row at the end.
    let inSummit: Bool

    public init(store: ExploreStore, hooks: ExploreHooks = ExploreHooks()) {
        self.init(store: store, hooks: hooks, inSummit: false)
    }

    init(store: ExploreStore, hooks: ExploreHooks, inSummit: Bool) {
        self.store = store
        self.hooks = hooks
        self.inSummit = inSummit
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !inSummit, let header = hooks.header { header().padding(.horizontal, Space.l).padding(.top, Space.s) }
            picker
            ExploreOriginLine(origin: store.origin, loading: store.phase == .loading)
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.xs)
            content
        }
        .searchable(text: $store.query, prompt: searchPrompt)
        .task { if store.index == nil { await store.load() } }
        .refreshable { await store.load() }
    }

    private var picker: some View {
        Picker(String(localized: "Show", bundle: .module), selection: $store.kind) {
            ForEach(store.shownKinds) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
    }

    private var searchPrompt: String {
        if store.kinds.contains(.article) {
            return String(localized: "Search stories, companies, places, library", bundle: .module)
        }
        if store.kinds.contains(.event) {
            return String(localized: "Search talks, speakers, companies, places", bundle: .module)
        }
        return String(localized: "Search the summit", bundle: .module)
    }

    /// The summit and graph rows at the end of the newsroom's lists.
    private var showsFooter: Bool { hooks.showsSummit && !inSummit }

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
                    Text(String(localized: "Explore loads once online, then works offline. \(message)", bundle: .module))
                } actions: {
                    Button(String(localized: "Try again", bundle: .module)) { Task { await store.load() } }
                }
            } else {
                ProgressView(String(localized: "Loading…", bundle: .module)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if store.kind == .event {
            talkList
        } else if store.kind == .article || store.kind == .library {
            datedList
        } else {
            alphabetical
        }
    }

    /// Stories and library items, newest first.
    private var datedList: some View {
        List {
            Section {
                ForEach(store.results) { row($0) }
            }
            footer
        }
        .listStyle(.plain)
    }

    /// "Lisbon summit 2026" and the newsroom's graph, at the end of each newsroom list.
    @ViewBuilder private var footer: some View {
        if showsFooter {
            Section {
                NavigationLink(value: ExploreSummitRoute()) {
                    footerRow(String(localized: "Lisbon summit 2026", bundle: .module),
                              String(localized: "The November summit's index: people, organisations and companies", bundle: .module),
                              symbol: "calendar")
                }
                .accessibilityIdentifier("pt.explore.summit")
                if hooks.graph != nil {
                    NavigationLink(value: ExploreGraphRoute()) {
                        footerRow(String(localized: "The newsroom's graph", bundle: .module),
                                  String(localized: "How its companies, places and stories connect", bundle: .module),
                                  symbol: "point.3.connected.trianglepath.dotted")
                    }
                    .accessibilityIdentifier("pt.explore.graph")
                }
            }
        }
    }

    private func footerRow(_ title: String, _ subtitle: String, symbol: String) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol).foregroundStyle(Palette.red).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.headline)
                Text(subtitle).font(Typo.meta).foregroundStyle(Palette.muted)
            }
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
            footer
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

    @ViewBuilder private func row(_ item: ExploreItem) -> some View {
        if inSummit {
            NavigationLink(value: ExploreSummitItemRoute(item: item)) { rowLabel(item) }
        } else {
            NavigationLink(value: item) { rowLabel(item) }
        }
    }

    private func rowLabel(_ item: ExploreItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            if item.kind == .library {
                Image(systemName: item.id.hasPrefix("video:") ? "play.rectangle" : "books.vertical")
                    .foregroundStyle(Palette.red).accessibilityHidden(true)
            }
            if let time = ExploreFormat.time(item) {
                // One line, never wrapped: "12:00–12:45" or "11:05 AM" does not fit a fixed 64 pt.
                Text(time).font(Typo.dataSmall).foregroundStyle(Palette.red)
                    .lineLimit(1).fixedSize()
                    .frame(minWidth: 64, alignment: .leading)
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

public struct ExploreDetailView: View {
    let item: ExploreItem
    let store: ExploreStore
    /// Opened from the summit's index: links to other entries open with the summit's store.
    let inSummit: Bool
    @State private var detail: ExploreDetail?
    @State private var failed = false

    public init(item: ExploreItem, store: ExploreStore) {
        self.init(item: item, store: store, inSummit: false)
    }

    init(item: ExploreItem, store: ExploreStore, inSummit: Bool) {
        self.item = item
        self.store = store
        self.inSummit = inSummit
    }

    public var body: some View {
        List {
            Section { header }
            if let detail {
                detailSections(detail)
            } else if failed {
                Section { Text(failureText).foregroundStyle(Palette.muted) }
            } else {
                Section { ProgressView() }
            }
            openSection
            Section {
                ExploreOriginLine(origin: detail?.origin ?? store.origin, loading: detail == nil && !failed)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: item.id) {
            failed = false
            do { detail = try await store.source.detail(for: item) } catch is CancellationError {} catch { failed = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Label(kindTitle, systemImage: kindSymbol)
                .font(Typo.kicker).foregroundStyle(Palette.red)
            Text(item.title).font(Typo.title)
            if let time = ExploreFormat.time(item) { Text(time).font(Typo.data).foregroundStyle(Palette.muted) }
            if !item.subtitle.isEmpty { Text(item.subtitle).font(Typo.body).foregroundStyle(Palette.muted) }
        }
    }

    private var isVideo: Bool { item.id.hasPrefix("video:") }
    private var kindTitle: String { isVideo ? String(localized: "Video", bundle: .module) : item.kind.title }
    private var kindSymbol: String { isVideo ? "play.rectangle" : item.kind.symbol }

    private var failureText: String {
        item.kind == .event ? String(localized: "Connect to see speakers", bundle: .module)
            : String(localized: "Saved details not available offline yet", bundle: .module)
    }

    @ViewBuilder private func detailSections(_ detail: ExploreDetail) -> some View {
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
                ForEach(detail.speakers) { link in linked(link) { Text(link.label) } }
            }
        }
        if !detail.otherLinks.isEmpty {
            Section(String(localized: "Connections", bundle: .module)) {
                ForEach(detail.otherLinks) { link in linked(link) { linkRow(link) } }
            }
        }
        if !detail.sources.isEmpty {
            Section(String(localized: "Sources", bundle: .module)) {
                ForEach(detail.sources) { source in sourceRow(source) }
            }
        }
        if let website = detail.website {
            Section { Link(destination: website) { Label(String(localized: "Website", bundle: .module), systemImage: "safari") } }
        }
    }

    /// A row that opens the other entry when the index has it, else plain text.
    @ViewBuilder private func linked<Content: View>(_ link: ExploreDetail.Link, @ViewBuilder label: () -> Content) -> some View {
        if let target = store.index?.item(ref: link.ref) {
            if inSummit {
                NavigationLink(value: ExploreSummitItemRoute(item: target)) { label() }
            } else {
                NavigationLink(value: target) { label() }
            }
        } else {
            label()
        }
    }

    private func sourceRow(_ source: ExploreDetail.Source) -> some View {
        Link(destination: source.url) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label).lineLimit(3)
                Text(source.url.host() ?? source.url.absoluteString).font(Typo.meta).foregroundStyle(Palette.muted)
            }
        }
    }

    /// The original (a video, a replay) and the entry's own page.
    @ViewBuilder private var openSection: some View {
        let page = detail?.pageURL ?? item.page
        if item.link != nil || page != nil {
            Section {
                if let link = item.link {
                    Link(destination: link) {
                        Label(Self.originalTitle(link),
                              systemImage: NewsroomWire.youTubeID(link) != nil ? "play.rectangle" : "arrow.up.right.square")
                    }
                }
                if let page {
                    Link(destination: page) { Label(Self.pageTitle(page), systemImage: "arrow.up.right.square") }
                }
            }
        }
    }

    static func originalTitle(_ url: URL) -> String {
        if NewsroomWire.youTubeID(url) != nil { return String(localized: "Watch on YouTube", bundle: .module) }
        return String(localized: "Open the original", bundle: .module)
    }

    static func pageTitle(_ url: URL) -> String {
        let host = (url.host() ?? "promptugal.news").replacingOccurrences(of: "www.", with: "")
        if host == "promptugal.news" { return String(localized: "Open on promptugal.news", bundle: .module) }
        return String(localized: "Open on \(host)", bundle: .module)
    }

    private func linkRow(_ link: ExploreDetail.Link) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(link.verb).font(Typo.meta).foregroundStyle(Palette.muted)
            Text(link.label)
        }
    }
}

/// Says where the screen's entries came from: live, this device's copy, or the copy built into the app.
struct ExploreOriginLine: View {
    let origin: ExploreOrigin?
    let loading: Bool

    var body: some View {
        HStack(spacing: 6) {
            if loading { ProgressView().controlSize(.mini) }
            Image(systemName: icon).accessibilityHidden(true)
            Text(Self.label(origin, loading: loading))
            if let date = origin?.date, origin?.kind != .builtIn {
                Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(origin?.kind == .live ? Palette.muted : Palette.amber)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pt.explore.provenance")
    }

    static func label(_ origin: ExploreOrigin?, loading: Bool) -> String {
        guard let origin else {
            return loading ? String(localized: "Loading…", bundle: .module) : String(localized: "Not loaded", bundle: .module)
        }
        switch origin.kind {
        case .live: return String(localized: "Live from PrompTugal.news", bundle: .module)
        case .cached: return String(localized: "Offline: the last copy this device read", bundle: .module)
        case .builtIn:
            let day = origin.snapshotDay ?? NewsroomExploreSource.snapshotDay
            return String(localized: "Built-in copy of \(day): connect to update", bundle: .module)
        }
    }

    private var icon: String {
        switch origin?.kind {
        case .live: "dot.radiowaves.left.and.right"
        case .cached: "wifi.slash"
        case .builtIn: "shippingbox"
        case nil: "questionmark.circle"
        }
    }
}

/// Dates and times in Lisbon time, which is how the site publishes them.
enum ExploreFormat {
    /// The site's event kinds ("session", "registration", ...) in the person's language. Unknown kinds show as the site wrote them.
    static func kindTitle(_ raw: String) -> String {
        switch raw.lowercased() {
        case "session": String(localized: "Session", bundle: .module)
        case "registration": String(localized: "Registration", bundle: .module)
        case "announcement": String(localized: "Announcement", bundle: .module)
        case "night-summit": String(localized: "Night summit", bundle: .module)
        case "pitch": String(localized: "Pitch", bundle: .module)
        case "side-event": String(localized: "Side event", bundle: .module)
        case "summit": String(localized: "Summit", bundle: .module)
        default: raw.prefix(1).uppercased() + raw.dropFirst()
        }
    }

    static let lisbon = TimeZone(identifier: "Europe/Lisbon") ?? .gmt

    static func day(_ day: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = lisbon
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return day }
        let out = DateFormatter()
        out.timeZone = lisbon
        out.locale = AppCulture.locale
        out.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return out.string(from: date)
    }

    /// `2026-11-24` → "24 Nov 2026" in the person's language; anything else as given.
    static func date(_ day: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = lisbon
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(day.prefix(10))) else { return day }
        let out = DateFormatter()
        out.timeZone = lisbon
        out.locale = AppCulture.locale
        out.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return out.string(from: date)
    }

    static func time(_ item: ExploreItem) -> String? {
        guard let start = item.start else { return nil }
        return item.end.map { "\(start)–\($0)" } ?? start
    }
}
