import Foundation
import Testing
@testable import PTLocal

/// The fake site: path → body.
private let bodies: [String: String] = [
    "api/v1/articles.json": #"{"articles":[]}"#,
    "api/v1/articles/one.json": #"{"title":"One"}"#,
    "api/v1/since.json": #"{"items":[]}"#,
    "api/v1/by-place/index.json": #"{"places":[]}"#,
    "api/v1/by-place/faro.json": #"{"id":"faro","name":"Faro","updated":"2026-11-25","ai_news":[]}"#,
    "api/v1/newsletter.json": #"{"issues":[]}"#,
    "api/v1/newsletter/2026-11-13-evening.txt": "Evening edition",
]

private func entry(_ path: String, body: String? = nil, feature: String = "api") -> String {
    let text = body ?? bodies[path] ?? ""
    let data = Data(text.utf8)
    return #"{"path":"\#(path)","bytes":\#(data.count),"sha256":"\#(EditionHash.hex(data))","feature":"\#(feature)"}"#
}

private func manifestJSON(extra: [String] = []) -> String {
    var entries = bodies.keys.sorted().map { entry($0) }
    entries.append(entry("api/v1/by-place/faro-sul.json", body: "{}"))      // not a place the app knows
    entries.append(entry("api/v1/by-place/faro/now.json", body: "{}"))      // a place's live file, not saved
    entries.append(entry("api/v1/articles/deep/two.json", body: "{}"))     // nested, not saved
    entries.append(entry("api/v1/search/a.json", body: "{}"))
    entries.append(entry("../etc/passwd", body: "x"))
    entries.append(#"{"path":"api/v1/broken.json"}"#)                    // no size or hash: dropped
    entries.append(contentsOf: extra)
    return #"{"version":"v0.1.2293","count":3222,"files":["# + entries.joined(separator: ",") + "]}"
}

private let now = ISO8601DateFormatter().date(from: "2026-11-26T03:00:00Z")!

private final class FakeSite: @unchecked Sendable {
    var manifest: String
    var tamper: String?
    var requests: [String] = []
    private let lock = NSLock()

    init(manifest: String) { self.manifest = manifest }

    func fetch(_ url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        let path = String(url.path.dropFirst())
        requests.append(path)
        if path == "api/v1/manifest.json" { return Data(manifest.utf8) }
        if path == tamper { return Data("tampered".utf8) }
        guard let body = bodies[path] else { throw URLError(.fileDoesNotExist) }
        return Data(body.utf8)
    }
}

private func tempFiles() -> EditionFiles {
    EditionFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent("edition-\(UUID().uuidString)"))
}

@Suite("Offline edition")
struct OfflineEditionTests {
    @Test("The edition is the same subset for everyone: articles, since, place index and known places, newsletter")
    func subset() throws {
        let manifest = try JSONDecoder().decode(EditionManifest.self, from: Data(manifestJSON().utf8))
        #expect(manifest.version == "v0.1.2293")
        #expect(manifest.files.count == bodies.count + 5)
        let paths = manifest.editionFiles().map(\.path)
        #expect(paths == bodies.keys.sorted())
        #expect(!paths.contains("api/v1/by-place/faro-sul.json"))
        #expect(!paths.contains("api/v1/by-place/faro/now.json"))
    }

    @Test("Unsafe paths are never saved")
    func safety() {
        #expect(EditionManifest.isSafe("api/v1/since.json"))
        #expect(!EditionManifest.isSafe("../etc/passwd"))
        #expect(!EditionManifest.isSafe("api/v1/../../x.json"))
        #expect(!EditionManifest.isSafe("/api/v1/x.json"))
        #expect(!EditionManifest.isSafe("https://evil.example/api/v1/x.json"))
    }

    @Test("SHA-256 in hex")
    func hash() {
        #expect(EditionHash.hex(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(EditionHash.matches(Data("abc".utf8), "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
    }

    @Test("Saving downloads and verifies each file, keeps a record, and readers can load them")
    @MainActor func save() async throws {
        let site = FakeSite(manifest: manifestJSON())
        let files = tempFiles()
        defer { files.delete() }
        let edition = OfflineEdition(files: files, fetch: { try site.fetch($0) },
                                     cost: { NetworkCost(expensive: false, constrained: false, online: true) }, clock: { now })
        #expect(await edition.save())
        #expect(edition.state == .idle)
        let saved = try #require(edition.saved)
        #expect(saved.version == "v0.1.2293")
        #expect(saved.savedAt == now)
        #expect(saved.files.count == bodies.count)
        #expect(edition.data(for: "api/v1/newsletter/2026-11-13-evening.txt") == Data("Evening edition".utf8))
        #expect(edition.data(for: "api/v1/search/a.json") == nil)
        #expect(edition.data(for: "../etc/passwd") == nil)
        #expect(!site.requests.contains("api/v1/search/a.json"))
        // A fresh instance reads the record back from disk.
        let again = OfflineEdition(files: files, fetch: { try site.fetch($0) }, clock: { now })
        #expect(again.saved == saved)
    }

    @Test("A file that does not match its hash changes nothing")
    @MainActor func mismatch() async throws {
        let site = FakeSite(manifest: manifestJSON())
        let files = tempFiles()
        defer { files.delete() }
        let edition = OfflineEdition(files: files, fetch: { try site.fetch($0) }, clock: { now })
        #expect(await edition.save())
        let before = edition.saved
        site.tamper = "api/v1/since.json"
        #expect(await edition.save() == false)
        #expect(edition.saved == before)
        #expect(edition.state == .failed(OfflineError.hashMismatch("api/v1/since.json").text))
        #expect(edition.data(for: "api/v1/since.json") == Data(bodies["api/v1/since.json"]!.utf8))
    }

    @Test("It saves by itself only after a first save, 6 hours on, and not on mobile data or Low Data Mode")
    @MainActor func automatic() async throws {
        let site = FakeSite(manifest: manifestJSON())
        let files = tempFiles()
        defer { files.delete() }
        let box = CostBox()
        let clockBox = ClockBox(now)
        let edition = OfflineEdition(files: files, fetch: { try site.fetch($0) },
                                     cost: { box.value }, clock: { clockBox.value })
        await edition.refreshIfFree()
        #expect(edition.saved == nil)                     // never saved by hand: nothing automatic
        #expect(await edition.save())
        site.requests.removeAll()
        clockBox.value = now.addingTimeInterval(7 * 3600)
        box.value = NetworkCost(expensive: true, constrained: false, online: true)
        await edition.refreshIfFree()
        #expect(site.requests.isEmpty)                    // mobile data
        #expect(await edition.onMobileData())
        box.value = NetworkCost(expensive: false, constrained: true, online: true)
        await edition.refreshIfFree()
        #expect(site.requests.isEmpty)                    // Low Data Mode
        box.value = NetworkCost(expensive: false, constrained: false, online: true)
        clockBox.value = now.addingTimeInterval(3600)
        await edition.refreshIfFree()
        #expect(site.requests.isEmpty)                    // too soon
        clockBox.value = now.addingTimeInterval(7 * 3600)
        await edition.refreshIfFree()
        #expect(site.requests.contains("api/v1/manifest.json"))
        #expect(edition.saved?.savedAt == now.addingTimeInterval(7 * 3600))
    }

    @Test("Delete removes the files and the record")
    @MainActor func delete() async {
        let site = FakeSite(manifest: manifestJSON())
        let files = tempFiles()
        let edition = OfflineEdition(files: files, fetch: { try site.fetch($0) }, clock: { now })
        #expect(await edition.save())
        edition.delete()
        #expect(edition.saved == nil)
        #expect(files.record() == nil)
        #expect(edition.data(for: "api/v1/since.json") == nil)
    }

    @Test("With no network and no device copy, the places reader falls back to the saved edition")
    @MainActor func placesFallback() async {
        let site = FakeSite(manifest: manifestJSON())
        let files = tempFiles()
        defer { files.delete() }
        let edition = OfflineEdition(files: files, fetch: { try site.fetch($0) }, clock: { now })
        #expect(await edition.save())
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString)")
        let store = LocalStore(fetch: { _ in throw URLError(.notConnectedToInternet) },
                               cache: LocalDiskCache(directory: cacheDir), bundle: LocalResources.bundle, edition: files)
        await store.refreshPlaces()
        #expect(store.site("faro")?.updated == "2026-11-25")
        #expect(store.placeProvenance.isLive == false)
    }

    @Test("Text: day and size")
    func text() {
        let utc = TimeZone(identifier: "UTC")!
        #expect(OfflineEditionText.day(now, now: now, timeZone: utc) == "26 Nov, 03:00")
        let saved = SavedEdition(version: "v1", savedAt: now, files: [])
        #expect(OfflineEditionText.detail(saved).hasPrefix("Edition v1 · 0 files"))
    }
}

private final class CostBox: @unchecked Sendable {
    var value = NetworkCost(expensive: false, constrained: false, online: true)
}

private final class ClockBox: @unchecked Sendable {
    var value: Date
    init(_ value: Date) { self.value = value }
}
