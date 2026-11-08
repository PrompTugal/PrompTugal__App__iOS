import Foundation
import Testing
@testable import PTSync

@Suite("PTSync: sync engine and content store")
struct SyncEngineTests {
    private func makeSite() -> FakeSite {
        let site = FakeSite()
        site.set("api/a.json", "A1")
        site.set("api/b.json", "B1")
        site.set("big/c.json", "C1")
        return site
    }

    private let manifestPath = "api/v1/manifest.json"

    @Test("First sync fetches only the wanted pack, verifies it and switches to generation 1")
    func firstSync() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)

        let report = try await engine.sync([.core])
        #expect(report.switched && report.generation == 1)
        #expect(report.downloaded == 2 && report.added == 2 && report.failures.isEmpty)
        #expect(report.bytes == 4)
        #expect(report.version == "v1")
        #expect(store.entries.map(\.path) == ["api/a.json", "api/b.json"])
        #expect(store.data(at: "api/a.json") == Data("A1".utf8))
        #expect(store.data(at: "big/c.json") == nil, "the full pack was not asked for")
        #expect(site.requestCount(for: "big/c.json") == 0)
        #expect(store.syncedAt != nil && !store.isFromSeed)
    }

    @Test("A later sync for more packs fetches only the new pack")
    func morePacks() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])
        let report = try await engine.sync([.core, .full])
        #expect(report.notModified, "the manifest did not change")
        #expect(report.switched && report.generation == 2)
        #expect(report.downloaded == 1)
        #expect(site.requestCount(for: "api/a.json") == 1, "files already held are not fetched again")
        #expect(store.data(at: "big/c.json") == Data("C1".utf8))
    }

    @Test("Nothing changed: one manifest request (304), no files, no new generation, but the check time moves")
    func upToDate() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let clock = FakeClock(1_000)
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store, now: { clock.now() })
        _ = try await engine.sync([.core])
        site.clearRequests()
        clock.advance(300)
        let report = try await engine.sync([.core])
        #expect(report.notModified && !report.switched && report.isUpToDate)
        #expect(site.totalRequests == 1)
        #expect(store.generation == 1)
        #expect(store.syncedAt == Date(timeIntervalSince1970: 1_300))
        let reopened = ContentStore(source: testSource, directory: dir.url)
        #expect(reopened.syncedAt == Date(timeIntervalSince1970: 1_300), "the time is kept on disk")
    }

    @Test("A changed file is fetched alone; a snapshot taken before keeps the old bytes")
    func changedFile() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])
        let before = store.snapshot()

        site.set("api/a.json", "A2")
        site.setVersion("v2")
        let report = try await engine.sync([.core])
        #expect(!report.notModified && report.switched && report.generation == 2)
        #expect(report.changed == 1 && report.downloaded == 1 && report.added == 0)
        #expect(site.requestCount(for: "api/b.json") == 1)
        #expect(store.data(at: "api/a.json") == Data("A2".utf8))
        #expect(before.data(at: "api/a.json") == Data("A1".utf8), "a screen holding a snapshot never sees a mix")
        #expect(before.generation == 1 && store.snapshot().generation == 2)
    }

    @Test("A file the site removed is gone after the switch")
    func removedFile() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])
        site.remove("api/b.json")
        let report = try await engine.sync([.core])
        #expect(report.removed == 1 && report.switched)
        #expect(store.data(at: "api/b.json") == nil)
        #expect(store.data(at: "api/a.json") != nil)
    }

    @Test("A download that fails once is tried again")
    func retries() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        site.fail("api/a.json", times: 1)
        let store = ContentStore(source: testSource, directory: dir.url)
        let report = try await makeEngine(site: site, store: store).sync([.core])
        #expect(report.switched && report.failures.isEmpty)
        #expect(site.requestCount(for: "api/a.json") == 2)
    }

    @Test("When a file keeps failing nothing is switched, the others are kept, and the next sync fetches only the missing one")
    func halfDoneNeverShows() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])                       // generation 1 holds A1 and B1
        site.set("api/a.json", "A2")
        site.set("api/b.json", "B2")
        site.setVersion("v2")
        site.fail("api/a.json", times: 10)

        let failed = try await engine.sync([.core])
        #expect(failed.failures == ["api/a.json"] && !failed.switched)
        #expect(store.generation == 1)
        #expect(store.data(at: "api/a.json") == Data("A1".utf8), "the live generation did not change")
        #expect(store.data(at: "api/b.json") == Data("B1".utf8), "not even the file that did download")

        site.fail("api/a.json", times: 0)
        let healed = try await engine.sync([.core])
        #expect(healed.switched && healed.generation == 2)
        #expect(site.requestCount(for: "api/b.json") == 2, "B2 was kept from the failed run, not fetched again (A1 + B1 + B2 = two B requests)")
        #expect(store.data(at: "api/a.json") == Data("A2".utf8) && store.data(at: "api/b.json") == Data("B2".utf8))
    }

    @Test("Wrong bytes, right size: refused, never stored")
    func hashMismatch() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        site.corrupt("api/a.json")
        let store = ContentStore(source: testSource, directory: dir.url)
        let report = try await makeEngine(site: site, store: store).sync([.core])
        #expect(report.failures == ["api/a.json"] && !report.switched)
        #expect(!store.hasObject(SHA256Hex.of(Data("A1".utf8))))
        #expect(store.data(at: "api/a.json") == nil)
        #expect(site.requestCount(for: "api/a.json") == 2, "tried once more")
    }

    @Test("More bytes than the manifest says: refused")
    func sizeMismatch() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        site.oversize("api/a.json")
        let store = ContentStore(source: testSource, directory: dir.url)
        let report = try await makeEngine(site: site, store: store).sync([.core])
        #expect(report.failures == ["api/a.json"] && !report.switched)
    }

    @Test("Unsafe manifest entries are dropped and counted; files the rules skip are never requested")
    func unsafeAndSkipped() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        site.set("../evil.json", "x")
        site.set("skip/x.json", "y")
        let store = ContentStore(source: testSource, directory: dir.url)
        let report = try await makeEngine(site: site, store: store).sync([.core, .full])
        #expect(report.rejectedEntries == 1)
        #expect(site.requestCount(for: "../evil.json") == 0 && site.requestCount(for: "evil.json") == 0)
        #expect(site.requestCount(for: "skip/x.json") == 0)
        #expect(store.entries.map(\.path) == ["api/a.json", "api/b.json", "big/c.json"])
    }

    @Test("An expensive or constrained connection leaves the big packs for later")
    func networkGating() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let metered = try await makeEngine(site: site, store: store, path: FakePath(isExpensive: true)).sync([.core, .full])
        #expect(metered.skippedPacks == [.full] && metered.switched)
        #expect(site.requestCount(for: "big/c.json") == 0)
        let lowData = try await makeEngine(site: site, store: store, path: FakePath(isConstrained: true)).sync([.core, .full])
        #expect(lowData.skippedPacks == [.full])
        let wifi = try await makeEngine(site: site, store: store, path: FakePath()).sync([.core, .full])
        #expect(wifi.skippedPacks.isEmpty && wifi.switched)
        #expect(store.data(at: "big/c.json") == Data("C1".utf8))
    }

    @Test("A bad answer for the manifest throws and changes nothing")
    func badManifestStatus() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        site.overrideManifestStatus(500)
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        await #expect(throws: SyncError.badStatus(500)) { try await engine.sync([.core]) }
        #expect(store.generation == 0)
    }

    @Test("Two syncs asked for at once share one run")
    func joins() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        async let first = engine.sync([.core])
        async let second = engine.sync([.core])
        let (one, two) = try await (first, second)
        #expect(one == two)
        #expect(site.requestCount(for: manifestPath) == 1)
    }

    @Test("Status updates tell the app what is happening")
    func statusUpdates() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        let stream = engine.statusUpdates()
        let collector = Task { () -> [SyncStatus] in
            var seen: [SyncStatus] = []
            for await status in stream {
                seen.append(status)
                if case .switched = status { break }
            }
            return seen
        }
        _ = try await engine.sync([.core])
        let seen = await collector.value
        #expect(seen.contains(.fetchingManifest))
        #expect(seen.contains(.downloading(done: 2, total: 2)))
        #expect(seen.last == .switched(generation: 1))
    }

    @Test("A seed gives the first launch its files; only files that verify are used; the first sync fetches the difference")
    func seed() async throws {
        let dir = TempDir()
        let seedDir = TempDir()
        defer { dir.cleanup(); seedDir.cleanup() }
        let site = makeSite()
        // The seed is the site as it was at build time: manifest.json and each file at its path.
        try site.manifestData().write(to: seedDir.url.appendingPathComponent("manifest.json"))
        for (path, content) in [("api/a.json", "A1"), ("api/b.json", "XX"), ("big/c.json", "C1")] {   // b is damaged (right size, wrong bytes)
            let file = seedDir.url.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: file)
        }
        try FileManager.default.removeItem(at: seedDir.url.appendingPathComponent("big/c.json"))    // c is missing

        let store = ContentStore(source: testSource, directory: dir.url, seed: seedDir.url)
        #expect(store.generation == 1 && store.isFromSeed && store.syncedAt == nil)
        #expect(store.entries.map(\.path) == ["api/a.json"])
        #expect(store.data(at: "api/a.json") == Data("A1".utf8))
        #expect(store.data(at: "api/b.json") == nil)

        let report = try await makeEngine(site: site, store: store).sync([.core, .full])
        #expect(report.switched && report.generation == 2)
        #expect(report.downloaded == 2, "b and c")
        #expect(site.requestCount(for: "api/a.json") == 0, "a came with the build")
        #expect(!store.isFromSeed && store.syncedAt != nil)
        #expect(store.entries.count == 3)
    }

    @Test("A store reopened from disk has the same generation and files")
    func persistence() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])
        _ = try await engine.sync([.core, .full])
        let reopened = ContentStore(source: testSource, directory: dir.url)
        #expect(reopened.generation == 2 && reopened.version == "v1")
        #expect(reopened.data(at: "big/c.json") == Data("C1".utf8))
        #expect(reopened.entries == store.entries)
    }

    @Test("Old generations and files nothing refers to are removed; the two newest generations stay")
    func pruning() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url, pruneGrace: 0)
        let engine = makeEngine(site: site, store: store)
        _ = try await engine.sync([.core])
        for version in 2...3 {
            site.set("api/a.json", "A\(version)")
            site.setVersion("v\(version)")
            _ = try await engine.sync([.core])
        }
        #expect(store.generation == 3)
        func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: store.root.appendingPathComponent(name).path) }
        #expect(!exists("gen-1.json") && exists("gen-2.json") && exists("gen-3.json"))
        #expect(!store.hasObject(SHA256Hex.of(Data("A1".utf8))), "only generation 1 used it")
        #expect(store.hasObject(SHA256Hex.of(Data("A2".utf8))) && store.hasObject(SHA256Hex.of(Data("A3".utf8))))
        #expect(store.data(at: "api/a.json") == Data("A3".utf8))
    }

    @Test("The loader closure other packages take reads from the live generation")
    func loaderClosure() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = makeSite()
        let store = ContentStore(source: testSource, directory: dir.url)
        let load = store.loader
        #expect(load("api/a.json") == nil)
        _ = try await makeEngine(site: site, store: store).sync([.core])
        #expect(load("api/a.json") == Data("A1".utf8))
        #expect(store.fileURL(for: "api/a.json") != nil && store.fileURL(for: "nope.json") == nil)
    }
}
