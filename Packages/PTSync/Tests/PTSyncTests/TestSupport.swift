import Foundation
@testable import PTSync

/// A temporary folder, removed by `cleanup()`.
struct TempDir {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("ptsync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func cleanup() { try? FileManager.default.removeItem(at: url) }
}

func entry(_ path: String, _ content: String, feature: String? = nil) -> ManifestEntry {
    let data = Data(content.utf8)
    return ManifestEntry(path: path, bytes: data.count, sha256: SHA256Hex.of(data), feature: feature)
}

let testSource = SyncSource(id: "test", base: URL(string: "https://example.test/")!)

/// Everything in the test rules is core, except `big/` which is full and `skip/` which is never fetched.
let testRules = PackRules(rules: [.init("skip/", nil), .init("big/", .full)], fallback: .core)

/// A site in memory: files, a manifest built from them, and switches for what can go wrong.
final class FakeSite: SyncTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data] = [:]
    private var version = "v1"
    /// Paths whose next downloads fail with a network error (count of failures left).
    private var failing: [String: Int] = [:]
    /// Paths served with the wrong bytes of the right size.
    private var corrupt: Set<String> = []
    /// Paths served with more bytes than the manifest says.
    private var oversize: Set<String> = []
    private(set) var requests: [String] = []
    private var manifestStatusOverride: Int?

    func set(_ path: String, _ content: String) { lock.withLock { files[path] = Data(content.utf8) } }
    func remove(_ path: String) { lock.withLock { _ = files.removeValue(forKey: path) } }
    func setVersion(_ value: String) { lock.withLock { version = value } }
    func fail(_ path: String, times: Int) { lock.withLock { failing[path] = times } }
    func corrupt(_ path: String) { lock.withLock { _ = corrupt.insert(path) } }
    func oversize(_ path: String) { lock.withLock { _ = oversize.insert(path) } }
    func overrideManifestStatus(_ status: Int?) { lock.withLock { manifestStatusOverride = status } }
    func requestCount(for path: String) -> Int { lock.withLock { requests.filter { $0 == path }.count } }
    func clearRequests() { lock.withLock { requests.removeAll() } }
    var totalRequests: Int { lock.withLock { requests.count } }

    /// The manifest JSON, with a `schema` key per file and an unknown top-level key, as the real one has.
    func manifestData() -> Data {
        lock.withLock {
            let list = files.keys.sorted().map { path -> [String: Any] in
                let data = files[path]!
                return ["path": path, "bytes": data.count, "sha256": SHA256Hex.of(data), "schema": NSNull(), "feature": "api"]
            }
            let object: [String: Any] = ["version": version, "about": "test", "count": list.count, "files": list]
            return try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
    }

    func download(_ url: URL, ifNoneMatch: String?, into directory: URL) async throws -> SyncDownload {
        let path = String(url.path.dropFirst())     // "/api/x.json" -> "api/x.json"
        let outcome: (status: Int, data: Data?, etag: String?) = try lock.withLock {
            requests.append(path)
            if path == "api/v1/manifest.json" {
                if let status = manifestStatusOverride { return (status, nil, nil) }
                let tag = "\"\(version)-\(files.count)-\(files.values.reduce(0) { $0 + $1.count })\""
                if ifNoneMatch == tag { return (304, nil, tag) }
                return (200, nil, tag)   // body filled in below
            }
            if let left = failing[path], left > 0 {
                failing[path] = left - 1
                throw URLError(.notConnectedToInternet)
            }
            guard var data = files[path] else { return (404, nil, nil) }
            if corrupt.contains(path) { data = Data(repeating: 0x58, count: data.count) }
            if oversize.contains(path) { data.append(Data("extra".utf8)) }
            return (200, data, nil)
        }
        if outcome.status != 200 { return SyncDownload(status: outcome.status, file: nil, etag: outcome.etag) }
        let body = path == "api/v1/manifest.json" ? manifestData() : outcome.data!
        let file = directory.appendingPathComponent(UUID().uuidString + ".part")
        try body.write(to: file)
        return SyncDownload(status: 200, file: file, etag: outcome.etag)
    }
}

/// A connection that is whatever the test says.
struct FakePath: NetworkPath {
    var isExpensive = false
    var isConstrained = false
}

func makeEngine(site: FakeSite, store: ContentStore, path: NetworkPath? = nil,
                policy: SyncPolicy = SyncPolicy(retries: 1, retryDelay: 0), now: @escaping @Sendable () -> Date = { Date() }) -> SyncEngine {
    SyncEngine(store: store, rules: testRules, transport: site, network: path, policy: policy, now: now)
}

/// A clock the test moves by hand.
final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ seconds: TimeInterval = 1_000) { date = Date(timeIntervalSince1970: seconds) }
    func now() -> Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}
