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
        PlacesCredit.costText = { action, ref, date in
            LocalCredit.shared.costText(action: action, ref: ref, date: date)
        }
    }
}

/// The places home's extra section: the newsroom in action, then the persona and near me.
struct PlacesHomeLayers: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            NewsroomLiveSection()
            PersonaBanner()
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
            ConditionsCard(placeID: placeID)
            TownNewsroomLive(placeID: placeID)
            if let site = store.site(placeID) {
                TownSummaryCard(site: site)
            }
        }
    }
}

/// PTTalk's transport already has PlacesTalk's two methods (send(_:signedBy:), replies(for:)): this is the whole adapter.
extension TalkTransport: @retroactive PlacesTalk {}

extension View {
    /// Set once above every navigation stack (PrompTugalApp), so pushed place pages and sheets inherit the hooks.
    func placesLayers() -> some View {
        placesHomeAccessory { AnyView(PlacesHomeLayers()) }
            .placeAccessory { id in AnyView(PlaceLayers(placeID: id)) }
            // Place comments go to the conductor's lane through PTTalk; without a pasted lane link they say so.
            .placesTalk(TalkTransport.conductor)
            // PTTalk's composers sign with the person key PTPlaces' sign-in keeps (read from the Keychain, off the main actor).
            .talkSigning { try? PersonKeychain.load()?.signingKey() }
    }
}
