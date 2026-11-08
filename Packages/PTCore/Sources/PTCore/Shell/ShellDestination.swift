import SwiftUI

/// One screen a shell can show. The group is plain text (a sidebar section or a "More" heading), so each app
/// names its own groups.
public struct ShellDestination: Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public let group: String
    public let kind: SurfaceKind
    /// Shown under the title in the iPhone "More" list and in the sidebar's tooltip.
    public var summary: String
    /// Shown on iPhone as one of the tabs, in this order.
    public var phoneTab: Int?
    /// A short label for the iPhone tab bar, when the title is long.
    public var tabTitle: String?
    /// Only shown when debug mode is on.
    public var debugOnly: Bool
    /// The screen has its own NavigationSplitView or NavigationStack. The shell then does not wrap it
    /// in a stack: on iPad it hides the shell's sidebar, on iPhone it opens full screen.
    public var ownsNavigation: Bool
    /// False: the screen can be opened by id (links, other screens) but is not in the tabs, the sidebar or a list.
    public var listed: Bool
    public let view: @MainActor () -> AnyView

    public init(id: String, title: String, symbol: String, group: String, kind: SurfaceKind = .native,
                summary: String = "", phoneTab: Int? = nil, tabTitle: String? = nil,
                debugOnly: Bool = false, ownsNavigation: Bool = false, listed: Bool = true,
                view: @escaping @MainActor () -> AnyView) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.group = group
        self.kind = kind
        self.summary = summary
        self.phoneTab = phoneTab
        self.tabTitle = tabTitle
        self.debugOnly = debugOnly
        self.ownsNavigation = ownsNavigation
        self.listed = listed
        self.view = view
    }
}

/// A row of the iPad sidebar. In debug mode it also shows the native, web or hybrid badge.
public struct ShellSidebarRow: View {
    let destination: ShellDestination
    let badge: Int?
    let debug: Bool

    public init(destination: ShellDestination, badge: Int? = nil, debug: Bool) {
        self.destination = destination
        self.badge = badge
        self.debug = debug
    }

    public var body: some View {
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
                }
            }
        } icon: {
            Image(systemName: destination.symbol)
        }
        .badge(badge ?? 0)
        .help(destination.summary)
    }
}

/// A row of the iPhone "More" list.
public struct ShellMoreRow: View {
    let destination: ShellDestination

    public init(destination: ShellDestination) {
        self.destination = destination
    }

    public var body: some View {
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
