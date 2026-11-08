import Foundation
import Testing
@testable import PTCore

private struct FakeSource: ContentSource {
    let files: [String: Data]
    let generation: Int
    func data(at path: String) -> Data? { files[path] }
}

@Suite("Content sources", .serialized)
struct ContentSourceTests {
    @Test("A registered source is found by site id, replaced by a later one, and removed")
    func registry() {
        defer { ContentSources.unregister("test.site") }
        #expect(ContentSources.source(for: "test.site") == nil)
        ContentSources.register(FakeSource(files: ["a.json": Data("1".utf8)], generation: 1), for: "test.site")
        #expect(ContentSources.source(for: "test.site")?.data(at: "a.json") == Data("1".utf8))
        #expect(ContentSources.source(for: "other.site") == nil)
        ContentSources.register(FakeSource(files: [:], generation: 2), for: "test.site")
        #expect(ContentSources.source(for: "test.site")?.generation == 2)
        #expect(ContentSources.source(for: "test.site")?.data(at: "a.json") == nil)
        ContentSources.unregister("test.site")
        #expect(ContentSources.source(for: "test.site") == nil)
    }
}
