import SwiftUI

/// Settings: who I am on the team, debug mode, and about.
/// A triple tap on the version also turns debug mode on (contract §8).
struct SettingsView: View {
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""
    @AppStorage(DebugMode.key) private var debug = false

    var body: some View {
        Form {
            Section {
                Picker("I am", selection: $me) {
                    Text("Not on the team").tag("")
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

            Section("About") {
                LabeledContent("Version") {
                    Text(BuildInfo.versionLine)
                        .monospacedDigit()
                        .onTapGesture(count: 3) { debug.toggle() }
                        .accessibilityHint("Triple tap to toggle debug mode")
                }
                Link("PrompTugal.news", destination: FeedClient.site)
                Link("About this coverage", destination: FeedClient.disclosure)
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

/// App version, build and the git commit if the build stamps one (platform owns the stamp).
enum BuildInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
    /// Set by the platform session's build step as `PTGitCommit` in Info.plist, when it exists.
    static var commit: String? { Bundle.main.object(forInfoDictionaryKey: "PTGitCommit") as? String }
    static var versionLine: String { "\(version) (\(build))" + (commit.map { " · \($0.prefix(7))" } ?? "") }
}
