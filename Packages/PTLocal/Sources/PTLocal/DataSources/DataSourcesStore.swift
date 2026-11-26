import Foundation
import Observation
import PTCore

/// Reads one small feed per PrompTugal.news site, and data.promptugal.news's catalogue, for the Data sources screen.
/// One instance for the app; at most one read every 10 minutes; each feed kept on the device and shown with where it
/// came from. Read-only.
@MainActor @Observable
public final class DataSourcesStore {
    public static let shared = DataSourcesStore()

    public private(set) var readings: [String: SiteReading] = [:]
    public private(set) var provenance: [String: Provenance] = [:]
    public private(set) var index: DataIndex?
    public private(set) var phase: LoadPhase = .idle

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var lastLoad: Date?

    nonisolated static let minimumGap: TimeInterval = 10 * 60

    public init(fetch: @escaping LocalFetch = LocalStore.liveFetch, cache: LocalDiskCache = .standard(),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.fetch = fetch
        self.cache = cache
        self.clock = clock
    }

    /// Reads every site, unless read in the last 10 minutes (`force` for pull to refresh).
    public func load(force: Bool = false) async {
        let now = clock()
        if !force, let lastLoad, now.timeIntervalSince(lastLoad) < Self.minimumGap { return }
        lastLoad = now
        phase = .loading
        var any = false
        await withTaskGroup(of: (String, Data?, Bool).self) { group in
            for site in DataSite.all {
                guard let url = site.feed else { continue }
                group.addTask { [fetch, cache] in
                    let key = "data-site-\(site.id)"
                    if let data = try? await fetch(url) {
                        cache.store(data, key: key)
                        return (site.id, data, true)
                    }
                    return (site.id, cache.load(key: key), false)
                }
            }
            for await (id, data, live) in group {
                guard let data else { continue }
                accept(id: id, data: data, live: live, now: now)
                any = true
            }
        }
        phase = any ? .loaded : .failed(LocalText.string("The PrompTugal.news sites could not be reached."))
    }

    private func accept(id: String, data: Data, live: Bool, now: Date) {
        let source: Provenance = live ? .live(now) : .cached(cache.modified(key: "data-site-\(id)"))
        if id == "data", let decoded = try? JSONDecoder().decode(DataIndex.self, from: data) {
            index = decoded
            for derived in ["weather", "events", "signals"] {
                if let reading = DataSiteProbe.reading(site: derived, index: decoded) {
                    readings[derived] = reading
                    provenance[derived] = source
                }
            }
        }
        if let reading = DataSiteProbe.reading(site: id, data: data) {
            readings[id] = reading
            provenance[id] = source
        }
    }

    /// How many sites read their data in the last 3 hours, and how many have a known read time.
    public func freshCounts(now: Date) -> (live: Int, dated: Int) {
        var live = 0
        var dated = 0
        for reading in readings.values {
            guard let read = reading.readAt else { continue }
            dated += 1
            if Freshness.of(read, now: now).isLive { live += 1 }
        }
        return (live, dated)
    }
}
