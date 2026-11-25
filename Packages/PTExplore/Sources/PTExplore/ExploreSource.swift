import Foundation
import PTCore

/// Where the entries come from. Injected, so a PTSync-backed or ContentSource-backed loader can replace the
/// first one without touching the screens.
public protocol ExploreSource: Sendable {
    func index() async throws -> ExploreIndex
    /// The full record of one entry (facts and links to other entries).
    func detail(for item: ExploreItem) async throws -> ExploreDetail
}

public typealias ExploreFetch = @Sendable (URL) async throws -> Data

public enum ExploreFetchers {
    public static let live: ExploreFetch = { url in
        try await HTTPClient.shared.get(url, timeout: 20, label: "explore", maxBytes: 4 * 1024 * 1024)
    }
}

/// A small flat disk cache, one file per key, written atomically.
public struct ExploreDiskCache: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func standard() -> ExploreDiskCache {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return ExploreDiskCache(directory: base.appendingPathComponent("PTExplore", isDirectory: true))
    }

    private func file(_ key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? String($0) : "_" }.joined()
        return directory.appendingPathComponent(String(safe.prefix(180)))
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
    /// When the stored copy was written, if there is one.
    public func modified(key: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file(key).path))?[.modificationDate] as? Date
    }
    public func clear() { try? FileManager.default.removeItem(at: directory) }
}

/// Reads promptugal.news over HTTPS and keeps what it read on disk. When the network fails it answers from disk.
///
/// - Index: `api/v1/search-docs.json` (talks, speakers, companies, organisations) and `api/v1/places.json`.
/// - Detail: `api/v1/<folder>/<slug>.json`, read when an entry is opened.
public struct PublishedExploreSource: ExploreSource {
    public let base: URL
    public let fetch: ExploreFetch
    public let cache: ExploreDiskCache

    public init(base: URL = URL(string: "https://promptugal.news")!, cache: ExploreDiskCache = .standard(),
                fetch: @escaping ExploreFetch = ExploreFetchers.live) {
        self.base = base
        self.cache = cache
        self.fetch = fetch
    }

    /// Fetches `path`, stores it, and returns it with where it came from; on failure returns the stored copy or rethrows.
    private func read(_ path: String, key: String) async throws -> (data: Data, origin: ExploreOrigin) {
        do {
            let data = try await fetch(base.appendingPathComponent(path))
            cache.store(data, key: key)
            return (data, ExploreOrigin(kind: .live, date: Date()))
        } catch {
            if error is CancellationError { throw error }
            if let stored = cache.load(key: key) {
                return (stored, ExploreOrigin(kind: .cached, date: cache.modified(key: key)))
            }
            throw error
        }
    }

    public func index() async throws -> ExploreIndex {
        let docs = try await read("api/v1/search-docs.json", key: "search-docs.json")
        var index = try ExploreWire.index(searchDocs: docs.data, places: nil, base: base)
        index.origin = docs.origin
        // Places are a bonus: the index is still useful without them.
        if let places = try? await read("api/v1/places.json", key: "places.json") {
            let withPlaces = try ExploreWire.index(searchDocs: docs.data, places: places.data, base: base)
            index.items = withPlaces.items
            index.origin = docs.origin.combined(with: places.origin)
        }
        return index
    }

    public func detail(for item: ExploreItem) async throws -> ExploreDetail {
        let path = "api/v1/\(item.kind.folder)/\(item.slug).json"
        let got = try await read(path, key: "detail.\(item.kind.rawValue).\(item.slug).json")
        var detail = try ExploreDetail.decode(got.data, kind: item.kind)
        detail.origin = got.origin
        return detail
    }
}
