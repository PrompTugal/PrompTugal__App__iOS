import Foundation

/// Something in the app that costs reading credit, named by the website's page kind it is priced as, so the app
/// charges what promptugal.news charges for the same kind of reading. Other packages (PTPlaces, the AI and Talk
/// screens) build one of these and pass it to `LocalCredit.shared.charge(kind:)`.
///
/// | In the app | Priced as (site page-type) | Why |
/// | --- | --- | --- |
/// | a story from a town, opened | `story`, by the story's date | the site's story: assembled by agents, decays |
/// | a town or region page | `place` | the site's town pages are `place` pages (1p, no decay) |
/// | the newsroom | `site` | the site's newsroom page is a `site` page |
/// | an AI summary or "explain the AI path" | `topic` (analysis), base price | work a reader cannot do from one page |
/// | a question to a town's agent | `article`, base price | an answer is judgement, the site's dearest kind |
/// | a contribution sent (photo, video, interview) | `evidence` | a capture with its source: the floor |
/// | the live view, the CI status | `data` | reading how the newsroom runs: the floor |
/// | your reading account, top up | `account` | the meter's own pages are free |
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

    public var id: String { action + ":" + (ref ?? "-") }

    public init(pageType: String, action: String, ref: String? = nil, pageDate: String? = nil, title: String,
                oncePerSession: Bool = true) {
        self.pageType = pageType
        self.action = action
        self.ref = ref
        self.pageDate = pageDate
        self.title = title
        self.oncePerSession = oncePerSession && ref != nil
    }

    // MARK: The app's kinds

    /// A story from a town (its source opened from the app).
    public static func story(url: String, title: String, date: String?) -> CreditKind {
        CreditKind(pageType: "story", action: "story", ref: url, pageDate: date, title: title)
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
    public static func page(type: String, ref: String, date: String? = nil, title: String) -> CreditKind {
        CreditKind(pageType: type, action: "page." + type, ref: ref, pageDate: date, title: title)
    }

    /// The rows of the app's price list: one example of each kind of reading in the app.
    public static var priceList: [(label: String, kind: CreditKind)] { [
        ("A story, the day it was published", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 0)),
        ("A story, two weeks old", .story(url: "example", title: "A story", date: nil).withDate(ageDays: 14)),
        ("A town or the Algarve", .town(id: "example", name: "A town")),
        ("The newsroom", .newsroom),
        ("An AI summary", .aiSummary(of: "example", title: "a town")),
        ("A question to a town's agent", .talk(to: "a town")),
        ("A contribution (photo, video, interview)", .contribution("a photo")),
        ("The live view or the CI status", .data("example", title: "Live")),
    ] }

    /// The same kind dated this many days ago (for the price list).
    func withDate(ageDays: Double, now: Date = .now) -> CreditKind {
        let date = now.addingTimeInterval(-ageDays * 86_400 + 60)
        let formatter = ISO8601DateFormatter()
        return CreditKind(pageType: pageType, action: action, ref: ref, pageDate: formatter.string(from: date), title: title,
                          oncePerSession: oncePerSession)
    }
}
