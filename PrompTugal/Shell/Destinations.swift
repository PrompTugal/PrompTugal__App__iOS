import SwiftUI

/// The sidebar sections, in order (contract §7).
enum ShellSection: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case team = "Team"
    case agents = "Agents"
    case briefings = "Briefings"
    case news = "News"
    case observability = "Observability"
    case web = "Web"
    case vault = "Vault"
    case debug = "Debug"
    case settings = "Settings"

    var id: Self { self }
}

/// One screen the shell can show. Each feature registers one or more of these below.
///
/// Contract §7 names this `Destination`; it is `AppDestination` here because the
/// reader in `PrompTugalApp.swift` already has a private type called `Destination`.
struct AppDestination: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let section: ShellSection
    let kind: SurfaceKind
    /// Shown under the title in the iPhone "More" list and in the sidebar's tooltip.
    var summary: String = ""
    /// Shown on iPhone as one of the four tabs, in this order.
    var phoneTab: Int?
    /// Only shown when debug mode is on.
    var debugOnly = false
    let view: @MainActor () -> AnyView
}

/// The registry. Sessions add their entry views here; design merges the registrations.
///
/// To plug a screen in, add one line to the right section:
///
///     AppDestination(id: "team.schedule", title: "My schedule", symbol: "calendar",
///                    section: .today, kind: .hybrid) { AnyView(ScheduleView()) }
@MainActor
enum Destinations {
    static var all: [AppDestination] {
        today + team + agents + briefings + news + observability + web + vault + debug + settings
    }

    static func destination(_ id: String?) -> AppDestination? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func section(_ section: ShellSection) -> [AppDestination] {
        all.filter { $0.section == section }
    }

    // MARK: Today (design; schedule from team)

    static let today: [AppDestination] = [
        AppDestination(id: "today", title: "My day", symbol: "sun.max", section: .today, kind: .native,
                       summary: "Stand-up, what waits on me, my agents", phoneTab: 0) { AnyView(TodayView()) },
        AppDestination(id: "team.schedule", title: "My schedule", symbol: "calendar", section: .today,
                       kind: .hybrid, summary: "Picks from the website and the app, one list") { AnyView(MyDayView()) },
        AppDestination(id: "team.planner", title: "Plan my day", symbol: "calendar.day.timeline.left", section: .today,
                       kind: .native, summary: "Free slots and walking times between picks") { AnyView(PlannerView()) },
        AppDestination(id: "reader.agenda", title: "Agenda", symbol: "clock", section: .today, kind: .native,
                       summary: "The summit agenda, offline, with picks") { AnyView(AgendaView()) },
    ]

    // MARK: Team (design; team session adds Team and Store)

    static let team: [AppDestination] = [
        AppDestination(id: "team.people", title: "The team", symbol: "person.3", section: .team, kind: .native,
                       summary: "Everyone's load: only you, decide, overdue", phoneTab: 1) { AnyView(TeamDashboardView()) },
        AppDestination(id: "team.commandcentre", title: "My command centre", symbol: "rectangle.3.group",
                       section: .team, kind: .web(TeamSite.base), summary: "The team site's command centre") {
            AnyView(MyCommandCentreWeb())
        },
        // collab: replace with LanesView() from PrompTugal/Lanes when it lands.
        AppDestination(id: "collab.lanes", title: "Messages", symbol: "bubble.left.and.bubble.right",
                       section: .team, kind: .native, summary: "Append lanes to teammates and the newsroom") {
            AnyView(PendingFeatureView(title: "Messages", owner: "night/collab",
                                       note: "Shared picks and notes, and lanes to teammates, through vaults."))
        },
        AppDestination(id: "team.home", title: "Team home", symbol: "person.crop.circle", section: .team,
                       kind: .native, summary: "Who I am, and where everyone is") { AnyView(TeamHomeView()) },
        AppDestination(id: "team.store", title: "Reading credit", symbol: "creditcard", section: .team,
                       kind: .native, summary: "The meter and native top-ups") { AnyView(ReadingCreditView()) },
    ]

    // MARK: Agents

    static let agents: [AppDestination] = [
        AppDestination(id: "agents.activity", title: "What my agents do", symbol: "cpu", section: .agents,
                       kind: .native, summary: "Wakes, runs and reports", phoneTab: 2) { AnyView(AgentsDashboardView()) },
        AppDestination(id: "agents.wakes.web", title: "Wakes (web)", symbol: "globe", section: .agents,
                       kind: .web(TeamSite.base.appendingPathComponent("wakes/")), summary: "The web original") {
            AnyView(WebPage(url: TeamSite.base.appendingPathComponent("wakes/"), title: "Wakes"))
        },
        AppDestination(id: "agents.reports.web", title: "Reports (web)", symbol: "doc.text", section: .agents,
                       kind: .web(TeamSite.base.appendingPathComponent("reports/")), summary: "Every two hours") {
            AnyView(WebPage(url: TeamSite.base.appendingPathComponent("reports/"), title: "Reports"))
        },
        // collab: replace with AIChatView() from PrompTugal/AI when it lands.
        AppDestination(id: "collab.ai", title: "Ask", symbol: "sparkles", section: .agents, kind: .native,
                       summary: "OpenRouter chat over the app's own data") {
            AnyView(PendingFeatureView(title: "Ask", owner: "night/collab",
                                       note: "Chat with the key in the Keychain, using the agenda, picks and team status."))
        },
    ]

    // MARK: Briefings

    static let briefings: [AppDestination] = [
        AppDestination(id: "briefed", title: "Briefed", symbol: "text.badge.checkmark", section: .briefings,
                       kind: .hybrid, summary: "My stand-up briefing, decisions waiting") { AnyView(BriefedView()) },
        AppDestination(id: "briefings.pulse.web", title: "Pulse (web)", symbol: "waveform.path.ecg",
                       section: .briefings, kind: .web(TeamSite.base.appendingPathComponent("pulse-summary/")),
                       summary: "The team's check-ins, summarised") {
            AnyView(WebPage(url: TeamSite.base.appendingPathComponent("pulse-summary/"), title: "Pulse"))
        },
        AppDestination(id: "briefings.board.web", title: "Board health (web)", symbol: "heart.text.square",
                       section: .briefings, kind: .web(TeamSite.base.appendingPathComponent("board-health/")),
                       summary: "Deadlines at risk") {
            AnyView(WebPage(url: TeamSite.base.appendingPathComponent("board-health/"), title: "Board health"))
        },
    ]

    // MARK: News

    static let news: [AppDestination] = [
        AppDestination(id: "news.home", title: "News", symbol: "newspaper", section: .news, kind: .native,
                       summary: "Feed, newsletter, stories, graph", phoneTab: 3) { AnyView(NewsHomeView()) },
        AppDestination(id: "news.newsroom", title: "Newsroom", symbol: "building.columns", section: .news,
                       kind: .native, summary: "Desks, the story pipeline, decisions") { AnyView(NewsroomStatusView()) },
        AppDestination(id: "news.graph", title: "Graph", symbol: "point.3.connected.trianglepath.dotted",
                       section: .news, kind: .native, summary: "1,688 nodes, drawn natively") { AnyView(GraphExplorerView()) },
    ]

    // MARK: Observability

    static let observability: [AppDestination] = [
        AppDestination(id: "obs.native", title: "Observability", symbol: "chart.xyaxis.line", section: .observability,
                       kind: .native, summary: "Newsroom metrics and what is public") { AnyView(ObservabilityView()) },
        AppDestination(id: "obs.web", title: "Observability (web)", symbol: "globe", section: .observability,
                       kind: .web(FeedClient.site.appendingPathComponent("newsroom/observability/")),
                       summary: "Read from the public vault in the browser") {
            AnyView(WebPage(url: FeedClient.site.appendingPathComponent("newsroom/observability/"), title: "Observability"))
        },
    ]

    // MARK: Web

    static let web: [AppDestination] = [
        AppDestination(id: "web.promptugal", title: "PrompTugal.news", symbol: "newspaper.fill", section: .web,
                       kind: .web(FeedClient.site)) { AnyView(WebPage(url: FeedClient.site, title: "PrompTugal.news")) },
        AppDestination(id: "web.all", title: "All websites", symbol: "safari", section: .web, kind: .web(FeedClient.site),
                       summary: "The website shell, with its shortcuts") { AnyView(WebsiteView()) },
    ]

    // MARK: Vault (vault session)

    static let vault: [AppDestination] = [
        AppDestination(id: "vault", title: "Vault", symbol: "lock.shield", section: .vault, kind: .native,
                       summary: "My encrypted vault, read in Swift") { AnyView(VaultHomeView()) },
    ]

    // MARK: Debug and settings

    static let debug: [AppDestination] = [
        AppDestination(id: "debug", title: "Debug", symbol: "ladybug", section: .debug, kind: .native,
                       summary: "Vault traffic, network, bridge, storage, keys, build", debugOnly: true) { AnyView(DebugHomeView()) },
    ]

    static let settings: [AppDestination] = [
        AppDestination(id: "settings", title: "Settings", symbol: "gearshape", section: .settings, kind: .native,
                       summary: "Who I am, debug mode, about") { AnyView(SettingsView()) },
        AppDestination(id: "settings.reminders", title: "Reminders", symbol: "bell.badge", section: .settings, kind: .native,
                       summary: "Before each pick and stand-up") { AnyView(ReminderSettingsView()) },
    ]
}

/// A placeholder for a screen another session is building, so the shell is complete tonight.
struct PendingFeatureView: View {
    let title: String
    let owner: String
    let note: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            Text("\(note)\n\nBeing built tonight on \(owner).")
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(title)
        .surfaceKind(.native)
    }
}
