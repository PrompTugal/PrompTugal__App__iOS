import SwiftUI

/// Settings: who I am on the team, debug mode, and about.
/// A triple tap on the version also turns debug mode on (contract §8).
struct SettingsView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn

    var body: some View {
        Form {
            Section {
                Picker("I am", selection: $me) {
                    Text("Not chosen").tag("")
                    Text("Not on the team (reader)").tag(SampleMode.readerID)
                    ForEach(data.team.value?.sortedPeople ?? []) { person in
                        Text(person.displayName).tag(person.id)
                    }
                }
                if let person = data.person(me) {
                    LabeledContent("Role", value: person.role ?? "")
                    LabeledContent("Level", value: person.levelName ?? "")
                }
            } header: {
                Text("Team")
            } footer: {
                Text("Picks the command centre, briefing and counts the app shows you. Read from the team's public data; no key needed.")
            }

            Section {
                Toggle("Debug mode", isOn: $debug)
            } footer: {
                Text("Shows the Debug section, and a native, web or hybrid badge on every screen.")
            }

            Section {
                LabeledContent("Version") {
                    Text("\(BuildInfo.current.appVersion) (\(BuildInfo.current.appBuild)) · \(BuildInfo.current.shortCommit)")
                        .monospacedDigit()
                        .onTapGesture(count: 3) { debug.toggle() }
                        .accessibilityHint("Triple tap to toggle debug mode")
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
        }
        .navigationTitle("Settings")
        .task { await data.refreshTeam() }
    }
}

/// The command centre of the person this device belongs to, on the web.
struct MyCommandCentreWeb: View {
    @AppStorage(DashboardData.meKey) private var me = ""

    var body: some View {
        if me.isEmpty {
            ContentUnavailableView {
                Label("Who are you?", systemImage: "person.crop.circle.badge.questionmark")
            } description: {
                Text("Choose yourself in Settings to open your command centre.")
            }
        } else {
            WebPage(url: TeamSite.base.appendingPathComponent("people/\(me)/app/"), title: "My command centre")
        }
    }
}


/// The app's own privacy and support pages, and its independence note (guideline 5.1.1, 5.2).
enum SupportLinks {
    static let privacy = URL(string: "https://ios.app.promptugal.news/privacy.html")!
    static let support = URL(string: "https://ios.app.promptugal.news/support.html")!
    static let independence = "PrompTugal is independent. It is not affiliated with, endorsed by or sponsored by Web Summit."
}
