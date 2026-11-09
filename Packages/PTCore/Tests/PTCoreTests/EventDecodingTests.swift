import Foundation
import Testing
@testable import PTCore

@Suite("Event decoding")
struct EventDecodingTests {
    private func json(_ extra: String = "") -> Data {
        Data("""
        {"date":"2026-11-10","time":"10:00-10:30","title":"Opening","place":"Stage 1","kind":"talk","official":true,
         "page":"events/opening/index.html"\(extra)}
        """.utf8)
    }

    @Test("An event without shows_as still decodes, with showsAs nil (older feeds)")
    func withoutShowsAs() throws {
        let event = try JSONDecoder().decode(Event.self, from: json())
        #expect(event.title == "Opening")
        #expect(event.showsAs == nil)
    }

    @Test("shows_as is read as showsAs, for free and busy")
    func withShowsAs() throws {
        let busy = try JSONDecoder().decode(Event.self, from: json(#","shows_as":"busy""#))
        #expect(busy.showsAs == "busy")
        let free = try JSONDecoder().decode(Event.self, from: json(#","shows_as":"free""#))
        #expect(free.showsAs == "free")
    }

    @Test("The memberwise init needs no showsAs, and showsAs survives an encode and decode round trip")
    func initAndRoundTrip() throws {
        let plain = Event(date: "2026-11-10", time: "10:00-10:30", title: "A", place: "P", kind: "talk", official: true,
                          page: "events/a/index.html")
        #expect(plain.showsAs == nil)
        let busy = Event(date: "2026-11-10", time: "10:00-10:30", title: "A", place: "P", kind: "talk", official: true,
                         page: "events/a/index.html", showsAs: "busy")
        let data = try JSONEncoder().encode(busy)
        #expect(String(decoding: data, as: UTF8.self).contains(#""shows_as":"busy""#))
        #expect(try JSONDecoder().decode(Event.self, from: data) == busy)
    }
}
