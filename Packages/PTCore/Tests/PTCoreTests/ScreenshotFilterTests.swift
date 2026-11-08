import Foundation
import Testing
@testable import PTCore

@Suite("Screenshot filter")
struct ScreenshotFilterTests {
    private func event(_ title: String, place: String = "Hall 1") -> Event {
        Event(date: "2026-11-09", time: "10:00-11:00", title: title, place: place, kind: "talk", official: true,
              page: "events/\(abs(title.hashValue))/index.html")
    }

    private func story(_ title: String) -> Story {
        Story(id: title, title: title, summary: "", category: "news", published: nil, url: URL(string: "https://promptugal.news/")!)
    }

    @Test("no term keeps everything")
    func noTerm() {
        #expect(ScreenshotFilter.keep("Web Summit registration", hiding: nil))
        #expect(ScreenshotFilter.keep("Web Summit registration", hiding: ""))
        let all = [event("Web Summit registration"), event("Keynote")]
        #expect(ScreenshotFilter.events(all, hiding: nil) == all)
    }

    @Test("the term is matched case-insensitively in any of the texts")
    func matching() {
        #expect(!ScreenshotFilter.keep("Doors", "at the WEB summit venue", hiding: "web summit"))
        #expect(ScreenshotFilter.keep("Keynote", "Hall 1", hiding: "web summit"))
    }

    @Test("events are dropped by title or place, stories by title")
    func filtering() {
        let events = [event("Registration: Web Summit lanyard"), event("Keynote", place: "Web Summit Hall"), event("Panel")]
        #expect(ScreenshotFilter.events(events, hiding: "web summit").map(\.title) == ["Panel"])
        let stories = [story("Web Summit opens"), story("Lisbon weather")]
        #expect(ScreenshotFilter.stories(stories, hiding: "WEB SUMMIT").map(\.title) == ["Lisbon weather"])
    }
}
