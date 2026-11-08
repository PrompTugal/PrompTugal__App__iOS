import Foundation
import PTAgenda
import PTCore

/// The public app's context: the agenda, my picks and the page on screen. No team data, no person name.
/// Picks come from the one schedule (`AgendaHub.schedule`, set by the app at launch), the same list the website,
/// the widgets and the reminders use.
@MainActor
public final class PublicAskProvider: AskContextProvider {
    public init() {}

    public var supportedKinds: Set<AIContextKind> { [.agenda, .picks, .page] }
    public var personName: String? { nil }

    /// The reader's cache on this device, then the network (logged in Debug → Network).
    public func agenda() async -> [Event] {
        let cached = AskAgendaCache.events()
        if !cached.isEmpty { return cached }
        return (try? await FeedClient.agenda()) ?? []
    }

    public func myPickIds() -> [String] {
        (AgendaHub.schedule?.picks ?? []).map { PickId.normalise($0.id) }
    }

    public func isPicked(_ event: Event) -> Bool { AgendaHub.schedule?.isPicked(event) ?? false }

    public func togglePick(_ event: Event) { AgendaHub.schedule?.toggle(event) }

    public func part(for kind: AIContextKind, now: Date) async -> AIContextPart? { nil }

    public func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)? { nil }

    /// Two prepared questions the public app can answer from the agenda and the picks.
    public var extraStarters: [AIStarter] {
        [AIStarter(id: "now-next", title: String(localized: "What is on now and next?", bundle: .module), symbol: "clock",
                   prompt: String(localized: "What is on at the summit right now, and what starts in the next two hours? Times in Lisbon time, one line each: time, title, place. If nothing is on, say when the next session starts.", bundle: .module),
                   include: [.agenda]),
         AIStarter(id: "my-picks-day", title: String(localized: "Plan my day from my picks", bundle: .module), symbol: "star",
                   prompt: String(localized: "Using my picks first, then the agenda, plan the rest of my day at the summit, from now, in Lisbon time. Show a timeline: time, what, where. Point out clashes (two things at once) and say which you would choose and why. Leave about 10 minutes to walk between venues and one break.", bundle: .module),
                   include: [.agenda, .picks])]
    }
}

/// The agenda the reader keeps on this device (`content.json`, written by `ReaderStore`), read without touching its state.
enum AskAgendaCache {
    private struct Cache: Decodable { var agenda: [Event] = [] }

    static func events(in directory: URL = URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)) -> [Event] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("content.json")),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return [] }
        return cache.agenda
    }
}

/// Pick ids are the bare event slug (contracts §3). Older forms (`events/<slug>`, the page path) turn into the slug.
enum PickId {
    static func normalise(_ raw: String) -> String {
        var id = raw.trimmingCharacters(in: .whitespaces)
        if id.hasPrefix("/") { id.removeFirst() }
        for suffix in ["/index.html", "/"] where id.hasSuffix(suffix) {
            id.removeLast(suffix.count)
        }
        if let range = id.range(of: "events/", options: .backwards) { id = String(id[range.upperBound...]) }
        return id
    }

    static func of(_ event: Event) -> String { normalise(event.page) }
}
