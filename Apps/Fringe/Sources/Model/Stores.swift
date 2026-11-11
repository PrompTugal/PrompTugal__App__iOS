import Foundation
import Observation

/// Reads the live feed on launch and on pull to refresh. Keeps the last good copy on the phone,
/// and ships a copy in the app for the first launch and for use offline.
@MainActor
@Observable
final class FeedStore {
    static let eventsURL = URL(string: "https://lisbontechfringe.com/api/v1/events.json")!
    static let communitiesURL = URL(string: "https://lisbontechfringe.com/api/v1/communities.json")!

    private(set) var events: [FeedEvent] = []
    private(set) var hostLines: [String: String] = [:]
    /// When the copy on screen was fetched (or built, for the copy in the app).
    private(set) var copyTime: Date?
    /// False until a fetch in this session works.
    private(set) var isLive = false
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let defaults: UserDefaults
    private let session: URLSession
    private static let fetchedAtKey = "ltf.feed.fetchedAt"

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        loadLocalCopy()
    }

    private static var cacheDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LisbonTechFringe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadLocalCopy() {
        let cachedEvents = Self.cacheDir.appendingPathComponent("events.json")
        let cachedCommunities = Self.cacheDir.appendingPathComponent("communities.json")
        if let data = try? Data(contentsOf: cachedEvents), let feed = try? EventFeed.decode(data), !feed.events.isEmpty {
            events = feed.events
            copyTime = defaults.object(forKey: Self.fetchedAtKey) as? Date ?? feed.builtAt
        } else if let url = Bundle.main.url(forResource: "events", withExtension: "json"),
                  let data = try? Data(contentsOf: url), let feed = try? EventFeed.decode(data) {
            events = feed.events
            copyTime = feed.builtAt
        }
        let communityData = (try? Data(contentsOf: cachedCommunities))
            ?? Bundle.main.url(forResource: "communities", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        if let communityData, let c = try? JSONDecoder().decode(CommunityFeed.self, from: communityData) {
            hostLines = c.hostLines
        }
    }

    /// Fetches both files. On failure the copy on screen stays and the list says it is offline.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: Self.eventsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.httpShouldHandleCookies = false
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let feed = try EventFeed.decode(data)
            guard !feed.events.isEmpty else { throw URLError(.cannotParseResponse) }
            try? data.write(to: Self.cacheDir.appendingPathComponent("events.json"), options: .atomic)
            let now = Date()
            defaults.set(now, forKey: Self.fetchedAtKey)
            events = feed.events
            copyTime = now
            isLive = true
            lastError = nil
        } catch {
            isLive = false
            lastError = "Could not load lisbontechfringe.com: \(error.localizedDescription)"
        }
        if let result = try? await session.data(from: Self.communitiesURL),
           (result.1 as? HTTPURLResponse)?.statusCode == 200,
           let c = try? JSONDecoder().decode(CommunityFeed.self, from: result.0) {
            let data = result.0
            try? data.write(to: Self.cacheDir.appendingPathComponent("communities.json"), options: .atomic)
            hostLines = c.hostLines
        }
    }

    /// "Updated 17:02" or "Offline copy from 17:02".
    func freshnessText(now: Date = Date()) -> String {
        guard let copyTime else { return "Offline copy" }
        let time = FeedDate.hhmm(copyTime)
        let sameDay = FeedDate.dayString(copyTime) == FeedDate.dayString(now)
        let when = sameDay ? time : "\(Day(key: FeedDate.dayString(copyTime)).shortTitle), \(time)"
        return isLive ? "Updated \(when)" : "Offline copy from \(when)"
    }

    var visibleEvents: [FeedEvent] { events.filter { $0.category != .hidden } }
}

/// A saved event that moved or was cancelled since the last refresh.
struct ChangeNotice: Codable, Hashable, Sendable, Identifiable {
    let eventID: String
    let text: String
    var id: String { eventID }
}

/// Saved events live on the phone only.
@MainActor
@Observable
final class SavedStore {
    private(set) var ids: [String]
    private(set) var notices: [ChangeNotice]
    private var snapshot: [String: String]
    private let defaults: UserDefaults

    private static let idsKey = "ltf.saved.ids"
    private static let snapshotKey = "ltf.saved.snapshot"
    private static let noticesKey = "ltf.saved.notices"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = defaults.stringArray(forKey: Self.idsKey) ?? []
        snapshot = (defaults.dictionary(forKey: Self.snapshotKey) as? [String: String]) ?? [:]
        if let data = defaults.data(forKey: Self.noticesKey),
           let list = try? JSONDecoder().decode([ChangeNotice].self, from: data) {
            notices = list
        } else {
            notices = []
        }
    }

    func isSaved(_ event: FeedEvent) -> Bool { ids.contains(event.id) }

    func toggle(_ event: FeedEvent) {
        if let i = ids.firstIndex(of: event.id) {
            ids.remove(at: i)
            snapshot[event.id] = nil
            notices.removeAll { $0.eventID == event.id }
        } else {
            ids.append(event.id)
            snapshot[event.id] = Self.fingerprint(event)
        }
        persist()
    }

    func saved(in events: [FeedEvent]) -> [FeedEvent] {
        let set = Set(ids)
        return events.filter { set.contains($0.id) }
    }

    /// Call after each fetch: notes saved events that moved or were cancelled since the last one.
    func compare(with events: [FeedEvent]) {
        let result = Self.changes(savedIDs: ids, snapshot: snapshot, events: events)
        for n in result.notices where !notices.contains(where: { $0.eventID == n.eventID && $0.text == n.text }) {
            notices.removeAll { $0.eventID == n.eventID }
            notices.append(n)
        }
        snapshot = result.snapshot
        persist()
    }

    func dismissNotices() {
        notices = []
        persist()
    }

    private func persist() {
        defaults.set(ids, forKey: Self.idsKey)
        defaults.set(snapshot, forKey: Self.snapshotKey)
        defaults.set(try? JSONEncoder().encode(notices), forKey: Self.noticesKey)
    }

    // MARK: Pure parts, tested

    nonisolated static func fingerprint(_ e: FeedEvent) -> String {
        "\(e.status ?? "")|\(e.date)|\(e.start.map { String(Int($0.timeIntervalSince1970)) } ?? "")"
    }

    nonisolated static func changes(savedIDs: [String], snapshot: [String: String], events: [FeedEvent])
        -> (notices: [ChangeNotice], snapshot: [String: String]) {
        let byID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var notices: [ChangeNotice] = []
        var next = snapshot
        for id in savedIDs {
            guard let e = byID[id] else { continue }
            let now = fingerprint(e)
            if let before = snapshot[id], before != now {
                let parts = before.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                let oldStatus = parts.first ?? ""
                if e.eventStatus == .cancelled, oldStatus.lowercased() != e.status?.lowercased() {
                    notices.append(ChangeNotice(eventID: id, text: "\(e.name) is cancelled."))
                } else if e.eventStatus == .moved || before.dropFirst(oldStatus.count) != now.dropFirst((e.status ?? "").count) {
                    notices.append(ChangeNotice(eventID: id, text: "\(e.name) has moved. It is now \(Day(key: e.date).title), \(e.timeRange)."))
                }
            }
            next[id] = now
        }
        return (notices, next)
    }
}

/// Which tab and which day are showing, shared so "Find more for Thursday" can switch tab.
@MainActor
@Observable
final class AppState {
    enum TabID: Hashable { case all, mine, calendar }
    var tab: TabID = .all
    var day: String?
    var category: EventCategoryChoice = .inPerson
}

enum EventCategoryChoice: Hashable { case inPerson, online }
