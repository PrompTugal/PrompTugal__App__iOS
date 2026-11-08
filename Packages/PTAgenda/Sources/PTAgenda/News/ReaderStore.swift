import Foundation
import Observation
import PTCore
import PTWeb

@MainActor @Observable
public final class ReaderStore {
    private struct Cache: Codable {
        var agenda: [Event] = []
        var news: [Story] = []
        var details: [String: EventDetail] = [:]
        var agendaUpdated: Date?
        var newsUpdated: Date?
    }

    /// Session details kept in the offline cache. The agenda has a few hundred sessions; details are
    /// fetched one at a time as sessions are opened, so this bounds content.json without losing any
    /// detail the reader is likely to open again.
    public nonisolated static let maxDetails = 300

    private var cache = Cache()
    private let directory: URL
    /// Saved sessions are the schedule's picks (contracts §3); the schedule imported the old saved.json.
    private var schedule: ScheduleStore? { AgendaHub.schedule }
    public private(set) var agendaUnavailable = false
    public private(set) var newsUnavailable = false
    public private(set) var refreshing = false
    /// Where the agenda on screen came from, for a "synced 3 min ago" line: the app's seed, the cache of an earlier
    /// run, or this run's refresh.
    public enum AgendaSource: Equatable, Sendable { case none, seed, cache, network }
    public private(set) var agendaSource: AgendaSource = .none
    public var storageMessage: String?

    // Both go through the screenshot filter (-PTHideTerm, Debug builds only; a no-op in Release).
    public var agenda: [Event] { ScreenshotFilter.events(cache.agenda) }
    public var news: [Story] { ScreenshotFilter.stories(cache.news) }
    public var agendaUpdated: Date? { cache.agendaUpdated }
    public var newsUpdated: Date? { cache.newsUpdated }
    public var saved: [Event] { (schedule?.picks ?? []).compactMap(\.event).sorted(by: Event.earlier) }

    public init() {
        directory = URL.applicationSupportDirectory.appendingPathComponent("PrompTugal", isDirectory: true)
        // Read the offline cache off the main thread: content.json can be a few MB with every
        // session's details, and decoding it here would hold up the first frame.
        let file = directory.appendingPathComponent("content.json")
        Task { [weak self] in
            let decoded = await Self.decodeCache(at: file)
            self?.adoptCachedContent(decoded)
        }
    }

    private nonisolated static func decodeCache(at file: URL) async -> Cache? {
        await Task.detached(priority: .userInitiated) { () -> Cache? in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(Cache.self, from: data)
        }.value
    }

    /// Takes what the cache file holds, unless a refresh already brought something newer.
    private func adoptCachedContent(_ decoded: Cache?) {
        if let decoded {
            if cache.agendaUpdated == nil {
                cache.agenda = decoded.agenda
                cache.agendaUpdated = decoded.agendaUpdated
                if !decoded.agenda.isEmpty { agendaSource = .cache }
            }
            if cache.newsUpdated == nil {
                cache.news = decoded.news
                cache.newsUpdated = decoded.newsUpdated
            }
            cache.details = Self.trimmed(decoded.details.merging(cache.details) { _, fresh in fresh },
                                         keeping: keptDetailIDs)
        }
        // Nothing cached yet: start from the agenda in the synced files (PTSync, kept on the device), then from the one
        // built into the app, so the first launch works with no network. Neither is written to the cache; only a real
        // refresh is.
        if cache.agenda.isEmpty {
            let seed = LiveContent.agenda() ?? AgendaHub.seedAgenda()
            if !seed.isEmpty {
                cache.agenda = seed
                agendaSource = .seed
            }
        }
        adoptKeptNews()
        publishNowNext()
    }

    /// News the feed syncer already holds on the device, used only while the cache and the network have none.
    private func adoptKeptNews() {
        guard cache.news.isEmpty else { return }
        let kept = LiveContent.stories()
        if !kept.isEmpty { cache.news = kept }
    }

    /// The ids whose details stay first when the cache is trimmed: today's agenda, then the picks.
    private var keptDetailIDs: [String] {
        cache.agenda.map(\.id) + (schedule?.picks ?? []).compactMap(\.event?.id)
    }

    /// At most `limit` details: those for `keeping` first (in that order), then the rest by id.
    public nonisolated static func trimmed<Detail>(_ details: [String: Detail], keeping: [String],
                                            limit: Int = maxDetails) -> [String: Detail] {
        guard details.count > limit else { return details }
        var order: [String] = []
        var seen = Set<String>()
        for id in keeping where details[id] != nil && seen.insert(id).inserted { order.append(id) }
        for id in details.keys.sorted() where seen.insert(id).inserted { order.append(id) }
        var result: [String: Detail] = [:]
        for id in order.prefix(limit) { result[id] = details[id] }
        return result
    }

    /// Gives the schedule the cached agenda (offline start) and keeps the widgets' "Now and next" current.
    public func publishNowNext() {
        if cache.agenda.isEmpty {
            AgendaHub.publishNowNext([], saved)
        } else {
            AgendaHub.agendaDidLoad(agenda)
        }
    }

    /// What the Now screen shows at `now`: the phase, what is next for the person, what is on, what starts soon.
    public func nowModel(at now: Date = AgendaClock.now) -> NowModel {
        NowModel(events: cache.agenda, picks: schedule?.picks ?? [], now: now)
    }

    public func event(id: String) -> Event? {
        agenda.first { $0.id == id } ?? (schedule?.picks ?? []).lazy.compactMap(\.event).first { $0.id == id }
    }

    public func isSaved(_ event: Event) -> Bool { schedule?.isPicked(event) ?? false }
    public func detail(for event: Event) -> EventDetail? { cache.details[event.id] }

    public func toggleSaved(_ event: Event) {
        schedule?.toggle(self.event(id: event.id) ?? event)
    }

    public func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        async let agenda: Void = refreshAgenda()
        async let news: Void = refreshNews()
        _ = await (agenda, news)
    }

    private func refreshAgenda() async {
        do {
            let events = try await FeedClient.agenda()
            try Task.checkCancellation()
            cache.agenda = events
            cache.agendaUpdated = .now
            agendaSource = .network
            agendaUnavailable = false
            persistCache()
            publishNowNext()
        } catch {
            if !Task.isCancelled { agendaUnavailable = true }
        }
    }

    private func refreshNews() async {
        do {
            let stories = try await FeedClient.news()
            try Task.checkCancellation()
            cache.news = stories
            cache.newsUpdated = .now
            newsUnavailable = false
            persistCache()
        } catch {
            if !Task.isCancelled {
                newsUnavailable = true
                adoptKeptNews()
            }
        }
    }

    public func refreshDetail(for event: Event) async {
        do {
            let detail = try await FeedClient.detail(for: event)
            try Task.checkCancellation()
            cache.details[event.id] = detail
            cache.details = Self.trimmed(cache.details, keeping: [event.id] + keptDetailIDs)
            persistCache()
        } catch {
            // The event page remains available when the detail feed cannot be reached.
        }
    }

    private func persistCache() {
        do {
            try write(cache, to: "content.json")
        } catch {
            storageMessage = String(localized: "The latest content couldn’t be stored for offline use.", bundle: .module)
        }
    }

    private func write<Value: Encodable>(_ value: Value, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
