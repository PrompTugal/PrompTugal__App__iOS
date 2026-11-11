import SwiftUI
import PTAgenda
import PTCore
import PTFringe

/// About with the independence line, Join the team, and Submit an event (both open the web).
struct MoreView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(FringeText.independence)
                    Button("The organisers' official site") { openURL(FringeText.officialSite) }
                } header: { Text("About Lisbon Fringe") } footer: {
                    Text("Events come from public pages, each with its source and the time it was read. Unknown means unknown, not a guess. The app collects no data about you: no account, no analytics, no tracking.")
                }
                Section("Join in") {
                    Button("Join the team") { openURL(FringeText.join) }
                    Button("Submit an event") { openURL(FringeText.submit) }
                    Button("fringe.promptugal.news") { openURL(FringeText.site) }
                }
                Section("The storm") {
                    Button("IPMA") { openURL(FringeText.ipma) }
                    Button("ANEPC") { openURL(FringeText.anepc) }
                    Button("Storm Charles site") { openURL(FringeText.stormSite) }
                }
                Section {
                    Text("\(BuildInfo.current.appVersion) (\(BuildInfo.current.appBuild))").font(Typo.data).foregroundStyle(Palette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("More")
        }
    }
}
