import PTAgenda
import SwiftUI

/// Explore (ux spec EXP-1). Until PTExplore is linked into this app, Explore shows the agenda's Talks list, which is
/// the spec's fallback: speakers, companies and places follow with PTExplore. `reader.agenda` and `news.graph` links
/// open this screen.
struct ExploreView: View {
    var body: some View {
        AgendaView()
    }
}
