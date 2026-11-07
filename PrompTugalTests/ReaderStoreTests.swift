import Foundation
import Testing
@testable import PrompTugal

@Suite("Reader store: offline cache")
struct ReaderStoreTests {
    @Test("Details under the limit are kept as they are")
    func underLimit() {
        let details = ["a": 1, "b": 2]
        #expect(ReaderStore.trimmed(details, keeping: [], limit: 5) == details)
    }

    @Test("Over the limit, the kept ids stay first, then the rest by id")
    func overLimit() {
        let details = Dictionary(uniqueKeysWithValues: (0..<10).map { ("s\($0)", $0) })
        let trimmed = ReaderStore.trimmed(details, keeping: ["s9", "s7", "missing", "s9"], limit: 4)
        #expect(trimmed.count == 4)
        #expect(Set(trimmed.keys) == ["s9", "s7", "s0", "s1"])
    }

    @Test("The default limit bounds the cache")
    func defaultLimit() {
        let details = Dictionary(uniqueKeysWithValues: (0..<1_000).map { ("s\($0)", $0) })
        #expect(ReaderStore.trimmed(details, keeping: []).count == ReaderStore.maxDetails)
    }
}
