import Foundation

/// Tools Ask can call to read the app's own data when the question needs it (as the website's chat does with
/// `window.__tool`). Read only: no tool changes anything. Each call and a one-line result show in the conversation.
enum AITools {
    static let resultCap = 12_000
    static let maxHops = 6

    private static func schema(_ properties: [String: JSONValue] = [:], required: [String] = []) -> JSONValue {
        .object(["type": .string("object"), "properties": .object(properties),
                 "required": .array(required.map(JSONValue.string))])
    }

    private static func tool(_ name: String, _ description: String, _ parameters: JSONValue) -> OpenRouter.Tool {
        OpenRouter.Tool(function: .init(name: name, description: description, parameters: parameters))
    }

    static let definitions: [OpenRouter.Tool] = [
        tool("now", "The time in Lisbon, and the summit sessions on now and starting in the next hour.", schema()),
        tool("search_agenda", "Search the Web Summit Lisbon 2026 agenda by words in the title or place. Optionally one day (YYYY-MM-DD).",
             schema(["query": .object(["type": .string("string"), "description": .string("words to look for")]),
                     "day": .object(["type": .string("string"), "description": .string("YYYY-MM-DD, optional")])],
                    required: ["query"])),
        tool("my_picks", "The sessions the user picked, with day, time and place.", schema()),
        tool("team_status", "The user's team status: counts, urgent items, decisions waiting, next stand-up.", schema()),
        tool("my_agents", "What the user's agents did recently, and the latest reports.", schema()),
        tool("where_is_everyone", "Which teammates go to which sessions on a day, and clashes. Needs plans shared through vaults.",
             schema(["day": .object(["type": .string("string"), "description": .string("YYYY-MM-DD")])], required: ["day"])),
    ]

    // MARK: Pure parts

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
    }

    /// Events whose title or place contain every word of the query.
    static func search(_ events: [Event], query: String, day: String?, limit: Int = 20) -> [Event] {
        let words = fold(query).split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        return events.filter { event in
            if let day, !day.isEmpty, event.date != day { return false }
            let haystack = fold("\(event.title) \(event.place) \(event.kind)")
            return words.allSatisfy { haystack.contains($0) }
        }
        .sorted(by: Event.earlier)
        .prefix(limit)
        .map { $0 }
    }

    /// Agenda sessions whose full title appears in `text` (case and accents ignored), in the order they appear.
    /// Short titles (under 12 characters) are skipped: they match too much by chance.
    static func mentioned(in text: String, events: [Event], limit: Int = 6) -> [Event] {
        let haystack = fold(text)
        var found: [(String.Index, Event)] = []
        var seen = Set<String>()
        for event in events where event.title.count >= 12 && !seen.contains(event.id) {
            if let range = haystack.range(of: fold(event.title)) {
                found.append((range.lowerBound, event))
                seen.insert(event.id)
            }
        }
        return found.sorted { $0.0 < $1.0 }.prefix(limit).map(\.1)
    }

    static func line(_ event: Event) -> String {
        "\(Lisbon.dayLabel(event.date)) \(event.time) · \(event.title) · \(event.place)"
    }

    static func onNow(_ events: [Event], at now: Date) -> (now: [Event], next: [Event]) {
        let current = events.filter { event in
            guard let start = event.start else { return false }
            return start <= now && now < (event.end ?? start.addingTimeInterval(1_800))
        }
        let next = events.filter { event in
            guard let start = event.start else { return false }
            return start > now && start <= now.addingTimeInterval(3_600)
        }
        return (current.sorted(by: Event.earlier), next.sorted(by: Event.earlier))
    }

    static func arguments(_ json: String) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return [:] }
        return object.compactMapValues { $0 as? String }
    }

    // MARK: Running

    /// Runs one call. Returns the text the model gets and a one-line summary for the conversation.
    @MainActor
    static func run(_ call: OpenRouter.ToolCall, now: Date = .now) async -> (result: String, summary: String) {
        let args = arguments(call.function.arguments)
        switch call.function.name {
        case "now":
            let (current, next) = onNow(await CollabHooks.agenda(), at: now)
            let text = (["Lisbon: \(AIContextAssembler.longLisbon(now))", "On now:"] + current.map { "- " + line($0) }
                        + ["Next hour:"] + next.map { "- " + line($0) }).joined(separator: "\n")
            return (cap(text), "\(current.count) on now, \(next.count) next")
        case "search_agenda":
            let found = search(await CollabHooks.agenda(), query: args["query"] ?? "", day: args["day"])
            let text = found.isEmpty ? "No session matches." : found.map(line).joined(separator: "\n")
            return (cap(text), "\(found.count) \(found.count == 1 ? "result" : "results")")
        case "my_picks":
            let part = AIContextAssembler.picksPart(ids: CollabHooks.myPickIds(), events: await CollabHooks.agenda(), now: now)
            return (cap(part.body.isEmpty ? "No picks yet." : part.body), part.summary)
        case "team_status":
            let part = await AIContextGatherer.teamPart()
            return (cap(part.body.isEmpty ? part.summary : part.body), part.summary)
        case "my_agents":
            let part = await AIContextGatherer.agentsPart()
            return (cap(part.body.isEmpty ? part.summary : part.body), part.summary)
        case "where_is_everyone":
            let store = CoordinationStore.shared
            if store.plans.isEmpty { await store.load() }
            let day = args["day"] ?? AIContextAssembler.lisbonDay(now)
            return (cap(store.summary(for: day)), "\(store.plans.count) plans")
        default:
            return ("error: no tool called \(call.function.name)", "unknown tool")
        }
    }

    static func cap(_ text: String) -> String {
        text.count > resultCap ? String(text.prefix(resultCap)) + "…(truncated)" : text
    }
}
