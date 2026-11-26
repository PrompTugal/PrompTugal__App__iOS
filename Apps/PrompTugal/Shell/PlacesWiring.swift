import PTCore
import PTLocal
import PTPlaces
import PTTalk
import SwiftUI

/// Wires conductor.a.ios@'s PTLocal layers into ios.places@'s PTPlaces screens through PTPlaces' public hooks
/// (PlacesHooks.swift, PlacesCredit.swift), so neither package imports the other. Only the app shell knows both.
@MainActor
enum PlacesWiring {
    /// Reading credit for the places reader: PTPlaces charges plain strings, PTLocal keeps the ledger. Never gates content.
    static func start() {
        PlacesCredit.charge = { action, ref, date, title in
            LocalCredit.shared.charge(action: action, ref: ref, date: date, title: title)
        }
        // No price chips on stories in this App Store version (25 Nov): nothing can be bought yet, so nothing shows a price.
        PlacesCredit.costText = { _, _, _ in nil }
    }
}

/// The places home's extra section: the newsroom in action, the persona and its reordered stories, then near me.
struct PlacesHomeLayers: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            // The sites behind the towns' news and numbers (Dinis, 25 Nov): a card that opens Data sources.
            DataSourcesCard()
            NewsroomLiveSection()
            PersonaBanner()
            PersonaForYouCard()
            NearMeView()
        }
    }
}

/// A place page's extra section: IPMA conditions, the town's newsroom live, and the on-device summary when this
/// device has the town's by-place file.
struct PlaceLayers: View {
    let placeID: String
    @State private var store = LocalStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            TownNewsroomLive(placeID: placeID)
            // Events and open council notices for the town (data.promptugal.news, civic.promptugal.news), hidden when empty.
            TownLayers(placeID: placeID)
            if let site = store.site(placeID) {
                TownSummaryCard(site: site)
            }
        }
    }
}

/// The Algarve page's map: appdev.live@'s styled map (Map, 3D flight, Grid, Cartogram) in place of PTPlaces' satellite
/// map. The towns come from PTLocal's store (built-in snapshot, then live) and the newsroom dashboard for each agent's
/// last sign of life; a tap pushes that town's page through PTPlaces' `open`.
struct RegionMapLayer: View {
    let open: (String) -> Void
    @State private var store = LocalStore.shared

    var body: some View {
        AlgarveStyledMap(towns: AlgarveMapTown.fromLocalStore(store)) { id in open(id) }
    }
}

/// PTTalk's transport already has PlacesTalk's two methods (send(_:signedBy:), replies(for:)): this is the whole adapter.
extension TalkTransport: @retroactive PlacesTalk {}

extension View {
    /// Set once above every navigation stack (PrompTugalApp), so pushed place pages and sheets inherit the hooks.
    func placesLayers() -> some View {
        placesHomeAccessory { AnyView(PlacesHomeLayers()) }
            .placeAccessory { id in AnyView(PlaceLayers(placeID: id)) }
            .placesRegionMap { open in AnyView(RegionMapLayer(open: open)) }
            // Place comments go to the conductor's lane through PTTalk; without a pasted lane link they say so.
            .placesTalk(TalkTransport.conductor)
            // Comments and sign-in hidden in this App Store version (Dinis, 25 Nov): a reviewer cannot hold a person key
            // or a lane link, and the privacy answer stays "Data Not Collected". Back behind an owner unlock later.
            .placesComments(false)
            // PTTalk's composers sign with the person key PTPlaces' sign-in keeps (read from the Keychain, off the main actor).
            .talkSigning { try? PersonKeychain.load()?.signingKey() }
    }
}
