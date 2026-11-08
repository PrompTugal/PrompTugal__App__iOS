import PTAgenda
import PTAsk
import PTCore
import SwiftUI

/// Settings of the public app: version, links, the independence note. The debug switch exists only in DEBUG builds.
struct PublicSettingsView: View {
    #if DEBUG
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    #endif

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    AskView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Ask about the summit", systemImage: "sparkles")
                        Text("With your own AI key").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                NavigationLink {
                    ReminderSettingsView()
                } label: {
                    Label("Reminders", systemImage: "bell.badge")
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
