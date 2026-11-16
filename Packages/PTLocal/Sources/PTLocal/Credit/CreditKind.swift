import Foundation

/// Something in the app that costs reading credit, named by the website's page kind it is priced as, so the app
/// charges what promptugal.news charges for the same kind of reading. Other packages (PTPlaces, the AI and Talk
/// screens) build one of these and pass it to `LocalCredit.shared.charge(kind:)`.
///
/// | In the app | Priced as (site page-type) | Paid? |
/// | --- | --- | --- |
/// | a story's full detail, opened | `story`, by the story's date (1p to 4p) | yes |
/// | an on-device AI summary or "explain the AI path" | `topic` (analysis), base price (3p) | yes, once per thing per session |
/// | a question to a town's agent | `article`, base price (6p) | yes, each question |
/// | a contribution sent (photo, video, interview) | `evidence` (1p) | yes, each one |
/// | browsing places, lists, the newsroom | (`town`, `newsroom`, `data` kinds exist, priced as the site's `place`, `site`, `data`) | free: not charged by the app |
public struct CreditKind: Hashable, Sendable, Identifiable {
    /// The site's page-type this is priced as (a key of `types` in meter.json).
    public let pageType: String
    /// A stable key for the feature ("story", "town", "ai.summary"), never display text.
    public let action: String
    /// What was read: a story's URL, a town's id. Charged once per app session per action and ref.
    public let ref: String?
    /// The page's own date, for freshness. Nil means the base price.
    public let pageDate: String?
    /// What the history says.
    public let title: String
    /// True when reading the same thing again in the same session is not a second charge (the site's rule for
    /// pages). Asking a question or sending a contribution is charged each time.
    public let oncePerSession: Bool
    /// Whose work was read: the outlet a paid read is attributed to ("Barlavento", "PrompTugal.news"), from the
    /// story's publisher or its URL's host. Nil for things that are not someone's story (an AI summary, a
    /// contribution). Revenue to outlets is planned, not yet paid: see "Where your credit goes".
    public let outlet: String?

    public var id: String { action + ":" + (ref ?? "-") }

    public init(pageType: String, action: String, ref: String? = nil, pageDate: String? = nil, title: String,
                oncePerSession: Bool = true, outlet: String? = nil) {
        self.pageType = pageType
        self.action = action
        self.ref = ref
        self.pageDate = pageDate
        self.title = title
        self.oncePerSession = oncePerSession && ref != nil
        // Only reads are someone's work: a story or a site page. An AI summary or a question is not attributed, even
        // when its ref is a story's address.
        let isRead = action == Action.story || action.hasPrefix("page.")
        self.outlet = Self.outletName(publisher: outlet, url: isRead ? ref : nil)
    }

    /// The outlet's name: the publisher as the data gives it, else the host of a web address without "www."
    /// (promptugal.news reads as "PrompTugal.news"). Nil when there is neither.
    public static func outletName(publisher: String?, url: String?) -> String? {
        if let name = publisher?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        guard let url, let components = URLComponents(string: url),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              var host = components.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host == "promptugal.news" || host.hasSuffix(".promptugal.news") { return "PrompTugal.news" }
        return host
    }

    // MARK: The app's kinds

    /// A story from a town (its source opened from the app).
    public static func story(url: String, title: String, date: String?, publisher: String? = nil) -> CreditKind {
        CreditKind(pageType: "story", action: "story", ref: url, pageDate: date, title: title, outlet: publisher)
    }

    /// A town's page, or the region's (the Algarve, Portugal).
    public static func town(id: String, name: String) -> CreditKind {
        CreditKind(pageType: "place", action: "town", ref: id, title: name)
    }

    /// The newsroom behind the sites.
    public static var newsroom: CreditKind {
        CreditKind(pageType: "site", action: "newsroom", ref: "newsroom", title: "The newsroom")
    }

    /// An Apple Intelligence summary of a town or a story, or the AI path explained. Once per thing per session.
    public static func aiSummary(of ref: String, title: String) -> CreditKind {
        CreditKind(pageType: "topic", action: "ai.summary", ref: ref, title: "AI summary: \(title)")
    }

    /// One question to a town's agent (or the on-device stand-in). Each question is charged.
    public static func talk(to agent: String) -> CreditKind {
        CreditKind(pageType: "article", action: "talk", ref: agent, title: "Question to \(agent)", oncePerSession: false)
    }

    /// A contribution sent from the app: a photo, screenshot, video or recorded interview. Each is charged.
    public static func contribution(_ what: String) -> CreditKind {
        CreditKind(pageType: "evidence", action: "contribution", title: "Contribution: \(what)", oncePerSession: false)
    }

    /// The live view of the agents, or the CI status page.
    public static func data(_ ref: String, title: String) -> CreditKind {
        CreditKind(pageType: "data", action: "data", ref: ref, title: title)
    }

    /// Any page of the site's kinds, by its page-type (article, company, topic, story, event, index, person,
    /// organisation, place, evidence, data, site, account) and its date.
    public static func page(type: String, ref: String, date: String? = nil, title: String, outlet: String? = nil) -> CreditKind {
        CreditKind(pageType: type, action: "page." + type, ref: ref, pageDate: date, title: title, outlet: outlet)
    }

    /// The actions other packages name by string (PTPlaces stays PTCore-only and calls a closure the app injects).
    /// What is paid (conductor, 16 Nov): opening a story's full detail, an on-device AI summary, a contribution, a
    /// question to an agent. Browsing lists is free.
    public enum Action {
        public static let story = "story"
        public static let aiSummary = "ai.summary"
        public static let contribution = "contribution"
        public static let talk = "talk"
    }

    /// A kind from plain strings: the action ("story", "ai.summary", "contribution", "talk", or any site page-type),
    /// what was read (a story's URL, a place id), the page's date and the words for the history.
    public static func named(_ action: String, ref: String, date: String? = nil, title: String, outlet: String? = nil) -> CreditKind {
        switch action {
        case Action.story: .story(url: ref, title: title, date: date, publisher: outlet)
        case Action.aiSummary: .aiSummary(of: ref, title: title)
        case Action.contribution: .contribution(title)
        case Action.talk: .talk(to: ref)
        default: .page(type: action, ref: ref, date: date, title: title, outlet: outlet)
        }
    }

    /// The rows of the app's price list: what is paid in the app. Browsing lists is free.
    public static var priceList: [(label: String, kind: CreditKind)] { [
        ("A story, the day it was published", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 0)),
        ("A story, a few days old", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 3)),
        ("A story, two weeks old", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 14)),
        ("A story, older than a month", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 45)),
        ("An AI summary", .aiSummary(of: "example", title: "a town")),
        ("A question to a town's agent", .talk(to: "a town")),
        ("A contribution (photo, video, interview)", .contribution("a photo")),
        ("Browsing places, lists and the newsroom", .page(type: "account", ref: "browse", title: "Browsing")),
    ] }

    /// The same kind dated this many days ago (for the price list).
    func withDate(ageDays: Double, now: Date = .now) -> CreditKind {
        let date = now.addingTimeInterval(-ageDays * 86_400 + 60)
        let formatter = ISO8601DateFormatter()
        return CreditKind(pageType: pageType, action: action, ref: ref, pageDate: formatter.string(from: date), title: title,
                          oncePerSession: oncePerSession, outlet: outlet)
    }
}
