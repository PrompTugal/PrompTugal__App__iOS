import PTAgenda
import PTCore
import PTDeck
import PTExplore
import PTLocal
import PTNews
import PTPlaces
import PTWeb
import SwiftUI

/// The public app's screens: four tabs (Places, News, Now, Explore) and More, a sheet from the round button. Places (PrompTugal.news by
/// place: Portugal, the Algarve and its 17 towns) opens first since 16 November 2026; the summit's venue Map moved to More. The ids are the Team app's ids where a screen is the
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
        // The summit's screens are gone (Dinis, 25 Nov): their old links open Places.
        "reader.agenda": "places",
        "team.schedule": "places",
        "team.planner": "places",
        "map": "places",
        "settings.reminders": "places",
        "explore.talk": "places",
        "explore.summit": "places",
        "explore.people": "places",
        "news.graph": "explore",         // the graph is opened from Explore
        "explore.companies": "explore",
        "explore.places": "explore",
        "explore.graph": "explore",
        "explore.stories": "explore",
        "explore.library": "explore",
        "algarve": "places",
        "places.algarve": "places",
    ]

    /// Where Explore opens for each id that leads there (the App Store screenshots use these ids).
    static let exploreStarts: [String: ExploreStart] = [
        "explore": .stories,
        "explore.stories": .stories,
        "explore.library": .library,
        "explore.companies": .companies,
        "explore.places": .places,
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
        if id.hasPrefix("place:") { return place(String(id.dropFirst("place:".count))) }
        return all.first { $0.id == id }
    }

    /// `place:<id>` (promptugal://open/place:loule, -PTDestination place:loule): one town or region page, built on the fly.
    static func place(_ rest: String) -> ShellDestination? {
        // place:loule, place:loule#lead, place:faro#now: the page scrolls once to the anchor (PTPlaces PlacesDeepLink).
        guard let link = PlacesDeepLink("place:" + rest) else { return destination("places") }
        return ShellDestination(id: link.text, title: String(localized: "Place"), symbol: "mappin.and.ellipse", group: "More",
                                listed: false) {
            AnyView(PlaceDetailView(id: link.id, anchor: link.anchor))
        }
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

    // MARK: The tabs (Explore left the tabs on 26 Nov, Dinis: its content was the summit; still routable)

    static let tabs: [ShellDestination] = [
        // Home (Dinis, 26 Nov): the PrompTugal.news front page, top news from the towns, the Algarve and Portugal (PTPlaces).
        ShellDestination(id: "home", title: String(localized: "Home"), symbol: "newspaper.fill", group: "Tabs",
                         summary: String(localized: "The top news from every town, the Algarve and Portugal"), phoneTab: 0) {
            AnyView(PortugalHomeView())
        },
        ShellDestination(id: "places", title: String(localized: "Places"), symbol: "map.fill", group: "Tabs",
                         summary: String(localized: "Portugal, the Algarve and its 17 towns: local AI news, the AI map, the agents"), phoneTab: 1) {
            AnyView(PlacesHomeView())
        },
        ShellDestination(id: "news.home", title: String(localized: "News"), symbol: "newspaper", group: "Tabs",
                         summary: String(localized: "Latest, newsletter, stories"), phoneTab: 2) { AnyView(NewsHomeView()) },
        ShellDestination(id: "now", title: String(localized: "Now"), symbol: "dot.radiowaves.left.and.right", group: "Tabs",
                         summary: String(localized: "Your towns, what is new, what is on"), phoneTab: 3) { AnyView(NowView()) },
        ShellDestination(id: "explore", title: String(localized: "Explore"), symbol: "magnifyingglass", group: "Tabs",
                         summary: String(localized: "Stories, companies, places and the library"), wrapsStack: false, listed: false) {
            AnyView(ExploreView())
        },
    ]

    // MARK: More (the iPad sidebar; on iPhone a sheet from the round button on every tab)

    static let more: [ShellDestination] = [
        // Not listed: Reading credit and CI status stay routable (old links) but are not in More (25 Nov).
        // The newsroom behind PrompTugal.news by place (read-only). The Places reader itself is PTPlaces (ios.places@).
        ShellDestination(id: "local.newsroom", title: String(localized: "Newsroom"), symbol: "person.3.sequence", group: "More",
                         summary: String(localized: "The agents behind the sites, read-only")) { AnyView(NewsroomCentreView()) },
        // The reading meter: the same prices as promptugal.news, the history of charges, App Store top-ups.
        ShellDestination(id: "local.credit", title: String(localized: "Reading credit"), symbol: "sterlingsign.circle", group: "More",
                         summary: String(localized: "Your balance, what you read, top up"), listed: false) { AnyView(LocalCreditView()) },
        // How long a push takes to reach the site and TestFlight, and whether this device's build is the latest (PTLocal/Status).
        ShellDestination(id: "local.ci-status", title: String(localized: "CI status"), symbol: "gauge.with.dots.needle.67percent", group: "More",
                         summary: String(localized: "From push to production, read-only"), listed: false) { AnyView(CIStatusView()) },
        // The last edition saved on this phone for offline reading, hash-checked against the site's manifest (PTLocal).
        ShellDestination(id: "local.offline", title: String(localized: "Offline edition"), symbol: "arrow.down.circle", group: "More",
                         summary: String(localized: "Save the latest edition to read without a connection")) { AnyView(OfflineEditionView()) },
        // Every site behind the app, with what it covers and how fresh it is (Dinis, 25 Nov; PTLocal/DataSources).
        ShellDestination(id: "local.sources", title: String(localized: "Data sources"), symbol: "server.rack", group: "More",
                         summary: String(localized: "The sites behind every story and number, and how fresh each is")) { AnyView(DataSourcesView()) },
        // The Algarve maps: every town coloured by its news (PTLocal/Live).
        ShellDestination(id: "local.maps", title: String(localized: "Algarve maps"), symbol: "map", group: "More",
                         summary: String(localized: "Every town coloured by its news: map, 3D and grid")) { AnyView(AlgarveMapsView()) },
        // Apple Intelligence on the device, persona mode and Near me over the by-place data (PTLocal/AI, appdev.ai@).
        ShellDestination(id: "local.ask", title: String(localized: "Ask and summarise"), symbol: "sparkles", group: "More",
                         summary: String(localized: "Apple Intelligence on this device, persona mode, near me")) { AnyView(AskAndSummariseView()) },
        ShellDestination(id: "settings", title: String(localized: "More"), symbol: "ellipsis.circle", group: "More",
                         summary: settingsSummary) { AnyView(PublicSettingsView()) },
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
        String(localized: "Data sources, newsroom, about, privacy, support")
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
