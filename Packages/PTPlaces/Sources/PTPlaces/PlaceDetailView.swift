import PTCore
import SwiftUI

/// One place, as a magazine spread: an aerial hero, the two-line mandate, its centre of gravity, the local AI news
/// (the lead big), the AI map drawn as connections, events, the agents behind it (conductor-report/v1), what we do
/// not know yet, and how the page is made (who signed it, sources and read dates).
public struct PlaceDetailView: View {
    let id: String
    @State private var store = PlacesStore.shared
    /// The labelled Algarvio voice toggle: the same facts, in a local voice.
    @State private var algarvio = false
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.openURL) private var openURL

    public init(id: String) { self.id = id }

    private var place: PlaceSummary? { store.place(id) }
    private var file: PlaceFile? { store.file(id) }
    private var accent: Color { PlaceTheme.accent(file, id: id) }
    private var wide: Bool { width == .regular }
    private var gutter: CGFloat { wide ? Space.xxl : Space.l }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let place {
                    hero(place)
                    VStack(alignment: .leading, spacing: Space.xl) {
                        mandate
                        numbers(place)
                        gravity
                        children
                        news
                        aiMap
                        events
                        agents(place)
                        gaps
                        provenance(place)
                    }
                    .padding(.horizontal, gutter)
                    .frame(maxWidth: 1_100, alignment: .leading)
                    .frame(maxWidth: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.bottom, Space.xxl)
        }
        .background(Palette.paper)
        .ignoresSafeArea(edges: wide ? [] : .top)
        .navigationTitle(place?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let place {
                    Menu {
                        if file?.voice != nil {
                            Toggle(isOn: $algarvio.animation()) {
                                Label(String(localized: "Algarvio voice (for fun)"), systemImage: "theatermasks")
                            }
                        }
                        Button {
                            openURL(PlacesStore.pageURL(place))
                        } label: {
                            Label(String(localized: "Open on promptugal.news"), systemImage: "safari")
                        }
                        ShareLink(item: PlacesStore.pageURL(place))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("places.detail.menu")
                }
            }
        }
        .refreshable {
            await store.loadPlace(id, force: true)
            if let place { await store.loadAgents(for: place, force: true) }
        }
        .task {
            if store.places.isEmpty { await store.load() }
            await store.loadPlace(id)
            if let place { await store.loadAgents(for: place) }
        }
        .accessibilityIdentifier("places.detail.\(id)")
    }

    // MARK: Hero

    private func hero(_ place: PlaceSummary) -> some View {
        ZStack(alignment: .bottomLeading) {
            SatelliteView(place: place, pitch: 62, heading: 25)
            LinearGradient(colors: [.black.opacity(0.25), .clear, accent.opacity(0.55), accent.opacity(0.95)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    Kicker(text: "PrompTugal.news · \(place.name)", color: .white.opacity(0.9))
                    StatusPill(status: place.status, onDark: true)
                }
                Text(place.name)
                    .font(.system(size: wide ? 84 : 56, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let look = file?.look {
                    Text(look.landmark).font(wide ? .title3 : .subheadline).foregroundStyle(.white.opacity(0.92))
                    if !look.motif.isEmpty {
                        Text(look.motif).font(.caption).italic().foregroundStyle(.white.opacity(0.75))
                    }
                }
                if algarvio, let lede = file?.voice?.lede, !lede.isEmpty {
                    Text(lede).font(.system(.headline, design: .serif).italic()).foregroundStyle(.white)
                        .padding(.top, 4)
                }
            }
            .padding(gutter)
            .padding(.bottom, Space.s)
        }
        .frame(height: wide ? 520 : 440)
        .clipped()
    }

    // MARK: Mandate and numbers

    @ViewBuilder private var mandate: some View {
        if let file {
            let text = algarvio ? (file.voice?.mandate ?? file.mandate) : file.mandate
            HStack(alignment: .top, spacing: Space.m) {
                Rectangle().fill(accent).frame(width: 5)
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker(text: algarvio ? String(localized: "The mandate, in Algarvio (same facts)") : String(localized: "The mandate"), color: accent)
                    Text(text)
                        .font(.system(wide ? .title2 : .title3, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, Space.l)
        }
    }

    @ViewBuilder private func numbers(_ place: PlaceSummary) -> some View {
        let stories = BigNumber(value: file?.aiNews.count ?? place.aiNews, label: String(localized: "AI stories"), accent: accent)
        let map = BigNumber(value: file?.aiMap.count ?? place.aiMap, label: String(localized: "on the AI map"), accent: accent)
        let events = BigNumber(value: file?.events.count ?? 0, label: String(localized: "events"), accent: accent)
        let sources = BigNumber(value: file?.sources.count ?? 0, label: String(localized: "sources"), accent: accent)
        if wide {
            HStack(spacing: Space.xxl) { stories; map; events; sources }
        } else {
            Grid(alignment: .leading, horizontalSpacing: Space.xl, verticalSpacing: Space.m) {
                GridRow { stories; map }
                GridRow { events; sources }
            }
        }
    }

    // MARK: Centre of gravity

    @ViewBuilder private var gravity: some View {
        if let gravity = file?.gravity, !gravity.text.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Centre of gravity"),
                            subtitle: String(localized: "Where AI weighs in this place, found from sources, never invented"), accent: accent)
                Text(algarvio ? (file?.voice?.gravity ?? gravity.text) : gravity.text)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(gravity.sources, id: \.self) { source in
                    SourceLine(title: source.title, url: source.url, readOn: source.readOn, accent: accent)
                }
            }
            .padding(Space.l)
            .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: Space.radius))
        }
    }

    // MARK: The places under this one (the country and the region)

    @ViewBuilder private var children: some View {
        let kids = store.children(of: id)
        if !kids.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: id == "portugal" ? String(localized: "The regions") : String(localized: "The towns"), accent: accent)
                if id == "algarve" {
                    RegionMap(store: store, interactive: true)
                        .frame(height: wide ? 460 : 340)
                        .clipShape(RoundedRectangle(cornerRadius: Space.radius))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: wide ? 200 : 150), spacing: Space.m)], spacing: Space.m) {
                    ForEach(Array(kids.enumerated()), id: \.element.id) { index, kid in
                        NavigationLink(value: PlaceRoute(kid.id)) {
                            TownTile(place: kid, file: store.file(kid.id), seed: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: News

    @ViewBuilder private var news: some View {
        let items = file?.newsByWeight ?? []
        if let lead = items.first {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Local AI news"),
                            subtitle: String(localized: "Each story passes the PrompTugal test: AI within three steps, with the path written down"), accent: accent)
                LeadStory(item: lead, accent: accent)
                let rest = Array(items.dropFirst())
                if !rest.isEmpty {
                    let columns = wide ? [GridItem(.flexible(), spacing: Space.l), GridItem(.flexible(), spacing: Space.l)] : [GridItem(.flexible())]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Space.l) {
                        ForEach(rest) { item in
                            StoryTile(item: item, accent: accent, place: place)
                                .frame(minHeight: 220)
                        }
                    }
                }
            }
        }
    }

    // MARK: The AI map, as connections

    @ViewBuilder private var aiMap: some View {
        let entries = file?.aiMap ?? []
        if !entries.isEmpty, let place {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "The AI map"),
                            subtitle: String(localized: "Who does AI here, and how close each is: the nearer the centre, the fewer steps from AI"), accent: accent)
                ConnectionsGraph(center: place.name, entries: entries, accent: accent)
                    .frame(height: wide ? 520 : 380)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
                let columns = [GridItem(.adaptive(minimum: wide ? 300 : 280), spacing: Space.m)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: Space.m) {
                    ForEach(entries) { entry in
                        MapEntryCard(entry: entry, accent: accent)
                    }
                }
            }
        }
    }

    // MARK: Events

    @ViewBuilder private var events: some View {
        let items = file?.events ?? []
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHead(title: String(localized: "Events"), accent: accent)
                ForEach(items) { event in
                    Button {
                        if let url = URL(string: event.url) { openURL(url) }
                    } label: {
                        HStack(alignment: .top, spacing: Space.m) {
                            VStack(spacing: 0) {
                                Text(dayNumber(event.date)).font(.system(.title, design: .serif, weight: .bold))
                                Text(monthName(event.date)).font(.caption2.weight(.bold)).textCase(.uppercase)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 64)
                            .background(accent, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.headline).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                                Text(event.date).font(.caption).foregroundStyle(Palette.muted)
                                if !event.aiPath.isEmpty {
                                    Text(event.aiPath).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dayNumber(_ text: String) -> String {
        guard let date = PlaceDates.parse(String(text.prefix(10))) else { return "·" }
        return String(Calendar(identifier: .gregorian).component(.day, from: date))
    }

    private func monthName(_ text: String) -> String {
        guard let date = PlaceDates.parse(String(text.prefix(10))) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    // MARK: Agents

    @ViewBuilder private func agents(_ place: PlaceSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHead(title: String(localized: "The agents behind \(place.name)"),
                        subtitle: String(localized: "What each one is doing now, from its own record. Powered by AgentiCCells."), accent: accent)
            if let report = store.agentsReport(for: place) {
                AgentsPanel(report: report, accent: accent, placeAgent: place.agent)
            } else {
                HStack(spacing: Space.m) {
                    ProgressView()
                    Text(String(localized: "Reading the agents' status records")).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    // MARK: Gaps

    @ViewBuilder private var gaps: some View {
        let items = file?.gaps ?? []
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "What we do not know yet"),
                            subtitle: String(localized: "The place agent's open questions, shown on purpose"), accent: accent)
                ForEach(items, id: \.self) { gap in
                    Label {
                        Text(gap).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "questionmark.circle").foregroundStyle(accent)
                    }
                }
            }
        }
    }

    // MARK: Provenance

    private func provenance(_ place: PlaceSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHead(title: String(localized: "How this page is made"), accent: accent)
            Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: 6) {
                provenanceRow(String(localized: "Written by"), file?.by ?? place.agent)
                provenanceRow(String(localized: "Updated"), PlaceDates.short(file?.updated ?? place.updated))
                if let identity = file?.identity {
                    provenanceRow(String(localized: "Signed with"), identity.keyID)
                }
                provenanceRow(String(localized: "Data"), PlacesStore.placeURL(place.id).absoluteString)
            }
            .font(.footnote)
            if let sources = file?.sources, !sources.isEmpty {
                Text(String(localized: "Sources the agent reads")).font(.footnote.weight(.semibold)).padding(.top, Space.s)
                FlowChips(items: sources.map { ($0.name, $0.url, $0.kind) }, accent: accent)
            }
        }
        .padding(Space.l)
        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: Space.radius))
    }

    private func provenanceRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(Palette.muted)
            Text(value).foregroundStyle(Palette.ink).textSelection(.enabled)
        }
    }
}

// MARK: - Parts

/// The lead story, set big, with its AI path drawn as a line of steps.
struct LeadStory: View {
    let item: NewsItem
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: item.url) { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Kicker(text: String(localized: "The lead"), color: accent)
                    Spacer()
                    Text([item.publisher, PlaceDates.short(item.date)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Text(item.title)
                    .font(Typo.storyDisplay)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.summary)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.aiPath.isEmpty {
                    HStack(alignment: .top, spacing: Space.s) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 4) {
                            StepsBadge(steps: item.steps, accent: accent)
                            Text(item.aiPath).font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(Space.m)
                    .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                HStack {
                    Label(String(localized: "Read at the source"), systemImage: "arrow.up.right.square")
                    Spacer()
                    if !item.readOn.isEmpty {
                        Text(String(localized: "read on \(PlaceDates.short(item.readOn))")).foregroundStyle(Palette.muted)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
            }
            .padding(Space.xl)
            .background(Palette.card)
            .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 6) }
            .clipShape(RoundedRectangle(cornerRadius: Space.radius))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("places.lead")
    }
}

/// One entity on the AI map: what it is, how it connects to AI, and its source with the read date.
struct MapEntryCard: View {
    let entry: MapEntry
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.s) {
                Image(systemName: ConnectionsGraph.symbol(entry.type))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(ConnectionsGraph.color(entry.type, accent: accent), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.name).font(.headline).foregroundStyle(Palette.ink)
                    Text(entry.type.capitalized).font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if let url = URL(string: entry.url), !entry.url.isEmpty {
                    Button { openURL(url) } label: { Image(systemName: "arrow.up.right.square") }
                        .accessibilityLabel(String(localized: "Open \(entry.name)"))
                }
            }
            if !entry.what.isEmpty {
                Text(entry.what).font(.subheadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            StepsBadge(steps: entry.steps, accent: accent)
            if !entry.aiPath.isEmpty {
                Text(entry.aiPath).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            if !entry.sourceURL.isEmpty {
                SourceLine(title: URL(string: entry.sourceURL)?.host() ?? entry.sourceURL, url: entry.sourceURL,
                           readOn: entry.readOn, accent: accent)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).stroke(Palette.rule, lineWidth: 0.5))
    }
}

/// A source with its read date: the provenance line.
struct SourceLine: View {
    let title: String
    let url: String
    let readOn: String
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let link = URL(string: url) { openURL(link) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "link").font(.caption2)
                Text(title).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if !readOn.isEmpty {
                    Text(String(localized: "read \(PlaceDates.short(readOn))")).font(.caption2).foregroundStyle(Palette.muted)
                }
            }
            .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping chips for the sources.
struct FlowChips: View {
    let items: [(String, String, String)]
    let accent: Color
    @Environment(\.openURL) private var openURL

    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    if let url = URL(string: item.1) { openURL(url) }
                } label: {
                    Text(item.0)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent.opacity(0.12), in: Capsule())
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Lays children out left to right, wrapping to new lines.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
