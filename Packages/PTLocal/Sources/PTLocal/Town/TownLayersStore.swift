import Foundation
import Observation

/// Reads a town's layers from the public sites: events from data.promptugal.news and, for the 16 Algarve councils,
/// open notices and the council's file from civic.promptugal.news. One instance for the app; each feed is read at
/// most every 10 minutes, kept on the device, and shown with its own read time.
@MainActor @Observable
public final class TownLayersStore {
    public static let shared = TownLayersStore()

    public private(set) var events: [String: Layer<TownEventsFeed>] = [:]
    public private(set) var councils: [String: Layer<CivicCouncil>] = [:]
    public private(set) var notices: Layer<CivicNotices>?

    /// A feed with where it came from.
    public struct Layer<Value: Sendable>: Sendable {
        public let value: Value
        public let provenance: Provenance
    }

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var lastRead: [String: Date] = [:]

    nonisolated static let minimumGap: TimeInterval = 10 * 60

    public init(fetch: @escaping LocalFetch = LocalStore.liveFetch, cache: LocalDiskCache = .standard(),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.fetch = fetch
        self.cache = cache
        self.clock = clock
    }

    /// Reads what this place needs, unless read in the last 10 minutes.
    public func load(placeID: String) async {
        async let a: Void = loadEvents(placeID)
        async let b: Void = loadCivic(placeID)
        _ = await (a, b)
    }

    func loadEvents(_ placeID: String) async {
        let key = "events-\(placeID)"
        guard isDue(key) else { return }
        if let feed: Layer<TownEventsFeed> = await read(TownEventsFeed.url(for: placeID), key: key) {
            events[placeID] = feed
        }
    }

    func loadCivic(_ placeID: String) async {
        guard let council = CivicCouncil.council(for: placeID) else { return }
        if isDue("civic-notices"), let feed: Layer<CivicNotices> = await read(CivicNotices.url, key: "civic-notices") {
            notices = feed
        }
        let key = "civic-council-\(council)"
        if isDue(key), let feed: Layer<CivicCouncil> = await read(CivicCouncil.url(for: council), key: key) {
            councils[council] = feed
        }
    }

    private func isDue(_ key: String) -> Bool {
        guard let last = lastRead[key] else { return true }
        return clock().timeIntervalSince(last) >= Self.minimumGap
    }

    /// Live, else this device's last copy. A place a site does not cover (404) shows nothing and is asked again only
    /// after the 10-minute gap.
    private func read<T: Decodable & Sendable>(_ url: URL, key: String) async -> Layer<T>? {
        lastRead[key] = clock()
        do {
            let data = try await fetch(url)
            let value = try JSONDecoder().decode(T.self, from: data)
            cache.store(data, key: key)
            return Layer(value: value, provenance: .live(clock()))
        } catch {
            guard let data = cache.load(key: key), let value = try? JSONDecoder().decode(T.self, from: data) else {
                return nil
            }
            return Layer(value: value, provenance: .cached(cache.modified(key: key)))
        }
    }
}
