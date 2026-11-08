import SGitVault
import SwiftUI

/// The root view (contract §7). On iPad a sidebar with every section; on iPhone
/// four tabs and a "More" list. Every destination comes from `Destinations`.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SampleMode.key) private var sampleMode = false
    @State private var data = (LaunchOptions.sampleData || UserDefaults.standard.bool(forKey: SampleMode.key))
        ? PreviewSamples.data() : DashboardData()
    /// The vault session's reader logs here; Debug → Vault traffic reads it.
    private var vaultLog: VaultTrafficLog { VaultSession.shared.log }
    @SceneStorage("shell.selection") private var selection: String = "today"
    @SceneStorage("shell.tab") private var tab: String = "today"
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    @State private var columns: NavigationSplitViewVisibility = .all
    /// A page opened by a link (a reminder's session or briefing), shown over the shell.
    @State private var linkedPage: LinkedPage?

    var body: some View {
        Group {
            if width == .compact {
                PhoneShell(tab: $tab, debug: debug)
            } else {
                splitView
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if sampleMode { SampleBanner { leaveSampleMode() } }
        }
        .environment(data)
        .environment(data.news)
        .environment(vaultLog)
        // .teamFeatures() is applied once, by the app root (PrompTugalApp), outside the shell.
        .identitySync()
        .tint(Palette.red)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active, !LaunchOptions.sampleData, !sampleMode { Task { await data.refreshAll() } }
        }
        .onChange(of: sampleMode) { _, on in
            data = on ? PreviewSamples.data() : DashboardData()
            if !on { Task { await data.refreshAll(force: true) } }
        }
        // The app-switcher snapshot is taken while the scene is inactive: cover keys, messages and Ask.
        .overlay {
            if scenePhase != .active { PrivacyCover() }
        }
        .onOpenURL { url in route(url) }
        .sheet(item: $linkedPage) { page in
            NavigationStack {
                WebPage(url: page.url, title: page.title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Done") { linkedPage = nil } }
                    }
            }
        }
        .onAppear {
            if let id = LaunchOptions.destination, let destination = Destinations.openable(id, debug: debug) {
                selection = id
                tab = destination.phoneTab != nil ? id : "more"
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            ShellSidebar(selection: $selection, debug: debug)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let destination = Destinations.openable(selection, debug: debug), destination.ownsNavigation {
                // The screen brings its own columns; the shell's sidebar steps aside (the system
                // sidebar button brings it back).
                destination.view().destinationID(destination.id).id(destination.id)
            } else {
                NavigationStack {
                    if let destination = Destinations.openable(selection, debug: debug) {
                        destination.view().destinationID(destination.id)
                            .id(destination.id)
                            .surfaceKind(destination.kind)
                            // Collab's Ask beside any screen: a toolbar button, ⌘K and a side panel.
                            .askAnywhere(enabled: destination.id != "collab.ai")
                    } else {
                        ContentUnavailableView("Choose a screen", systemImage: "sidebar.left")
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { _, id in
            if Destinations.destination(id)?.ownsNavigation == true { columns = .detailOnly }
        }
        .background(ShellKeyboardShortcuts(selection: $selection))
    }

    /// <scheme>://open/<destination id>, e.g. <scheme>://open/team.people
    private func route(_ url: URL) {
        guard url.scheme == AppLinks.scheme, url.host == "open" else { return }
        let id = url.pathComponents.dropFirst().joined(separator: "/")
        // Debug-only screens (Debug) open from a link only while debug mode is on.
        guard let destination = Destinations.openable(id, debug: debug) else { return }
        selection = id
        tab = destination.phoneTab != nil ? id : "more"
        // A reminder names the session (?session=<slug>) or the stand-up briefing (?url=<page>): open it.
        linkedPage = ShellLink.page(in: url)
    }
}

extension AppShell {
    private func leaveSampleMode() {
        SampleMode.leave()
    }
}

/// A page a link asks to open over the shell.
struct LinkedPage: Identifiable, Equatable {
    let url: URL
    let title: String
    var id: URL { url }
}

/// Reads the page out of a <scheme>://open/<id> link: `session=<event slug>` becomes that event's
/// page on promptugal.news; `url=<https page>` is opened only on our own two sites.
enum ShellLink {
    static let allowedHosts: Set<String> = ["promptugal.news", "web-summit.sgit.ai"]

    static func page(in link: URL) -> LinkedPage? {
        let items = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let slug = items.first(where: { $0.name == "session" })?.value,
           !slug.isEmpty, slug.range(of: #"^[a-z0-9][a-z0-9-]*$"#, options: .regularExpression) != nil {
            return LinkedPage(url: FeedClient.site.appendingPathComponent("events/\(slug)/index.html"), title: "Session")
        }
        if let text = items.first(where: { $0.name == "url" })?.value, let url = URL(string: text),
           url.scheme == "https", let host = url.host()?.lowercased(), allowedHosts.contains(host),
           !CheckoutPolicy.isBlocked(url) {
            return LinkedPage(url: url, title: "Briefing")
        }
        return nil
    }
}

/// The banner shown on every screen while sample data is on.
private struct SampleBanner: View {
    let leave: () -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "theatermasks").foregroundStyle(Palette.amber).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Sample data").font(.subheadline.weight(.semibold))
                Text("Made-up people and agents, so you can see every screen.").font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: Space.s)
            Button("Leave", action: leave)
                .buttonStyle(.bordered)
                .accessibilityLabel("Leave sample data")
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(Palette.amber.opacity(0.15))
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pt.sampleBanner")
    }
}

/// Covers the app while it is not active, so the app-switcher snapshot shows no keys, messages or chats.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: Space.m) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.ink)
                    .frame(width: 64, height: 64)
                    .overlay(Text("PT").font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(Palette.paper))
                Text("PrompTugal").font(Typo.title)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - iPad sidebar

private struct ShellSidebar: View {
    @Binding var selection: String
    let debug: Bool
    @Environment(DashboardData.self) private var data
    @AppStorage(DashboardData.meKey) private var me = ""

    var body: some View {
        List(selection: Binding<String?>(get: { selection }, set: { if let id = $0 { selection = id } })) {
            Section {
                SidebarHeader()
            }
            ForEach(ShellSection.allCases) { section in
                let rows = Destinations.section(section).filter { debug || !$0.debugOnly }
                if !rows.isEmpty {
                    Section(section.rawValue) {
                        ForEach(rows) { destination in
                            SidebarRow(destination: destination, badge: badge(for: destination), debug: debug)
                                .tag(destination.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PrompTugal")
    }

    private func badge(for destination: AppDestination) -> Int? {
        switch destination.id {
        case "today": data.person(me)?.attention
        case "briefed": data.person(me)?.decide
        case "news.newsroom": data.decisions.value?.decisions?.filter(\.isOpen).count
        default: nil
        }
    }
}

private struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: Space.m) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Palette.ink)
                .frame(width: 30, height: 30)
                .overlay(Text("PT").font(.system(.caption, design: .serif, weight: .bold)).foregroundStyle(Palette.paper))
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(Palette.red).frame(width: 8, height: 8).offset(x: 2, y: 2)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Kicker("PrompTugal")
                Text("Lisbon · 9–12 Nov").font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SidebarRow: View {
    let destination: AppDestination
    let badge: Int?
    let debug: Bool

    var body: some View {
        Label {
            HStack {
                Text(destination.title)
                Spacer(minLength: 4)
                if debug {
                    // Shape and colour, plus text for VoiceOver: not colour alone.
                    Image(systemName: destination.kind.symbol)
                        .font(.caption2)
                        .foregroundStyle(destination.kind.color)
                        .accessibilityLabel(destination.kind.label)
                        .help(destination.kind.label)
                }
            }
        } icon: {
            Image(systemName: destination.symbol)
        }
        .badge(badge ?? 0)
        .help(destination.summary)
    }
}

// MARK: - iPhone tabs and More

private struct PhoneShell: View {
    @Binding var tab: String
    let debug: Bool

    private var tabs: [AppDestination] {
        Destinations.all.filter { $0.phoneTab != nil }.sorted { ($0.phoneTab ?? 0) < ($1.phoneTab ?? 0) }
    }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(tabs) { destination in
                Tab(destination.tabTitle ?? destination.title, systemImage: destination.symbol, value: destination.id) {
                    NavigationStack {
                        destination.view().destinationID(destination.id).surfaceKind(destination.kind)
                    }
                }
            }
            Tab("More", systemImage: "ellipsis.circle", value: "more") {
                NavigationStack { MoreList(debug: debug) }
            }
        }
    }
}

private struct MoreList: View {
    let debug: Bool
    @State private var fullScreen: String? = LaunchOptions.launchedMoreDestination(ownsNavigation: true)?.id
    /// A screen opened by -PTDestination that lives under More (for screenshots and UI tests).
    @State private var launched = LaunchOptions.launchedMoreDestination(ownsNavigation: false) != nil

    var body: some View {
        List {
            ForEach(ShellSection.allCases) { section in
                let rows = Destinations.section(section).filter { $0.phoneTab == nil && (debug || !$0.debugOnly) }
                if !rows.isEmpty {
                    Section(section.rawValue) {
                        ForEach(rows) { destination in
                            if destination.ownsNavigation {
                                Button { fullScreen = destination.id } label: { MoreRow(destination: destination) }
                                    .foregroundStyle(Palette.ink)
                            } else {
                                NavigationLink {
                                    destination.view().destinationID(destination.id).surfaceKind(destination.kind)
                                } label: {
                                    MoreRow(destination: destination)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("More")
        .navigationDestination(isPresented: $launched) {
            if let destination = LaunchOptions.launchedMoreDestination(ownsNavigation: false) {
                destination.view().destinationID(destination.id).surfaceKind(destination.kind)
            }
        }
        .fullScreenCover(item: Binding(get: { fullScreen.map(FullScreenID.init) }, set: { fullScreen = $0?.id })) { item in
            if let destination = Destinations.destination(item.id) {
                destination.view().destinationID(destination.id)
                    .overlay(alignment: .topTrailing) {
                        Button { fullScreen = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                        }
                        .padding(Space.m)
                        .accessibilityLabel("Close \(destination.title)")
                    }
            }
        }
    }
}

private struct FullScreenID: Identifiable { let id: String }

private struct MoreRow: View {
    let destination: AppDestination

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.title)
                if !destination.summary.isEmpty {
                    Text(destination.summary).font(.caption).foregroundStyle(Palette.muted)
                }
            }
        } icon: {
            Image(systemName: destination.symbol)
        }
    }
}

// MARK: - Keyboard shortcuts (iPad with a keyboard)

/// ⌘1–⌘9 jump to the first screen of each section; ⌘, opens Settings; ⌘⇧D opens Debug.
private struct ShellKeyboardShortcuts: View {
    @Binding var selection: String
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn

    var body: some View {
        let sections = ShellSection.allCases.filter { $0 != .settings && $0 != .debug }
        ZStack {
            ForEach(Array(sections.prefix(9).enumerated()), id: \.offset) { index, section in
                if let first = Destinations.section(section).first {
                    Button(section.rawValue) { selection = first.id }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            Button("Settings") { selection = "settings" }.keyboardShortcut(",", modifiers: .command)
            Button("Debug") { debug = true; selection = "debug" }.keyboardShortcut("d", modifiers: [.command, .shift])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

#Preview("Shell · iPhone") {
    AppShell().environment(ReaderStore()).teamFeatures().phonePreview()
}

#Preview("Shell · iPad") {
    AppShell().environment(ReaderStore()).teamFeatures().padPreview()
}

extension View {
    /// Marks the screen the shell opened, for UI tests and screenshots: "pt.destination.<id>".
    func destinationID(_ id: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier("pt.destination.\(id)")
    }
}
