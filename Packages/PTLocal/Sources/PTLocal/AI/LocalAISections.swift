import PTCore
import SwiftUI

// Public sections for other screens to host, so the app's one Places reader (PTPlaces, ios.places@) shows Apple
// Intelligence, persona mode and Near me without editing it. Wire them in the app shell:
//
//   PlacesHomeView()
//       .placesHomeAccessory { AnyView(LocalAIHomeSection()) }
//       .placeAccessory { id in AnyView(LocalAIPlaceSection(placeID: id)) }
//
// Both read PTLocal's own copy of the by-place JSON (LocalStore: built-in snapshot, this device's copy, then live).

/// For a places home: the persona header (pick or type who you are), Near me (the nearest town's news first) and,
/// in persona mode, what matters to the persona across the Algarve, with an on-device briefing.
public struct LocalAIHomeSection: View {
    @State private var store = LocalStore.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            PersonaBanner()
            NearMeCard(store: store)
            PersonaForYouCard(store: store)
        }
        .task { if !store.placeProvenance.isLive { await store.refreshPlaces() } }
    }
}

/// For a place page: the town in one paragraph from Apple Intelligence on this device and, in persona mode, the
/// town's stories and organisations that matter to the persona, best first.
public struct LocalAIPlaceSection: View {
    public let placeID: String
    @State private var store = LocalStore.shared
    @State private var personas = PersonaStore.shared

    public init(placeID: String) { self.placeID = placeID }

    public var body: some View {
        if let site = store.site(placeID) {
            VStack(alignment: .leading, spacing: Space.m) {
                if personas.isOn { PersonaBanner() }
                TownSummaryCard(site: site)
                if personas.isOn, let info = PlaceDirectory.info(placeID) {
                    let stories = PersonaRanker.stories(in: [(info: info, site: site)], terms: personas.terms, limit: 5)
                    let entries = PersonaRanker.entries(in: [(info: info, site: site)], terms: personas.terms, limit: 5)
                    TitledCard("For you in \(site.name)", kicker: personas.persona?.label ?? "Persona") {
                        if stories.isEmpty && entries.isEmpty {
                            Text("Nothing in \(site.name) matches “\(personas.persona?.text ?? "")” yet.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                        ForEach(stories) { item in StoryRow(story: item.story, town: nil, match: item.match, townForAI: site.name) }
                        ForEach(entries) { item in MapEntryRow(entry: item.entry, match: item.match) }
                    }
                }
            }
        }
    }
}
