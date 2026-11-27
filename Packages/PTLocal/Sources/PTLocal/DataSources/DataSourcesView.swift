import PTCore
import SwiftUI

/// Every PrompTugal.news site the app draws on, on one screen: what each covers, how many items it holds, how fresh
/// its data is by its own read time (live under 3 hours, otherwise a snapshot with its date), and a link to the site.
/// data.promptugal.news lists each of its sources with cadence, state and last read. Read-only.
public struct DataSourcesView: View {
    @State private var store = DataSourcesStore.shared

    public init() {}

    public var body: some View {
        Page {
            ScreenHeader(kicker: LocalText.string("PrompTugal.news"), title: LocalText.string("Data sources"),
                         summary: LocalText.string("The public sites behind this app: what each covers, how much it holds and when it last read its data. Live means read in the last 3 hours."))
            summaryLine
            ForEach(DataSite.all) { site in
                DataSiteCard(site: site, reading: store.readings[site.id], provenance: store.provenance[site.id],
                             phase: store.phase)
            }
            if let index = store.index {
                DataCatalogueCard(index: index, provenance: store.provenance["data"] ?? .none)
            }
            GapNote(title: LocalText.string("What is real here"),
                    text: LocalText.string("Each count and read time comes from the site's own feed, read by this device. Weather, events and signals are counted from data.promptugal.news's catalogue. A site without a feed the app reads says so."))
        }
        .navigationTitle(LocalText.string("Data sources"))
        .task { await store.load() }
        .refreshable { await store.load(force: true) }
    }

    @ViewBuilder private var summaryLine: some View {
        let counts = store.freshCounts(now: Date())
        if counts.dated > 0 {
            Text(LocalText.string("\(String(describing: counts.live)) of \(String(describing: counts.dated)) sites read their data in the last 3 hours."))
                .font(.footnote)
                .foregroundStyle(counts.live == counts.dated ? Palette.muted : Palette.amber)
        } else if store.phase == .loading {
            ProgressView().controlSize(.small)
        }
    }
}

/// One site: name, what it covers, its count, its freshness and its link.
struct DataSiteCard: View {
    let site: DataSite
    let reading: SiteReading?
    let provenance: Provenance?
    let phase: LoadPhase

    var body: some View {
        TitledCard(site.name, kicker: kicker) {
            Text(site.covers).font(.footnote).foregroundStyle(Palette.ink)
            if let text = reading?.countText {
                Text(text).font(.headline.monospacedDigit()).foregroundStyle(Palette.ink)
            }
            if let note = reading?.note {
                Text(note).font(.caption).foregroundStyle(Palette.muted)
            }
            freshness
            Link(destination: site.site) {
                Label(LocalText.string("Open \(String(describing: site.name))"), systemImage: "arrow.up.right.square")
            }
            .font(.footnote)
        }
    }

    private var kicker: String {
        switch site.id {
        case "weather", "events", "signals": LocalText.string("Through data.promptugal.news")
        case "startups": LocalText.string("Pages only")
        default: "Site"
        }
    }

    /// Where the count was read: the catalogue for the derived sites, the site itself otherwise.
    private var readFrom: String {
        site.feed == nil ? "data.promptugal.news" : (site.site.host() ?? site.name)
    }

    @ViewBuilder private var freshness: some View {
        if let reading, let provenance {
            ProvenanceLabel(provenance: provenance, phase: .idle, readAt: reading.readAt, host: readFrom)
        } else if site.feed == nil && site.id == "startups" {
            Text(LocalText.string("No small feed the app reads: open the site for its pages and their read dates."))
                .font(.caption).foregroundStyle(Palette.muted)
        } else if phase == .loading {
            Text(LocalText.string("Reading…")).font(.caption).foregroundStyle(Palette.muted)
        } else {
            Text(LocalText.string("Not read: the site could not be reached.")).font(.caption).foregroundStyle(Palette.amber)
        }
    }
}

/// data.promptugal.news's sources, each with cadence, state, headline and last read, linking to its page.
struct DataCatalogueCard: View {
    let index: DataIndex
    let provenance: Provenance

    var body: some View {
        TitledCard(LocalText.string("The \(String(describing: index.sources.count)) sources of data.promptugal.news"), kicker: LocalText.string("Catalogue")) {
            ForEach(index.sources) { source in
                DataSourceRow(source: source)
                Divider()
            }
            ProvenanceLabel(provenance: provenance, phase: .idle, readAt: index.newestRead, host: "data.promptugal.news")
        }
    }
}

struct DataSourceRow: View {
    let source: DataIndex.Source

    var body: some View {
        let freshness = Freshness.of(source.readDate)
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(content: source.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Space.s)
                Text(content: source.status ?? "").font(.caption2).foregroundStyle(statusColor)
            }
            if let headline = source.headline {
                Text(headline).font(.footnote).foregroundStyle(Palette.ink)
            }
            Text(detail(freshness)).font(.caption).foregroundStyle(freshness.isLive ? Palette.muted : Palette.amber)
        }
        if let url = source.pageURL {
            Link(destination: url) { content }
                .buttonStyle(.plain)
                .accessibilityHint(LocalText.string("Opens the source's page on data.promptugal.news"))
        } else {
            content
        }
    }

    private var statusColor: Color {
        switch source.status {
        case "ok": Palette.green
        case "archived": Palette.muted
        default: Palette.amber
        }
    }

    private func detail(_ freshness: Freshness) -> String {
        var parts: [String] = []
        if let publisher = source.publisher { parts.append(publisher) }
        if let cadence = source.cadence { parts.append(cadence) }
        parts.append(freshness.label())
        return parts.joined(separator: " · ")
    }
}

/// A small card for the places home: how many sites read their data recently, and a link to the Data sources screen.
public struct DataSourcesCard: View {
    @State private var store = DataSourcesStore.shared

    public init() {}

    public var body: some View {
        NavigationLink {
            DataSourcesView()
        } label: {
            Card {
                Label(LocalText.string("Data sources"), systemImage: "square.stack.3d.up").font(.headline).foregroundStyle(Palette.ink)
                Text(line).font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .task { await store.load() }
    }

    private var line: String {
        let counts = store.freshCounts(now: Date())
        let base = LocalText.string("The \(String(describing: DataSite.all.count)) public sites behind this app, each with its own read time.")
        guard counts.dated > 0 else { return base }
        return base + LocalText.string(" \(String(describing: counts.live)) of \(String(describing: counts.dated)) read in the last 3 hours.")
    }
}
