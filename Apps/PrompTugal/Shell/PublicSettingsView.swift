import PTAgenda
import PTCore
import SwiftUI

/// More: reminders, the welcome screen again, version, links, the independence note. The debug switch exists only in DEBUG builds.
struct PublicSettingsView: View {
    #if DEBUG
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    #endif

    @State private var showHow = false
    @Environment(\.openDestination) private var open

    var body: some View {
        Form {
            StandSection()
            Section {
                NavigationLink {
                    ReminderSettingsView()
                } label: {
                    Label("Reminders", systemImage: "bell.badge")
                }
                Button { showHow = true } label: {
                    Label("Show the welcome again", systemImage: "questionmark.circle")
                }
            }
            Section {
                PickCalendarToggle()
            } footer: {
                Text("The app adds talks and never reads your calendar. Taking a pick off leaves its event in the calendar.")
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
        .navigationTitle("More")
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

/// Round 4 of the redesign: where to meet RiskMandate at the summit. The stand line is the one Dinis approved.
struct StandSection: View {
    static let site = URL(string: "https://riskmandate.ai")!

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Meet RiskMandate").font(Typo.headline).foregroundStyle(Palette.ink)
                Text("Thursday 12 November, booth A1-30, ALPHA 1, Pavilion 1")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .combine)
            Link(destination: Self.site) {
                Label("riskmandate.ai", systemImage: "arrow.up.right.square")
            }
            .accessibilityIdentifier("pt.more.riskmandate")
        } header: {
            Text("At the summit")
        }
    }
}
