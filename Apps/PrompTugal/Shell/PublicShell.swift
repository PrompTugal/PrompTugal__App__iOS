import PTAgenda
import PTCore
import PTExplore
import PTNews
import PTWeb
import SwiftUI

/// Root view of the public app. iPhone: four tabs (Now, My program, Explore, News) and no More tab; iPad: a sidebar
/// with the same four, then Settings and Reminders. Settings opens from a gear on Now and My program. Ask is reached
/// from a card on Now and from Settings, not from a tab. Every screen comes from `PublicDestinations`. No team names,
/// no lanes, no sample data, and no debug screen in a Release build.
struct PublicShell: View {
    // Created in this order: the features register the hubs the reader store reads.
    @State private var features = PublicFeatures.shared
    @State private var reader = ReaderStore()
    @State private var newsFeeds = NewsFeeds()

    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("shell.selection") private var selection = "now"
    @SceneStorage("shell.tab") private var tab = "now"
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    @State private var columns: NavigationSplitViewVisibility = .all
    /// A page opened by a link (a reminder's session), shown over the shell.
    @State private var linkedPage: LinkedPage?
    /// A screen that is not a tab, opened over the iPhone shell (Settings from the gear, a link to Ask).
    @State private var presented: PresentedScreen?
    /// Where Explore opens (a link such as explore.people picks a segment).
    @State private var exploreStart: ExploreStart = .talks

    var body: some View {
        Group {
            if width == .compact {
                PublicPhoneShell(tab: $tab, openSettings: { open("settings") })
            } else {
                splitView
            }
        }
        .environment(reader)
        .environment(\.newsSource, reader)
        .environment(newsFeeds)
        .environment(\.openDestination, { open($0) })
        .environment(\.exploreStart, exploreStart)
        .publicFeatures(features)
        .pickToasts()
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
        .sheet(item: $presented) { screen in
            if let destination = PublicDestinations.destination(screen.id) {
                PresentedScreenView(destination: destination) { presented = nil }
            }
        }
        .onAppear {
            // A restored selection from an older build may name a screen that moved or no longer exists.
            if PublicDestinations.openable(selection, debug: debug) == nil { selection = "now" }
            selection = PublicDestinations.resolve(selection) ?? "now"
            if PublicDestinations.destination(tab)?.phoneTab == nil { tab = "now" }
            tab = PublicDestinations.resolve(tab) ?? "now"
            if let id = PublicLaunch.destination { open(id) }
        }
        .accessibilityIdentifier("public-shell")
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            PublicSidebar(selection: $selection, debug: debug)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let destination = PublicDestinations.openable(selection, debug: debug),
               destination.ownsNavigation || !destination.wrapsStack {
                // The screen brings its own columns; the sidebar steps aside (the system button brings it back).
                destination.view().destinationID(destination.id).id(destination.id)
            } else {
                NavigationStack {
                    if let destination = PublicDestinations.openable(selection, debug: debug) {
                        destination.view().destinationID(destination.id)
                            .id(destination.id)
                            .surfaceKind(destination.kind)
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

    /// Opens a screen by id: a tab selects the tab, any other screen is a sheet on iPhone and the detail on iPad.
    private func open(_ id: String) {
        if let start = PublicDestinations.exploreStarts[id] { exploreStart = start }
        guard let destination = PublicDestinations.openable(id, debug: debug) else { return }
        selection = destination.id
        if destination.phoneTab != nil {
            tab = destination.id
            presented = nil
        } else if width == .compact {
            presented = PresentedScreen(id: destination.id)
        }
    }

    /// <scheme>://open/<destination id>, e.g. <scheme>://open/team.schedule. Old ids still land somewhere sensible.
    private func route(_ url: URL) {
        guard url.scheme == AppLinks.scheme, url.host == "open" else { return }
        let id = url.pathComponents.dropFirst().joined(separator: "/")
        guard PublicDestinations.openable(id, debug: debug) != nil else { return }
        open(id)
        // A reminder names the session (?session=<slug>): open its page over the shell.
        linkedPage = ShellLink.page(in: url, isBlocked: CheckoutPolicy.isBlocked)
    }
}

/// A screen opened over the iPhone shell.
private struct PresentedScreen: Identifiable {
    let id: String
}

private struct PresentedScreenView: View {
    let destination: ShellDestination
    let close: () -> Void

    var body: some View {
        if destination.ownsNavigation {
            // The screen has its own navigation stack: a close button floats over it.
            destination.view().destinationID(destination.id)
                .overlay(alignment: .topTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical)
                    }
                    .padding(Space.m)
                    .accessibilityLabel("Close \(destination.title)")
                }
        } else {
            NavigationStack {
                destination.view().destinationID(destination.id).surfaceKind(destination.kind)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) }
                    }
            }
        }
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
                let rows = PublicDestinations.listed(group, debug: debug)
                if !rows.isEmpty {
                    if group == "Tabs" {
                        Section { rowViews(rows) }
                    } else {
                        Section(group) { rowViews(rows) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PrompTugal")
    }

    @ViewBuilder private func rowViews(_ rows: [ShellDestination]) -> some View {
        ForEach(rows) { destination in
            ShellSidebarRow(destination: destination, debug: debug).tag(destination.id)
        }
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

// MARK: - iPhone tabs

private struct PublicPhoneShell: View {
    @Binding var tab: String
    let openSettings: () -> Void

    private var tabs: [ShellDestination] {
        PublicDestinations.all.filter { $0.phoneTab != nil }.sorted { ($0.phoneTab ?? 0) < ($1.phoneTab ?? 0) }
    }

    /// The gear sits on the two screens a participant lives in.
    private func hasGear(_ id: String) -> Bool { id == "now" || id == "team.schedule" }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(tabs) { destination in
                Tab(destination.tabTitle ?? destination.title, systemImage: destination.symbol, value: destination.id) {
                    if destination.wrapsStack {
                        NavigationStack {
                            destination.view().destinationID(destination.id).surfaceKind(destination.kind)
                                .toolbar {
                                    if hasGear(destination.id) {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button(action: openSettings) { Image(systemName: "gearshape") }
                                                .accessibilityLabel("Settings")
                                        }
                                    }
                                }
                        }
                    } else {
                        // The screen has its own navigation stack (Explore).
                        destination.view().destinationID(destination.id)
                    }
                }
            }
        }
    }
}

// MARK: - Keyboard shortcuts (iPad with a keyboard)

/// ⌘1–⌘4 jump to the four tabs; ⌘, opens Settings.
private struct PublicKeyboardShortcuts: View {
    @Binding var selection: String

    var body: some View {
        let tabs = PublicDestinations.listed("Tabs", debug: false)
        ZStack {
            ForEach(Array(tabs.prefix(9).enumerated()), id: \.offset) { index, destination in
                Button(destination.title) { selection = destination.id }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
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

/// Launch arguments for screenshots and UI tests: `-PTDestination now` opens that screen.
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
