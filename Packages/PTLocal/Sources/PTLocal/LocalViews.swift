import MapKit
import PTCore
import SwiftUI

// MARK: - The Algarve

/// PrompTugal.news The Algarve, native: the region's mandate, the map of its 17 places, the latest from the towns,
/// the towns you follow first. Every story opens its source; every screen says whether its data is live.
public struct AlgarveView: View {
    @State private var store = LocalStore.shared
    @AppStorage("local.voice") private var algarvio = false

    public init() {}

    public var body: some View {
        Page {
            header
            HStack {
                ProvenanceLabel(provenance: store.placeProvenance, phase: store.phase)
                Spacer()
                CreditChip()
            }
            StatGrid(minimum: 120) {
                StatTile(label: "Places", value: "\(PlaceDirectory.towns.count)", detail: "first wave")
                StatTile(label: "Live sites", value: "\(store.liveTownCount)", detail: "the rest researching", tone: .good)
                StatTile(label: "Local AI stories", value: "\(store.storyCount)")
                StatTile(label: "On the AI map", value: "\(store.mappedCount)")
            }
            AlgarveMap(store: store)
            if !store.followed.isEmpty {
                TitledCard("Your towns", kicker: "Following") {
                    ForEach(store.followed, id: \.self) { id in
                        if let info = PlaceDirectory.info(id) { TownRow(info: info, site: store.site(id)) }
                    }
                }
            }
            Columns {
                TitledCard("The latest from the towns", kicker: "Local AI news") {
                    let latest = store.latestFromTowns(limit: 10)
                    if latest.isEmpty {
                        Text("No stories yet.").font(.footnote).foregroundStyle(Palette.muted)
                    }
                    ForEach(latest) { item in StoryRow(story: item.story, town: item.town.name) }
                }
            } trailing: {
                TitledCard("The towns", kicker: "\(store.liveTownCount) live · \(PlaceDirectory.towns.count - store.liveTownCount) researching") {
                    ForEach(sortedTowns) { info in TownRow(info: info, site: store.site(info.id)) }
                }
            }
            if let region = store.region, !region.aiNews.isEmpty {
                TitledCard("Across the region", kicker: "The Algarve") {
                    ForEach(region.aiNews.prefix(8)) { story in StoryRow(story: story, town: nil) }
                }
            }
            NavigationLink {
                NewsroomCentreView()
            } label: {
                Card {
                    Label("The newsroom behind it", systemImage: "person.3.sequence").font(.headline)
                    Text("One agent per town, and what each is doing now. Read-only.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .buttonStyle(.plain)
            Text("PrompTugal.news is independent. Every fact here links to where it was read. Each town's research is by its own agent.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .navigationTitle("The Algarve")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $algarvio) { Label("Algarvio voice", systemImage: "quote.bubble") }
                    .toggleStyle(.button)
                    .accessibilityHint("Shows the playful local voice the sites offer")
            }
        }
        .task { if !store.placeProvenance.isLive { await store.refreshAll() } }
        .refreshable { await store.refreshAll() }
        .chargesCredit(.town(id: PlaceDirectory.region.id, name: "The Algarve"))
    }

    private var header: some View {
        let region = store.region
        let text = algarvio ? (region?.voice?.mandate ?? region?.mandate) : region?.mandate
        return ScreenHeader(kicker: "PrompTugal.news · by place", title: "The Algarve",
                            summary: text ?? "AI and technology across the Algarve and its 17 towns, every fact sourced.")
    }

    /// Live sites first, then by number of stories.
    private var sortedTowns: [PlaceInfo] {
        PlaceDirectory.towns.sorted { a, b in
            let sa = store.site(a.id), sb = store.site(b.id)
            let la = sa?.isLive == true ? 0 : 1, lb = sb?.isLive == true ? 0 : 1
            if la != lb { return la < lb }
            let na = sa?.aiNews.count ?? 0, nb = sb?.aiNews.count ?? 0
            if na != nb { return na > nb }
            return a.name < b.name
        }
    }
}

// MARK: - The map

/// The 17 places, each in its site's own accent: a filled dot is a live site, a ring one still being researched.
struct AlgarveMap: View {
    let store: LocalStore
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.21, longitude: -8.15),
        span: MKCoordinateSpan(latitudeDelta: 0.75, longitudeDelta: 1.75)))
    @State private var selected: String?

    var body: some View {
        Card(padding: 0) {
            Map(position: $position, selection: $selected) {
                ForEach(PlaceDirectory.towns) { info in
                    let site = store.site(info.id)
                    Annotation(info.name, coordinate: info.coordinate) {
                        PlaceDot(accent: Color(hex: site?.look?.accent), live: site?.isLive == true,
                                 stories: site?.aiNews.count ?? 0)
                    }
                    .tag(info.id)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
            .accessibilityLabel("Map of the 17 places in the Algarve")
        }
        .navigationDestination(item: $selected) { id in TownView(id: id) }
    }
}

struct PlaceDot: View {
    let accent: Color
    let live: Bool
    let stories: Int

    var body: some View {
        ZStack {
            Circle().fill(live ? accent : Palette.card)
            Circle().strokeBorder(accent, lineWidth: 3)
            if stories > 0 {
                Text("\(stories)").font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(live ? Color.white : Palette.ink)
            }
        }
        .frame(width: 26, height: 26)
        .shadow(radius: 1.5)
        .accessibilityLabel("\(live ? "Live" : "Researching"), \(stories) stories")
    }
}

// MARK: - Rows

struct TownRow: View {
    let info: PlaceInfo
    let site: PlaceSite?

    var body: some View {
        NavigationLink {
            TownView(id: info.id)
        } label: {
            HStack(spacing: Space.m) {
                PlaceDot(accent: Color(hex: site?.look?.accent), live: site?.isLive == true, stories: 0)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name).font(.body.weight(.medium)).foregroundStyle(Palette.ink)
                    if let landmark = site?.look?.landmark {
                        Text(landmark).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: Space.s)
                VStack(alignment: .trailing, spacing: 2) {
                    StatusChip(live: site?.isLive == true)
                    Text("\(site?.aiNews.count ?? 0) stories · \(site?.aiMap.count ?? 0) mapped")
                        .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StatusChip: View {
    let live: Bool
    var body: some View {
        Text(live ? "Live" : "Researching")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(live ? Palette.green : Palette.amber)
            .background((live ? Palette.green : Palette.amber).opacity(0.12), in: Capsule())
    }
}

/// A story: the source's headline opens the source itself; the AI path says why it is here.
struct StoryRow: View {
    let story: PlaceSite.News
    let town: String?
    @Environment(\.openURL) private var openURL

    /// What opening this story costs (the site's `story` price by its date), charged when the source opens.
    private var creditKind: CreditKind { .story(url: story.url, title: story.title, date: story.date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let town { Kicker(town) }
            if let url = story.sourceURL {
                Button {
                    LocalCredit.shared.charge(kind: creditKind)
                    openURL(url)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(story.title).font(Typo.story).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(Palette.muted)
                        CostTag(creditKind)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(story.title).font(Typo.story).foregroundStyle(Palette.ink)
            }
            if let summary = story.summary {
                Text(summary).font(.footnote).foregroundStyle(Palette.muted).lineLimit(4)
            }
            HStack(spacing: Space.s) {
                Text([story.publisher, story.date].compactMap { $0 }.joined(separator: ", "))
                if let steps = story.stepsLabel { Text("AI path: \(steps)").foregroundStyle(Palette.blue) }
            }
            .font(.caption)
            .foregroundStyle(Palette.muted)
            if let path = story.aiPath {
                Text(path).font(.caption).italic().foregroundStyle(Palette.muted).lineLimit(3)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Provenance and simulation

/// Says where the screen's data came from: live, this device's copy, or the copy built into the app.
public struct ProvenanceLabel: View {
    let provenance: Provenance
    let phase: LoadPhase

    public init(provenance: Provenance, phase: LoadPhase) {
        self.provenance = provenance
        self.phase = phase
    }

    public var body: some View {
        HStack(spacing: 6) {
            if phase == .loading { ProgressView().controlSize(.mini) }
            Image(systemName: icon)
            Text(provenance.label)
            if case .live(let date) = provenance {
                Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
            }
            if case .cached(let date?) = provenance {
                Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
            }
        }
        .font(.caption)
        .foregroundStyle(provenance.isLive ? Palette.muted : Palette.amber)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch provenance {
        case .live: "dot.radiowaves.left.and.right"
        case .cached: "wifi.slash"
        case .snapshot: "shippingbox"
        case .none: "questionmark.circle"
        }
    }
}

/// Marks anything not read from a real source. Every simulated row or number carries one.
public struct SimulatedBadge: View {
    public init() {}
    public var body: some View {
        Label("Simulated", systemImage: "wand.and.stars")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(Palette.series(4))
            .background(Palette.series(4).opacity(0.14), in: Capsule())
            .accessibilityLabel("Simulated, not real data")
    }
}
