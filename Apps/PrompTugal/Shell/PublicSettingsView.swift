import PTAgenda
import PTCore
import PTLocal
import PTTalk
import SwiftUI

/// More: reminders, the welcome screen again, version, links, the independence note. The debug switch exists only in DEBUG builds.
struct PublicSettingsView: View {
    #if DEBUG
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    #endif

    @State private var showHow = false
    @AppStorage(Appearance.key) private var appearance = Appearance.light.rawValue
    @Environment(\.openDestination) private var open

    var body: some View {
        Form {
            // Which build this is, first thing in More (on iPad the sidebar header shows it too).
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "PrompTugal.news · the Algarve").font(.subheadline.weight(.semibold))
                    Text(verbatim: AppVersion.label).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("pt.more.version")
                }
                .accessibilityElement(children: .combine)
            }
            Section {
                NavigationLink {
                    DataSourcesView()
                } label: {
                    Label("Data sources", systemImage: "server.rack")
                }
                .accessibilityIdentifier("pt.more.sources")
                NavigationLink {
                    OfflineEditionView()
                } label: {
                    Label("Offline edition", systemImage: "arrow.down.circle")
                }
                .accessibilityIdentifier("pt.more.offline")
                NavigationLink {
                    AlgarveMapsView()
                } label: {
                    Label("Algarve maps", systemImage: "map")
                }
                .accessibilityIdentifier("pt.more.maps")
                NavigationLink {
                    NewsroomCentreView()
                } label: {
                    Label("Newsroom", systemImage: "person.3.sequence")
                }
                .accessibilityIdentifier("pt.more.newsroom")
                NavigationLink {
                    AskAndSummariseView()
                } label: {
                    Label("Ask and summarise", systemImage: "sparkles")
                }
                .accessibilityIdentifier("pt.more.ask")
            } header: {
                Text("PrompTugal.news by place")
            } footer: {
                Text("The agents behind the town sites: what each is doing now, read-only. Ask and summarise: Apple Intelligence on this device, persona mode and the town near you.")
            }
            Section {
                Picker(selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                .accessibilityIdentifier("pt.more.appearance")
            }
            // PTTalk's "Connect to the newsroom" is hidden in this App Store version (Dinis, 25 Nov), like place comments.
            Section {
                LabeledContent("Version") {
                    versionText
                }
                Link("PrompTugal.news", destination: FeedClient.site)
                // Contribute or report a mistake: the site's own page, where a person reads it (no data sent from the app).
                Link("Contribute or report a mistake", destination: URL(string: "https://promptugal.news/contribute/")!)
                Link("About this coverage", destination: FeedClient.disclosure)
                Link("Privacy", destination: SupportLinks.privacy)
                Link("Support", destination: SupportLinks.support)
            } header: {
                Text("About")
            } footer: {
                Text("PrompTugal.news: local news from Portugal. Every story links to its source.")
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

/// Light (the default), Dark, or whatever the iPhone is set to.
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system

    static let key = "appearance"
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Match iPhone"
        }
    }

    /// nil follows the iPhone.
    var scheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
