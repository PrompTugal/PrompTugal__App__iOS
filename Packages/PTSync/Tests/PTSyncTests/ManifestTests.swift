import Foundation
import Testing
@testable import PTSync

@Suite("PTSync: manifest, paths, packs")
struct ManifestTests {
    private func json(_ files: [[String: Any]], extra: [String: Any] = [:]) -> Data {
        var object: [String: Any] = ["version": "v9", "about": "x", "count": files.count, "files": files]
        for (key, value) in extra { object[key] = value }
        return try! JSONSerialization.data(withJSONObject: object)
    }

    private let good = ["path": "api/v1/days.json", "bytes": 5, "sha256": String(repeating: "a", count: 64), "schema": NSNull(), "feature": "days"] as [String: Any]

    @Test("The real manifest's shape reads: extra keys are ignored, feature is optional")
    func readsRealShape() throws {
        let noFeature: [String: Any] = ["path": "api/v1/x.json", "bytes": 1, "sha256": String(repeating: "b", count: 64)]
        let parsed = try Manifest.parse(json([good, noFeature], extra: ["unknown": [1, 2, 3]]))
        #expect(parsed.manifest.version == "v9")
        #expect(parsed.manifest.files.map(\.path) == ["api/v1/days.json", "api/v1/x.json"])
        #expect(parsed.manifest.files[0].feature == "days")
        #expect(parsed.manifest.files[1].feature == nil)
        #expect(parsed.rejected == 0)
    }

    @Test("Malformed and unsafe entries are dropped and counted; a repeated path keeps the last")
    func dropsBadEntries() throws {
        let files: [[String: Any]] = [
            good,
            ["path": "api/v1/days.json", "bytes": 7, "sha256": String(repeating: "c", count: 64)],       // repeat
            ["path": "../etc/passwd", "bytes": 1, "sha256": String(repeating: "a", count: 64)],            // unsafe
            ["path": "api/v1/up.json", "bytes": 1, "sha256": String(repeating: "A", count: 64)],           // upper case digest
            ["path": "api/v1/short.json", "bytes": 1, "sha256": "abc"],                                    // short digest
            ["path": "api/v1/neg.json", "bytes": -1, "sha256": String(repeating: "a", count: 64)],         // negative size
            ["path": "api/v1/huge.json", "bytes": SyncLimits.maxFileBytes + 1, "sha256": String(repeating: "a", count: 64)],
            ["bytes": 1, "sha256": String(repeating: "a", count: 64)],                                     // no path
            ["path": 5, "bytes": 1, "sha256": String(repeating: "a", count: 64)],                          // wrong type
        ]
        let parsed = try Manifest.parse(json(files))
        #expect(parsed.manifest.files.count == 1)
        #expect(parsed.manifest.files[0].bytes == 7, "the later entry for a path wins")
        #expect(parsed.rejected == 7)
    }

    @Test("Not JSON, a missing files list, and too many files all fail")
    func rejectsBrokenManifests() {
        #expect(throws: SyncError.manifestInvalid) { try Manifest.parse(Data("nope".utf8)) }
        #expect(throws: SyncError.manifestInvalid) { try Manifest.parse(Data("{\"version\":\"v1\"}".utf8)) }
        let many = (0...SyncLimits.maxFiles).map { ["path": "f/\($0).json", "bytes": 1, "sha256": String(repeating: "a", count: 64)] as [String: Any] }
        #expect(throws: SyncError.manifestTooLarge) { try Manifest.parse(json(many)) }
        #expect(throws: SyncError.manifestTooLarge) { try Manifest.parse(Data(count: SyncLimits.maxManifestBytes + 1)) }
    }

    @Test("Paths: plain segments pass; anything that could leave the site does not")
    func pathSafety() {
        for path in ["api/v1/days.json", "a.json", "dir/with space/file.json", "a/b/c/d.txt"] {
            #expect(SyncPath.isSafe(path), "\(path)")
        }
        for path in ["", "/abs", "../x", "a/../b", "a/./b", "a//b", "a/", "a\\b", "https://evil.test/x", "javascript:alert(1)",
                     "a?x=1", "a#frag", "a%2e%2e/b", "a\u{0}b", String(repeating: "a", count: 600)] {
            #expect(!SyncPath.isSafe(path), "\(path)")
        }
    }

    @Test("URLs are built under the base, https only, and unsafe paths give none")
    func sourceURLs() throws {
        let source = SyncSource(id: "t", base: URL(string: "https://example.test")!)
        #expect(source.base.absoluteString == "https://example.test/")
        #expect(source.url(for: "api/v1/a.json")?.absoluteString == "https://example.test/api/v1/a.json")
        #expect(source.url(for: "dir/with space.json")?.absoluteString == "https://example.test/dir/with%20space.json")
        #expect(source.url(for: "../a.json") == nil)
        #expect(source.url(for: "https://evil.test/a.json") == nil)
        #expect(source.manifestURL?.absoluteString == "https://example.test/api/v1/manifest.json")
        let http = SyncSource(id: "h", base: URL(string: "http://example.test/")!)
        #expect(http.url(for: "a.json") == nil, "http is refused")
        #expect(SyncSource.promptugalNews.manifestURL?.absoluteString == "https://promptugal.news/api/v1/manifest.json")
    }

    @Test("promptugal.news packs: indexes and event pages are core, the graph and entity pages are full, browser files never")
    func newsPacks() {
        func pack(_ path: String) -> SyncPack? {
            PackRules.promptugalNews.pack(for: ManifestEntry(path: path, bytes: 1, sha256: String(repeating: "a", count: 64)))
        }
        for path in ["api/v1/live/agenda.json", "api/v1/days.json", "api/v1/days/2026-11-10.json", "api/v1/events.json",
                     "api/v1/events/some-session.json", "api/v1/stories.json", "api/v1/stories/a.json", "api/v1/newsletter.json",
                     "api/v1/people.json", "api/v1/organisations.json", "api/v1/companies.json", "api/v1/places.json",
                     "api/v1/topics.json", "api/v1/index.json", "api/v1/ontology.json"] {
            #expect(pack(path) == .core, "\(path)")
        }
        for path in ["api/v1/graph/whole.json", "api/v1/search/a.json", "api/v1/people/dinis.json", "api/v1/companies/x.json",
                     "api/v1/newsroom/dashboard.json", "api/v1/triples.nt", "api/v1/search-docs.json"] {
            #expect(pack(path) == .full, "\(path)")
        }
        #expect(pack("sw.js") == nil)
        #expect(pack("api/v1/deploy-exclude.txt") == nil)
    }

    @Test("Diff: added, changed, removed and unchanged")
    func diff() {
        let current = ["a": entry("a", "1"), "b": entry("b", "2"), "gone": entry("gone", "3")]
        let next = [entry("a", "1"), entry("b", "22"), entry("new", "4")]
        let diff = ManifestDiff.between(current: current, next: next)
        #expect(diff.added == ["new"])
        #expect(diff.changed == ["b"])
        #expect(diff.removed == ["gone"])
        #expect(diff.unchanged == 1)
    }

    @Test("SHA-256 matches the standard test vector, and a file hashes the same as its bytes")
    func hashing() throws {
        #expect(SHA256Hex.of(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let dir = TempDir()
        defer { dir.cleanup() }
        let big = Data((0..<700_000).map { UInt8($0 % 251) })       // more than two read chunks
        let file = dir.url.appendingPathComponent("big.bin")
        try big.write(to: file)
        #expect(try SHA256Hex.of(fileAt: file) == SHA256Hex.of(big))
    }
}
