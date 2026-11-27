import Foundation
import Testing
@testable import PTNowNext

@Suite("My town snapshot")
struct MyTownSnapshotTests {
    @Test func roundTripsThroughJSON() throws {
        let snapshot = MyTownSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_764_201_600), origin: "cached",
            towns: [.init(id: "loule", name: "Loulé", story: .init(title: "A story", date: "2026-11-26",
                                                                     outlet: "Sul Informação", url: URL(string: "https://example.org/a")!)),
                    .init(id: "lagos", name: "Lagos", story: nil)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(MyTownSnapshot.self, from: encoder.encode(snapshot))
        #expect(back == snapshot)
        #expect(back.towns[1].story == nil)
    }
}
