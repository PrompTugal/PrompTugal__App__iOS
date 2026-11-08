import PTAgenda
import PTAsk
import PTCore
import PTNews
import PTVaultUI
import PTWeb
import SwiftUI

/// The public app's screens. The ids are the Team app's ids, so `promptugal://open/<id>` links and reminders
/// keep working. Nothing here reads team data, and nothing here uses the vault or Ask unless the reader opens it.
@MainActor
enum PublicDestinations {
    static let groups = ["Summit", "News", "Ask", "Web", "Personal", "Settings", "Debug"]

    static var all: [ShellDestination] {
        summit + news + ask + web + personal + settings + debug
    }

    static func destination(_ id: String?) -> ShellDestination? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// A destination that may be opened now: the debug screen only in a DEBUG build with debug mode on.
    static func openable(_ id: String?, debug: Bool) -> ShellDestination? {
        guard let destination = destination(id) else { return nil }
        return destination.debugOnly && !debug ? nil : destination
    }

    static func group(_ name: String) -> [ShellDestination] {
        all.filter { $0.group == name }
    }

    // MARK: Summit

    static let summit: [ShellDestination] = [
        ShellDestination(id: "reader.agenda", title: "Agenda", symbol: "clock", group: "Summit",
                         summary: "The summit agenda, offline, with picks", phoneTab: 0) { AnyView(AgendaView()) },
        ShellDestination(id: "team.schedule", title: "My day", symbol: "calendar", group: "Summit", kind: .hybrid,
                         summary: "Picks from the website and the app, one list", phoneTab: 1) { AnyView(MyDayView()) },
        ShellDestination(id: "team.planner", title: "Plan my day", symbol: "calendar.day.timeline.left", group: "Summit",
                         summary: "Free slots and walking times between picks") { AnyView(PlannerView()) },
    ]

    // MARK: News

    static let news: [ShellDestination] = [
        ShellDestination(id: "news.home", title: "News", symbol: "newspaper", group: "News",
                         summary: "Feed, newsletter, stories, graph", phoneTab: 2) { AnyView(NewsHomeView()) },
        ShellDestination(id: "news.graph", title: "Graph", symbol: "point.3.connected.trianglepath.dotted", group: "News",
                         summary: "1,688 nodes, drawn natively") { AnyView(GraphExplorerView()) },
    ]

    // MARK: Ask

    static let ask: [ShellDestination] = [
        ShellDestination(id: "collab.ai", title: "Ask", symbol: "sparkles", group: "Ask",
                         summary: "Ask about the agenda, your picks and the news", phoneTab: 3) { AnyView(AskView()) },
    ]

    // MARK: Web

    static let web: [ShellDestination] = [
        ShellDestination(id: "web.promptugal", title: "PrompTugal.news", symbol: "newspaper.fill", group: "Web",
                         kind: .web(FeedClient.site)) { AnyView(WebPage(url: FeedClient.site, title: "PrompTugal.news")) },
        ShellDestination(id: "web.all", title: "All websites", symbol: "safari", group: "Web", kind: .web(FeedClient.site),
                         summary: "The website shell, with its shortcuts") { AnyView(WebsiteView()) },
    ]

    // MARK: Personal

    static let personal: [ShellDestination] = [
        ShellDestination(id: "vault", title: "Vault", symbol: "lock.shield", group: "Personal",
                         summary: "My encrypted vault, read in Swift", ownsNavigation: true) { AnyView(VaultHomeView()) },
    ]

    // MARK: Settings and debug

    static let settings: [ShellDestination] = [
        ShellDestination(id: "settings", title: "Settings", symbol: "gearshape", group: "Settings",
                         summary: "About, privacy, support") { AnyView(PublicSettingsView()) },
        ShellDestination(id: "settings.reminders", title: "Reminders", symbol: "bell.badge", group: "Settings",
                         summary: "Before each pick") { AnyView(ReminderSettingsView()) },
    ]

    /// The debug screen exists only in DEBUG builds: a Release build has no debug panel and no switch.
    static var debug: [ShellDestination] {
        #if DEBUG
        [ShellDestination(id: "debug", title: "Debug", symbol: "ladybug", group: "Debug",
                          summary: "Network and build", debugOnly: true) { AnyView(PublicDebugView()) }]
        #else
        []
        #endif
    }
}
