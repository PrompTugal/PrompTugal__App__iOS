import SGitVault
import SwiftUI

/// The root view (contract §7). On iPad a sidebar with every section; on iPhone
/// four tabs and a "More" list. Every destination comes from `Destinations`.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.scenePhase) private var scenePhase
    @State private var data = DashboardData()
    /// The vault session's reader logs here; Debug → Vault traffic reads it.
    private var vaultLog: VaultTrafficLog { VaultSession.shared.log }
    @SceneStorage("shell.selection") private var selection: String = "today"
    @SceneStorage("shell.tab") private var tab: String = "today"
    @AppStorage(DebugMode.key) private var debug = DebugMode.defaultOn
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if width == .compact {
                PhoneShell(tab: $tab, debug: debug)
            } else {
                splitView
            }
        }
        .environment(data)
        .environment(vaultLog)
        // .teamFeatures() is applied once, by the app root (PrompTugalApp), outside the shell.
        .identitySync()
        .tint(Palette.red)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await data.refreshAll() } }
        }
        .onOpenURL { url in route(url) }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            ShellSidebar(selection: $selection, debug: debug)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let destination = Destinations.destination(selection), destination.ownsNavigation {
                // The screen brings its own columns; the shell's sidebar steps aside (the system
                // sidebar button brings it back).
                destination.view().id(destination.id)
            } else {
                NavigationStack {
                    if let destination = Destinations.destination(selection) {
                        destination.view()
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
            if Destinations.destination(id)?.ownsNavigation == true { columns = .detailOnly }
        }
        .background(ShellKeyboardShortcuts(selection: $selection))
    }

    /// promptugal://open/<destination id>, e.g. promptugal://open/team.people
    private func route(_ url: URL) {
        guard url.scheme == "promptugal", url.host == "open" else { return }
        let id = url.pathComponents.dropFirst().joined(separator: "/")
        guard Destinations.destination(id) != nil else { return }
        selection = id
        tab = Destinations.destination(id)?.phoneTab != nil ? id : "more"
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
                if debug { Circle().fill(destination.kind.color).frame(width: 6, height: 6)
                    .accessibilityLabel(destination.kind.label) }
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
                Tab(destination.title, systemImage: destination.symbol, value: destination.id) {
                    NavigationStack {
                        destination.view().surfaceKind(destination.kind)
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
    @State private var fullScreen: String?

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
                                    destination.view().surfaceKind(destination.kind)
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
        .fullScreenCover(item: Binding(get: { fullScreen.map(FullScreenID.init) }, set: { fullScreen = $0?.id })) { item in
            if let destination = Destinations.destination(item.id) {
                destination.view()
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
