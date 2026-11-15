import Foundation
import Observation
import PTCore

/// Watches the newsroom while the live screen is open: reads dashboard.json every 60 seconds (the place files every
/// fifth time), diffs each read against the one before, and keeps the ticker and the "what just changed" set the
/// graph pulses with. The first read is diffed against the copy this device kept from its last visit, so opening the
/// screen shows what changed while you were away. Read-only.
@MainActor @Observable
public final class LiveNewsroom {
    /// One watcher for the whole app: the live screen and the strips on the places pages share its reads.
    public static let shared = LiveNewsroom()

    public private(set) var dashboard: NewsroomDashboard?
    public private(set) var extras: LiveDashboardExtras?
    public private(set) var events: [LiveEvent] = []
    public private(set) var provenance: Provenance = .none
    public private(set) var phase: LoadPhase = .idle
    public private(set) var lastPoll: Date?
    /// When this device last looked, if it had a copy from before.
    public private(set) var lastVisit: Date?
    /// When each agent was last seen to change while watching (or since the last visit).
    public private(set) var changedAt: [String: Date] = [:]
    public private(set) var polls = 0

    public nonisolated static let interval: Duration = .seconds(60)
    nonisolated static let cacheKey = "live-dashboard-previous"

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let clock: @Sendable () -> Date

    public init(store: LocalStore = .shared, fetch: @escaping LocalFetch = LocalStore.liveFetch,
                cache: LocalDiskCache = .standard(), clock: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.fetch = fetch
        self.cache = cache
        self.clock = clock
    }

    @ObservationIgnored private var inFlight = false

    /// Reads once a minute until the calling task is cancelled (a screen's `.task`). Several screens may run it at
    /// once; they share the reads, so the dashboard is still read once a minute.
    public func run() async {
        while !Task.isCancelled {
            if !inFlight, Self.isDue(lastPoll: lastPoll, now: clock()) { await poll() }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    nonisolated static func isDue(lastPoll: Date?, now: Date) -> Bool {
        guard let lastPoll else { return true }
        return now.timeIntervalSince(lastPoll) >= 55
    }

    public func poll() async {
        inFlight = true
        defer { inFlight = false }
        let now = clock()
        phase = .loading
        var url = URLComponents(url: LocalStore.site.appendingPathComponent("api/v1/newsroom/dashboard.json"),
                                resolvingAgainstBaseURL: false)!
        // One read per minute: a minute stamp keeps a cache in between from answering with an old copy.
        url.queryItems = [URLQueryItem(name: "m", value: String(Int(now.timeIntervalSince1970 / 60)))]
        do {
            let data = try await fetch(url.url!)
            let next = try JSONDecoder().decode(NewsroomDashboard.self, from: data)
            accept(next, extras: try? JSONDecoder().decode(LiveDashboardExtras.self, from: data), now: now)
            cache.store(data, key: Self.cacheKey)
            provenance = .live(now)
            phase = .loaded
        } catch {
            if dashboard == nil, let data = cache.load(key: Self.cacheKey),
               let stored = try? JSONDecoder().decode(NewsroomDashboard.self, from: data) {
                accept(stored, extras: try? JSONDecoder().decode(LiveDashboardExtras.self, from: data), now: now)
                provenance = .cached(cache.modified(key: Self.cacheKey))
            }
            phase = .failed("The newsroom dashboard could not be reached.")
        }
        lastPoll = now
        if polls % 5 == 0 { await pollPlaces(now: now) }
        polls += 1
    }

    /// Takes a new dashboard: diff against the last one (or the copy from the last visit), merge into the ticker.
    func accept(_ next: NewsroomDashboard, extras next2: LiveDashboardExtras?, now: Date) {
        var fresh: [LiveEvent] = []
        if let previous = dashboard {
            fresh = NewsroomDiff.changes(from: previous, to: next, now: now, origin: .watched)
        } else {
            if let data = cache.load(key: Self.cacheKey),
               let stored = try? JSONDecoder().decode(NewsroomDashboard.self, from: data),
               stored.at != next.at || stored.built != next.built {
                lastVisit = cache.modified(key: Self.cacheKey)
                fresh = NewsroomDiff.changes(from: stored, to: next, now: now, origin: .sinceLastVisit)
            }
            events = NewsroomDiff.latest(next, now: now)
        }
        for role in NewsroomDiff.roles(in: fresh) { changedAt[role] = now }
        events = NewsroomDiff.merge(fresh, into: events)
        dashboard = next
        if let next2 { extras = next2 }
    }

    private func pollPlaces(now: Date) async {
        let before = store.places
        await store.refreshPlaces()
        let fresh = NewsroomDiff.placeChanges(from: before, to: store.places, now: now)
        for role in NewsroomDiff.roles(in: fresh) { changedAt[role] = now }
        events = NewsroomDiff.merge(fresh, into: events)
    }

    // MARK: Reading

    public var places: [String: PlaceSite] { store.places }

    public func agent(_ role: String) -> NewsroomDashboard.Agent? { dashboard?.agents.first { $0.role == role } }

    /// How lit an agent is, 1 just now fading to 0 over `window`: from its own last sign of life or a change seen here.
    public func activity(_ role: String, now: Date, window: TimeInterval = 30 * 60) -> Double {
        let seen = changedAt[role]
        let own = agent(role)?.lastSign(now: now)
        guard let latest = [seen, own].compactMap({ $0 }).max() else { return 0 }
        return LiveNewsroom.decay(since: latest, now: now, window: window)
    }

    nonisolated static func decay(since date: Date, now: Date, window: TimeInterval) -> Double {
        let age = max(0, now.timeIntervalSince(date))
        guard age < window else { return 0 }
        return 1 - age / window
    }
}
