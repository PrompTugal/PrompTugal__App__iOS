import PTAgenda
import PTCore
import SwiftUI

/// Settings of the public app: version, links, the independence note. The debug switch exists only in DEBUG builds.
struct PublicSettingsView: View {
    #if DEBUG
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    #endif

    @State private var showHow = false
    @Environment(\.openDestination) private var open

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ReminderSettingsView()
                } label: {
                    Label("Reminders", systemImage: "bell.badge")
                }
                Button { showHow = true } label: {
                    Label("How PrompTugal works", systemImage: "questionmark.circle")
                }
            }
            Section {
                LabeledContent("Version") {
                    versionText
                }
                Link("PrompTugal.news", destination: FeedClient.site)
                Link("About this coverage", destination: FeedClient.disclosure)
                Link("Privacy", destination: SupportLinks.privacy)
                Link("Support", destination: SupportLinks.support)
            } header: {
                Text("About")
            } footer: {
                Text(SupportLinks.independence)
                    .accessibilityIdentifier("pt.notAffiliated")
            }
            #if DEBUG
            Section {
                Toggle("Debug mode", isOn: $debug)
            } footer: {
                Text("Debug builds only. Shows the Debug screen and a native, web or hybrid badge on every screen.")
            }
            #endif
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showHow) {
            OnboardingView { chooseTalks in
                showHow = false
                if chooseTalks { open("explore") }
            }
        }
    }

    @ViewBuilder private var versionText: some View {
        let text = Text("\(BuildInfo.current.appVersion) (\(BuildInfo.current.appBuild)) · \(BuildInfo.current.shortCommit)")
            .monospacedDigit()
        #if DEBUG
        text
            .onTapGesture(count: 3) { debug.toggle() }
            .accessibilityHint("Triple tap to toggle debug mode")
        #else
        text
        #endif
    }
}
