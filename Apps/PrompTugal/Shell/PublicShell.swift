import PTAgenda
import PTAsk
import PTCore
import PTNews
import PTWeb
import SwiftUI

/// Root view of the public app. On iPad a sidebar with every group; on iPhone tabs and a "More" list.
/// Every screen comes from `PublicDestinations`. No team names, no lanes, no sample data, and no debug
/// screen in a Release build.
struct PublicShell: View {
    // Created in this order: the features register the hubs the reader store reads.
    @State private var features = PublicFeatures.shared
    @State private var reader = ReaderStore()
    @State private var newsFeeds = NewsFeeds()

    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("shell.selection") private var selection = "reader.agenda"
    @SceneStorage("shell.tab") private var tab = "reader.agenda"
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    @State private var columns: NavigationSplitViewVisibility = .all
    /// A page opened by a link (a reminder's session), shown over the shell.
    @State private var linkedPage: LinkedPage?

    var body: some View {
        Group {
            if width == .compact {
                PublicPhoneShell(tab: $tab, debug: debug)
            } else {
                splitView
            }
        }
        .environment(reader)
        .environment(\.newsSource, reader)
        .environment(newsFeeds)
        .publicFeatures(features)
        .tint(Palette.red)
        .task { await reader.refresh() }
        // The app-switcher snapshot is taken while the scene is inactive: cover keys and picks.
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
            if let id = PublicLaunch.destination, let destination = PublicDestinations.openable(id, debug: debug) {
                selection = id
                tab = destination.phoneTab != nil ? id : "more"
            }
        }
        .accessibilityIdentifier("public-shell")
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            PublicSidebar(selection: $selection, debug: debug)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let destination = PublicDestinations.openable(selection, debug: debug), destination.ownsNavigation {
                // The screen brings its own columns; the sidebar steps aside (the system button brings it back).
                destination.view().destinationID(destination.id).id(destination.id)
            } else {
                NavigationStack {
                    if let destination = PublicDestinations.openable(selection, debug: debug) {
                        destination.view().destinationID(destination.id)
                            .id(destination.id)
                            .surfaceKind(destination.kind)
                            // Ask beside any screen: a toolbar button, ⌘K and a side panel.
                            .askAnywhere(enabled: destination.id != "collab.ai")
                    } else {
                        ContentUnavailableView("Choose a screen", systemImage: "sidebar.left")
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { _, id in
            if PublicDestinations.destination(id)?.ownsNavigation == true { columns = .detailOnly }
        }
        .background(PublicKeyboardShortcuts(selection: $selection))
    }

    /// <scheme>://open/<destination id>, e.g. <scheme>://open/reader.agenda
    private func route(_ url: URL) {
        guard url.scheme == AppLinks.scheme, url.host == "open" else { return }
        let id = url.pathComponents.dropFirst().joined(separator: "/")
        guard let destination = PublicDestinations.openable(id, debug: debug) else { return }
        selection = id
        tab = destination.phoneTab != nil ? id : "more"
        // A reminder names the session (?session=<slug>): open its page over the shell.
        linkedPage = ShellLink.page(in: url, isBlocked: CheckoutPolicy.isBlocked)
    }
}

// MARK: - iPad sidebar

private struct PublicSidebar: View {
    @Binding var selection: String
    let debug: Bool

    var body: some View {
        List(selection: Binding<String?>(get: { selection }, set: { if let id = $0 { selection = id } })) {
            Section { header }
            ForEach(PublicDestinations.groups, id: \.self) { group in
                let rows = PublicDestinations.group(group).filter { debug || !$0.debugOnly }
                if !rows.isEmpty {
                    Section(group) {
                        ForEach(rows) { destination in
                            ShellSidebarRow(destination: destination, debug: debug).tag(destination.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PrompTugal")
    }

    private var header: some View {
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

// MARK: - iPhone tabs and More

private struct PublicPhoneShell: View {
    @Binding var tab: String
    let debug: Bool

    private var tabs: [ShellDestination] {
        PublicDestinations.all.filter { $0.phoneTab != nil }.sorted { ($0.phoneTab ?? 0) < ($1.phoneTab ?? 0) }
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
                NavigationStack { PublicMoreList(debug: debug) }
            }
        }
    }
}

private struct PublicMoreList: View {
    let debug: Bool
    @State private var fullScreen: String?

    var body: some View {
        List {
            ForEach(PublicDestinations.groups, id: \.self) { group in
                let rows = PublicDestinations.group(group).filter { $0.phoneTab == nil && (debug || !$0.debugOnly) }
                if !rows.isEmpty {
                    Section(group) {
                        ForEach(rows) { destination in
                            if destination.ownsNavigation {
                                Button { fullScreen = destination.id } label: { ShellMoreRow(destination: destination) }
                                    .foregroundStyle(Palette.ink)
                            } else {
                                NavigationLink {
                                    destination.view().destinationID(destination.id).surfaceKind(destination.kind)
                                } label: {
                                    ShellMoreRow(destination: destination)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("More")
        .fullScreenCover(item: Binding(get: { fullScreen.map(FullScreenID.init) }, set: { fullScreen = $0?.id })) { item in
            if let destination = PublicDestinations.destination(item.id) {
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

// MARK: - Keyboard shortcuts (iPad with a keyboard)

/// ⌘1–⌘5 jump to the first screen of each group; ⌘, opens Settings.
private struct PublicKeyboardShortcuts: View {
    @Binding var selection: String

    var body: some View {
        let groups = PublicDestinations.groups.filter { $0 != "Settings" && $0 != "Debug" && !PublicDestinations.group($0).isEmpty }
        ZStack {
            ForEach(Array(groups.prefix(9).enumerated()), id: \.offset) { index, group in
                if let first = PublicDestinations.group(group).first {
                    Button(group) { selection = first.id }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            Button("Settings") { selection = "settings" }.keyboardShortcut(",", modifiers: .command)
            #if DEBUG
            Button("Debug") { UserDefaults.standard.set(true, forKey: DebugMode.key); selection = "debug" }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            #endif
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

/// Launch arguments for screenshots and UI tests: `-PTDestination reader.agenda` opens that screen.
/// DEBUG builds only: in a Release build every option reads as absent.
enum PublicLaunch {
    static var destination: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-PTDestination"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}

#Preview("Shell · iPhone") {
    PublicShell().phonePreview()
}

#Preview("Shell · iPad") {
    PublicShell().padPreview()
}
