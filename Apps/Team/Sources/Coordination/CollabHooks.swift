import Foundation
import PTAgenda
import PTCore
import PTNews

// Team-app additions to PTCore's `CollabHooks` (vault, me and the current page live in PTCore/CollabSeams.swift).
// PTAsk reads the agenda, picks and day plan through `AskEnvironment.provider` (`TeamAskProvider`); Coordination uses these.
extension CollabHooks {
    /// My picks as bare slugs (nr.schedule.v1), from the team session's `ScheduleStore`.
    static var myPickIds: @MainActor () -> [String] = { TeamFeatures.shared.schedule.picks.map { PickId.normalise($0.id) } }

    /// The summit agenda. Default: the reader's cache on this device, then the network (logged).
    static var agenda: @MainActor () async -> [Event] = {
        let loaded = TeamFeatures.shared.planner.agenda
        if !loaded.isEmpty { return loaded }
        let cached = ReaderFiles.cachedAgenda()
        if !cached.isEmpty { return cached }
        return (try? await FeedClient.agenda()) ?? []
    }

    /// The day plan as text, from the team session's planner (`PlannerStore`). Nil: no planner.
    static var dayPlan: (@MainActor () async -> String?)? = { CollabTeamGlue.planText(TeamFeatures.shared.planner.plan) }
}

/// Reads the reader's files on this device (written by `ReaderStore`), without touching its state.
enum ReaderFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
    }

    private struct Cache: Decodable { var agenda: [Event] = [] }

    static func cachedAgenda(in directory: URL = ReaderFiles.directory) -> [Event] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("content.json")),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return [] }
        return cache.agenda
    }

    static func savedEventIds(in directory: URL = ReaderFiles.directory) -> [String] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("saved.json")),
              let saved = try? JSONDecoder().decode([String: Event].self, from: data) else { return [] }
        return saved.keys.map(PickId.normalise).sorted()
    }
}

/// Pick ids are the bare event slug (contracts §3, changed 03:45 UTC): the website takes it from
/// `events/<slug>/index.html`. Older forms (`events/<slug>`, the page path) are read and turned into the slug.
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

    /// The ids in an nr.schedule.v1 document. Unknown shapes give an empty list.
    static func ids(inScheduleDocument data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let picks = object["picks"] as? [[String: Any]] else { return [] }
        return picks.compactMap { $0["id"] as? String }.map(normalise)
    }

    /// `{"v":1,"picks":[{"id":…,"at":…}]}` for the ids given, with `at` as an ISO 8601 string.
    static func scheduleDocument(ids: [String], at date: Date = .now) throws -> Data {
        let at = ISO8601DateFormatter.collabJS.string(from: date)
        let picks = ids.map { ["id": normalise($0), "at": at] }
        return try JSONSerialization.data(withJSONObject: ["v": 1, "picks": picks], options: [.sortedKeys])
    }
}
