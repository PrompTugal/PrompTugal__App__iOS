import PTCore
import SwiftUI

/// "Ask and summarise": Apple Intelligence on this device over PrompTugal.news by place, persona mode and Near me, on
/// one screen so they demo on their own. Reached from More. The pieces are public, for the Places reader to host later.
public struct AskAndSummariseView: View {
    @State private var store = LocalStore.shared
    @State private var personas = PersonaStore.shared
    @State private var locator = NearMeLocator.shared
    @State private var chosen: String?
    @State private var status = LocalModel.status

    public init() {}

    /// The town to summarise: the reader's choice, else the one near them, else the first they follow, else Faro.
    private var townID: String { chosen ?? locator.townID ?? store.followed.first ?? "faro" }

    public var body: some View {
        Page(maxWidth: 900) {
            ScreenHeader(kicker: "PrompTugal.news · on this device", title: "Ask and summarise",
                         summary: "Apple Intelligence reads the Algarve's town pages on your device: a town in one paragraph, a story in two sentences, why a story is about AI. Tell it who you are and the news reorders for you.")
            modelCard
            HStack(spacing: 6) {
                if store.phase == .loading { ProgressView().controlSize(.mini) }
                Image(systemName: store.placeProvenance.isLive ? "dot.radiowaves.left.and.right" : "shippingbox")
                Text(store.placeProvenance.label)
            }
            .font(.caption)
            .foregroundStyle(store.placeProvenance.isLive ? Palette.muted : Palette.amber)

            PersonaBanner()
            PersonaForYouCard(store: store)
            NearMeView(store: store)
            townSection
        }
        .background(Palette.paper)
        .navigationTitle("Ask and summarise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { PersonaToolbarButton() } }
        .task { if !store.placeProvenance.isLive { await store.refreshPlaces() } }
        .refreshable { await store.refreshPlaces() }
        .onAppear { status = LocalModel.status }
    }

    private var modelCard: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: status.isAvailable ? "sparkles" : "iphone.slash")
                .font(.title2)
                .foregroundStyle(status.isAvailable ? Palette.blue : Palette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.isAvailable ? "Apple Intelligence: on this device" : "Apple Intelligence: not available on this device")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(status.isAvailable
                     ? "Every answer here is generated on the device from the page's own facts, and nothing is sent anywhere. It can be wrong: each story links to its source."
                     : "\(status.text) Persona mode and Near me still work: the ranking is keywords on the device, no model needed.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
    }

    @ViewBuilder
    private var townSection: some View {
        let info = PlaceDirectory.info(townID)
        let site = store.site(townID)
        TitledCard("Summarise a town", kicker: "The 17 places") {
            Picker("Town", selection: Binding(get: { townID }, set: { chosen = $0 })) {
                ForEach(PlaceDirectory.towns.sorted { $0.name < $1.name }) { town in Text(town.name).tag(town.id) }
            }
            .pickerStyle(.menu)
            if let info { AITownHeader(info: info, site: site) }
            if site == nil {
                Text("This town's page has not loaded yet.").font(.footnote).foregroundStyle(Palette.muted)
            }
        }
        if let site {
            TownSummaryCard(site: site)
            let stories = PersonaRanker.order(site.aiNews) { personas.match($0).score }
            TitledCard("Its stories", kicker: personas.isOn ? "For you first" : "\(site.aiNews.count) local AI stories") {
                if stories.isEmpty {
                    Text("No local AI stories yet: \(site.name)'s agent is still researching.").font(.footnote).foregroundStyle(Palette.muted)
                }
                ForEach(stories) { story in
                    AIStoryRow(story: story, town: nil, match: personas.match(story), townForAI: site.name)
                    if story != stories.last { Divider() }
                }
            }
            if !site.aiMap.isEmpty {
                let entries = PersonaRanker.order(site.aiMap) { personas.match($0).score }
                TitledCard("Its AI map", kicker: "\(site.aiMap.count) organisations") {
                    ForEach(entries.prefix(personas.isOn ? 12 : 6)) { entry in
                        AIEntryRow(entry: entry, match: personas.match(entry))
                    }
                }
            }
        }
    }
}
