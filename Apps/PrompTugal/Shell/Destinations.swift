import PTAgenda
import PTCore
import PTDeck
import PTExplore
import PTNews
import PTWeb
import SwiftUI

/// The public app's screens (ux spec: four tabs, no More tab). The ids are the Team app's ids where a screen is the
/// same, so `promptugal://open/<id>` links and reminders keep working; the ids of screens that moved are aliases.
@MainActor
enum PublicDestinations {
    /// Internal group names. "Tabs" has no heading in the iPad sidebar.
    static let groups = ["Tabs", "More", "Debug"]

    static var all: [ShellDestination] {
        tabs + more + routable + debugOnlyScreens + debug
    }

    /// Old and extra ids that still open something sensible: the screen moved into another one.
    static let aliases: [String: String] = [
        "reader.agenda": "explore",      // the agenda is the Talks list in Explore
        "news.graph": "explore",         // the graph is opened from Explore
        "team.planner": "team.schedule", // the planner is a section of My program
        "explore.people": "explore",
        "explore.companies": "explore",
        "explore.places": "explore",
        "explore.talk": "explore",
        "explore.graph": "explore",
    ]

    /// Where Explore opens for each id that leads there (the App Store screenshots use these ids).
    static let exploreStarts: [String: ExploreStart] = [
        "explore": .talks,
        "reader.agenda": .talks,
        "explore.people": .speakers,
        "explore.companies": .companies,
        "explore.places": .places,
        "explore.talk": .talk(ref: nil),
        "explore.graph": .graph,
        "news.graph": .graph,
    ]

    /// The id a link or a launch argument means, after the aliases.
    static func resolve(_ id: String?) -> String? {
        guard let id else { return nil }
        return aliases[id] ?? id
    }

    static func destination(_ id: String?) -> ShellDestination? {
        guard let id = resolve(id) else { return nil }
        return all.first { $0.id == id }
    }

    /// A destination that may be opened now: the debug screens only in a DEBUG build with debug mode on.
    static func openable(_ id: String?, debug: Bool) -> ShellDestination? {
        guard let destination = destination(id) else { return nil }
        return destination.debugOnly && !debug ? nil : destination
    }

    /// The rows a list (the iPad sidebar) shows for a group.
    static func listed(_ group: String, debug: Bool) -> [ShellDestination] {
        all.filter { $0.group == group && $0.listed && (debug || !$0.debugOnly) }
    }

    // MARK: The four tabs

    static let tabs: [ShellDestination] = [
        ShellDestination(id: "now", title: String(localized: "Now"), symbol: "dot.radiowaves.left.and.right", group: "Tabs",
                         summary: String(localized: "What is on now, what is next for you, what is new"), phoneTab: 0) { AnyView(NowView()) },
        ShellDestination(id: "team.schedule", title: String(localized: "My program"), symbol: "star", group: "Tabs", kind: .hybrid,
                         summary: String(localized: "The talks you picked, clashes and free time"), phoneTab: 1) { AnyView(MyProgramScreen()) },
        ShellDestination(id: "explore", title: String(localized: "Explore"), symbol: "magnifyingglass", group: "Tabs",
                         summary: String(localized: "Talks, speakers, companies and places"), phoneTab: 2, wrapsStack: false) {
            AnyView(ExploreView())
        },
        ShellDestination(id: "news.home", title: String(localized: "News"), symbol: "newspaper", group: "Tabs",
                         summary: String(localized: "Latest, newsletter, stories"), phoneTab: 3) { AnyView(NewsHomeView()) },
    ]

    // MARK: More (the iPad sidebar; on iPhone Settings opens from the gear)

    static let more: [ShellDestination] = [
        ShellDestination(id: "settings", title: String(localized: "Settings"), symbol: "gearshape", group: "More",
                         summary: settingsSummary) { AnyView(PublicSettingsView()) },
        ShellDestination(id: "settings.reminders", title: String(localized: "Reminders"), symbol: "bell.badge", group: "More",
                         summary: String(localized: "Before each pick")) { AnyView(ReminderSettingsView()) },
    ]

    // MARK: Opened by id or from another screen, never in a tab or the sidebar

    static let routable: [ShellDestination] = [
        // Not in the first App Store build.
        ShellDestination(id: "decks", title: String(localized: "Decks"), symbol: "rectangle.on.rectangle.angled", group: "More",
                         summary: String(localized: "Decks and presenter mode, offline"), ownsNavigation: true, listed: false) {
            AnyView(DeckScreen())
        },
        ShellDestination(id: "web.promptugal", title: "PrompTugal.news", symbol: "newspaper.fill", group: "More",
                         kind: .web(FeedClient.site), listed: false) {
            AnyView(WebPage(url: FeedClient.site, title: "PrompTugal.news"))
        },
    ]

    static var settingsSummary: String {
        String(localized: "Reminders, about, privacy, support")
    }

    // MARK: DEBUG builds only

    /// The website list still names the team site: it is not in a Release build.
    static var debugOnlyScreens: [ShellDestination] {
        #if DEBUG
        [
            ShellDestination(id: "web.all", title: String(localized: "All websites"), symbol: "safari", group: "More", kind: .web(FeedClient.site),
                             summary: String(localized: "The website shell, with its shortcuts"), debugOnly: true) { AnyView(WebsiteView()) },
        ]
        #else
        []
        #endif
    }

    /// The debug screen exists only in DEBUG builds: a Release build has no debug panel and no switch.
    static var debug: [ShellDestination] {
        #if DEBUG
        [ShellDestination(id: "debug", title: String(localized: "Debug"), symbol: "ladybug", group: "Debug",
                          summary: String(localized: "Network and build"), debugOnly: true) { AnyView(PublicDebugView()) }]
        #else
        []
        #endif
    }
}
