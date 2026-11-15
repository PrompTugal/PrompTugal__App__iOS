import PTCore
import SwiftUI

/// One town's site, native: its mandate and centre of gravity, its local AI news, events and AI map, what it does not
/// know yet, its sources, and the agent that keeps it. Follow it to see it first.
public struct TownView: View {
    public let id: String
    @State private var store = LocalStore.shared
    @State private var personas = PersonaStore.shared
    @AppStorage("local.voice") private var algarvio = false

    public init(id: String) { self.id = id }

    private var info: PlaceInfo? { PlaceDirectory.info(id) }
    private var site: PlaceSite? { store.site(id) }

    public var body: some View {
        Page(maxWidth: 900) {
            if let site {
                content(site)
            } else {
                StateView(phase: store.phase, hasData: false, title: info?.name ?? "this place") {
                    Task { await store.refreshPlaces() }
                }
            }
        }
        .navigationTitle(info?.name ?? site?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.toggleFollow(id)
                } label: {
                    Label(store.isFollowed(id) ? "Following" : "Follow",
                          systemImage: store.isFollowed(id) ? "star.fill" : "star")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                if let page = info?.page {
                    ShareLink(item: page) { Label("Share the site", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .refreshable { await store.refreshAll() }
        .task { if store.dashboard == nil { await store.refreshDashboard() } }
    }

    @ViewBuilder
    private func content(_ site: PlaceSite) -> some View {
        let accent = Color(hex: site.look?.accent)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Kicker("PrompTugal.news · \(site.name)", color: accent)
                StatusChip(live: site.isLive)
            }
            Text(site.name).font(Typo.display).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            if let landmark = site.look?.landmark {
                Text(landmark).font(.subheadline).foregroundStyle(Palette.muted)
            }
            Text(algarvio ? (site.voice?.lede ?? site.mandate) : site.mandate)
                .font(.callout).foregroundStyle(Palette.ink)
            Toggle("Algarvio voice", isOn: $algarvio).font(.caption).tint(accent).fixedSize()
        }
        .padding(.bottom, Space.xs)
        .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 4).offset(x: -Space.m) }

        if personas.isOn { PersonaBanner() }
        ProvenanceLabel(provenance: store.placeProvenance, phase: store.phase)
        Text("Updated \(site.updated) by \(site.by)").font(.caption.monospaced()).foregroundStyle(Palette.muted)

        TownSummaryCard(site: site)

        if let text = algarvio ? (site.voice?.gravity ?? site.gravity?.text) : site.gravity?.text {
            TitledCard("The centre of gravity", kicker: site.name) {
                Text(text).font(.callout)
                SourceLinks(links: site.gravity?.sources ?? [])
            }
        }

        TitledCard("AI in \(site.name)", kicker: "\(site.aiNews.count) local stories") {
            if site.aiNews.isEmpty {
                Text("No local AI stories yet: the town's agent is still researching.").font(.footnote).foregroundStyle(Palette.muted)
            }
            let stories = PersonaRanker.order(site.aiNews) { personas.match($0).score }
            ForEach(stories) { story in
                StoryRow(story: story, town: nil, match: personas.match(story), townForAI: site.name)
                if story != stories.last { Divider() }
            }
        }

        if !site.events.isEmpty {
            TitledCard("Events", kicker: "\(site.events.count)") {
                ForEach(site.events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        if let link = event.link {
                            Link(event.title, destination: link).font(.body.weight(.medium))
                        } else {
                            Text(event.title).font(.body.weight(.medium))
                        }
                        if let date = event.date { Text(date).font(.caption).foregroundStyle(Palette.muted) }
                        if let path = event.aiPath { Text(path).font(.caption).italic().foregroundStyle(Palette.muted).lineLimit(3) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }

        TitledCard("The AI map", kicker: "\(site.aiMap.count) organisations") {
            Text("The companies, institutions and communities with a path to AI, each from a public source.")
                .font(.footnote).foregroundStyle(Palette.muted)
            ForEach(PersonaRanker.order(site.aiMap) { personas.match($0).score }) { entry in
                MapEntryRow(entry: entry, match: personas.match(entry))
            }
        }

        TownAgentCard(placeID: id, dashboard: store.dashboard, provenance: store.dashboardProvenance)

        if !site.gaps.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                if algarvio, let intro = site.voice?.gapsIntro {
                    Text(intro).font(.footnote).italic()
                }
                ForEach(Array(site.gaps.enumerated()), id: \.offset) { _, gap in
                    GapNote(title: "Not known yet", text: gap)
                }
            }
        }

        if !site.sources.isEmpty {
            TitledCard("Where the agent reads", kicker: "\(site.sources.count) sources") {
                ForEach(site.sources) { source in
                    HStack {
                        if let link = source.link { Link(source.name, destination: link) } else { Text(source.name) }
                        Spacer()
                        if let kind = source.kind { Text(kind).font(.caption).foregroundStyle(Palette.muted) }
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

struct SourceLinks: View {
    let links: [PlaceSite.Link]
    var body: some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sources").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                ForEach(links, id: \.url) { link in
                    if let url = PlaceSite.safeURL(link.url) {
                        Link(destination: url) {
                            Text(link.title ?? url.host() ?? link.url).font(.caption).multilineTextAlignment(.leading)
                        }
                    }
                }
            }
        }
    }
}

struct MapEntryRow: View {
    let entry: PlaceSite.MapEntry
    /// In persona mode, how the organisation fits the persona.
    var match: PersonaMatch = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            PersonaMatchChip(match: match)
            HStack(alignment: .firstTextBaseline) {
                if let home = entry.home {
                    Link(entry.name, destination: home).font(.body.weight(.semibold))
                } else {
                    Text(entry.name).font(.body.weight(.semibold))
                }
                Spacer(minLength: Space.s)
                if let type = entry.type { Text(type).font(.caption2).foregroundStyle(Palette.muted) }
            }
            if let what = entry.what { Text(what).font(.footnote).foregroundStyle(Palette.ink).lineLimit(5) }
            if let path = entry.aiPath { Text("AI path: \(path)").font(.caption).foregroundStyle(Palette.blue).lineLimit(3) }
            HStack(spacing: 4) {
                Image(systemName: "link")
                if let source = entry.source {
                    Link(entry.sourceHost, destination: source)
                } else {
                    Text(entry.sourceHost)
                }
                if let read = entry.readOn { Text("· read \(read)") }
            }
            .font(.caption2)
            .foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 4)
    }
}

/// The agent that keeps the town's site: what it says it is doing, its next steps and what it asks for, from the
/// newsroom dashboard. Read-only.
struct TownAgentCard: View {
    let placeID: String
    let dashboard: NewsroomDashboard?
    let provenance: Provenance

    var body: some View {
        let agent = dashboard?.agent(forPlace: placeID)
        TitledCard("The town's agent", kicker: "Newsroom") {
            if let agent {
                AgentSummary(agent: agent)
                ProvenanceLabel(provenance: provenance, phase: .idle)
            } else if dashboard == nil {
                Text("Loading the newsroom dashboard…").font(.footnote).foregroundStyle(Palette.muted)
            } else {
                Text("place.\(placeID)@PrompTugal.dinis is not on the newsroom dashboard yet.")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
        }
    }
}
