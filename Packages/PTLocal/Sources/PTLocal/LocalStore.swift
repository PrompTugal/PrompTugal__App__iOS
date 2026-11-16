import Foundation
import Observation
import PTCore

/// Where a screen's data came from, said on the screen: never let a copy pass for live.
public enum Provenance: Equatable, Sendable {
    /// Read from promptugal.news just now.
    case live(Date)
    /// The last copy this device read, because the network failed.
    case cached(Date?)
    /// The copy built into the app, taken on the date given.
    case snapshot(String)
    case none

    public var label: String {
        switch self {
        case .live: "Live from promptugal.news"
        case .cached: "Offline: the last copy this device read"
        case .snapshot(let day): "Built-in copy of \(day): connect to update"
        case .none: "Not loaded"
        }
    }

    public var isLive: Bool { if case .live = self { true } else { false } }
}

public typealias LocalFetch = @Sendable (URL) async throws -> Data

/// Reads PrompTugal.news by place and the newsroom dashboard. Answers first from the built-in snapshot (so the first
/// launch with no network still shows the Algarve), then from this device's last copy, then live.
@MainActor @Observable
public final class LocalStore {
    public static let shared = LocalStore()

    public nonisolated static let site = URL(string: "https://promptugal.news")!
    /// The date the built-in place files were read (scripts/places/snapshot.py writes it).
    public nonisolated static let snapshotDay = LocalSnapshot.day

    public private(set) var places: [String: PlaceSite] = [:]
    public private(set) var placeProvenance: Provenance = .none
    public private(set) var dashboard: NewsroomDashboard?
    public private(set) var dashboardProvenance: Provenance = .none
    public private(set) var phase: LoadPhase = .idle
    public private(set) var dashboardPhase: LoadPhase = .idle

    /// The towns this device follows, in the order they were picked.
    public var followed: [String] {
        didSet { UserDefaults.standard.set(followed, forKey: Self.followedKey) }
    }

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private let bundle: Bundle
    static let followedKey = "local.followed"

    public init(fetch: @escaping LocalFetch = LocalStore.liveFetch, cache: LocalDiskCache = .standard(), bundle: Bundle = LocalResources.bundle) {
        self.fetch = fetch
        self.cache = cache
        self.bundle = bundle
        followed = UserDefaults.standard.stringArray(forKey: Self.followedKey) ?? []
        loadSnapshot()
    }

    public nonisolated static let liveFetch: LocalFetch = { url in
        try await HTTPClient.shared.get(url, timeout: 20, label: "local", maxBytes: 2 * 1024 * 1024)
    }

    // MARK: Reading

    public var region: PlaceSite? { places[PlaceDirectory.region.id] }
    public var country: PlaceSite? { places[PlaceDirectory.country.id] }
    public func site(_ id: String) -> PlaceSite? { places[id] }

    public var townSites: [PlaceSite] { PlaceDirectory.towns.compactMap { places[$0.id] } }
    public var liveTownCount: Int { townSites.filter(\.isLive).count }
    public var storyCount: Int { townSites.reduce(0) { $0 + $1.aiNews.count } }
    public var mappedCount: Int { townSites.reduce(0) { $0 + $1.aiMap.count } }

    /// The latest stories from the towns, newest first, each once (a story can be in two towns), with its town.
    public func latestFromTowns(limit: Int = 12, only ids: [String]? = nil) -> [TownStory] {
        var seen = Set<String>()
        var out: [TownStory] = []
        for info in PlaceDirectory.towns where ids?.contains(info.id) ?? true {
            for story in places[info.id]?.aiNews ?? [] where seen.insert(story.url).inserted {
                out.append(TownStory(town: info, story: story))
            }
        }
        return Array(out.sorted { ($0.story.date ?? "") > ($1.story.date ?? "") }.prefix(limit))
    }

    public func isFollowed(_ id: String) -> Bool { followed.contains(id) }
    public func toggleFollow(_ id: String) {
        if let index = followed.firstIndex(of: id) { followed.remove(at: index) } else { followed.append(id) }
    }

    // MARK: Loading

    /// The built-in copy: read once at start, so every screen has something true to show.
    func loadSnapshot() {
        var loaded: [String: PlaceSite] = [:]
        for info in PlaceDirectory.all {
            if let url = bundle.url(forResource: "place-\(info.id)", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let site = try? JSONDecoder().decode(PlaceSite.self, from: data) {
                loaded[info.id] = site
            }
        }
        places = loaded
        placeProvenance = loaded.isEmpty ? .none : .snapshot(Self.snapshotDay)
    }

    /// Every place, live; one failure keeps that place's earlier copy.
    public func refreshPlaces() async {
        phase = .loading
        var live = 0
        var fromCache = 0
        await withTaskGroup(of: (String, PlaceSite?, Bool).self) { group in
            for info in PlaceDirectory.all {
                group.addTask { [fetch, cache] in
                    let url = Self.site.appendingPathComponent("data/by-place/\(info.id).json")
                    do {
                        let data = try await fetch(url)
                        let site = try JSONDecoder().decode(PlaceSite.self, from: data)
                        cache.store(data, key: "place-\(info.id)")
                        return (info.id, site, true)
                    } catch {
                        if let data = cache.load(key: "place-\(info.id)"),
                           let site = try? JSONDecoder().decode(PlaceSite.self, from: data) {
                            return (info.id, site, false)
                        }
                        return (info.id, nil, false)
                    }
                }
            }
            for await (id, site, isLive) in group {
                guard let site else { continue }
                places[id] = site
                if isLive { live += 1 } else { fromCache += 1 }
            }
        }
        if live > 0 {
            placeProvenance = .live(.now)
            phase = .loaded
        } else if fromCache > 0 {
            placeProvenance = .cached(cache.modified(key: "place-\(PlaceDirectory.region.id)"))
            phase = .failed("promptugal.news could not be reached.")
        } else {
            phase = places.isEmpty ? .failed("promptugal.news could not be reached.") : .loaded
        }
    }

    public func refreshDashboard() async {
        dashboardPhase = .loading
        let url = Self.site.appendingPathComponent("api/v1/newsroom/dashboard.json")
        do {
            let data = try await fetch(url)
            dashboard = try JSONDecoder().decode(NewsroomDashboard.self, from: data)
            cache.store(data, key: "newsroom-dashboard")
            dashboardProvenance = .live(.now)
            dashboardPhase = .loaded
        } catch {
            if let data = cache.load(key: "newsroom-dashboard"),
               let stored = try? JSONDecoder().decode(NewsroomDashboard.self, from: data) {
                dashboard = stored
                dashboardProvenance = .cached(cache.modified(key: "newsroom-dashboard"))
            }
            dashboardPhase = .failed("The newsroom dashboard could not be reached.")
        }
    }

    public func refreshAll() async {
        async let a: Void = refreshPlaces()
        async let b: Void = refreshDashboard()
        _ = await (a, b)
    }
}

/// A story with the town it came from.
public struct TownStory: Identifiable, Hashable, Sendable {
    public var id: String { town.id + "|" + story.id }
    public let town: PlaceInfo
    public let story: PlaceSite.News
}

/// A small flat disk cache, one file per key, written atomically.
public struct LocalDiskCache: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func standard() -> LocalDiskCache {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return LocalDiskCache(directory: base.appendingPathComponent("PTLocal", isDirectory: true))
    }

    private func file(_ key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? String($0) : "_" }.joined()
        return directory.appendingPathComponent(String(safe.prefix(180)) + ".json")
    }

    public func store(_ data: Data, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file(key), options: .atomic)
        } catch {
            // A full disk must not break reading; the next fetch tries again.
        }
    }

    public func load(key: String) -> Data? { try? Data(contentsOf: file(key)) }

    public func modified(key: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file(key).path))?[.modificationDate] as? Date
    }

    public func clear() { try? FileManager.default.removeItem(at: directory) }
}

/// The package's own resource bundle (the built-in place files), for the app and the tests.
public enum LocalResources {
    public static var bundle: Bundle { .module }
}
