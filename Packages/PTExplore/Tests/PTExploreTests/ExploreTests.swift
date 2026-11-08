import Foundation
import Testing
@testable import PTExplore

private let docsJSON = """
{"version":"v0.1.700","count":6,"docs":[
 {"id":"event:startup-guide","url":"events/startup-guide/index.html","title":"A guide to Portugal's startup scene","type":"event","text":"session 2026-11-10 12:00-12:45 Masterclass 1 (Masterclasses), MEO Arena and FIL Masterclasses "},
 {"id":"event:opening-night","url":"events/opening-night/index.html","title":"Opening Night","type":"event","text":"summit 2026-11-09 18:00-20:00 Centre Stage"},
 {"id":"event:odd","url":"events/odd/index.html","title":"No time here","type":"event","text":"just words"},
 {"id":"person:joao-sao","url":"people/joao-sao/index.html","title":"João São Paulo","type":"person","text":"Co founder, CEO Skild AI"},
 {"id":"company:0xbow","url":"companies/0xbow/index.html","title":"0xbow","type":"company","text":"Plug-and-play on-chain privacy. United States grc"},
 {"id":"page:about","url":"about/index.html","title":"About","type":"site","text":"x"}
]}
"""

private let placesJSON = """
{"type":"place","count":2,"items":[
 {"id":"albufeira","label":"Albufeira","page":"https://promptugal.news/places/albufeira/index.html"},
 {"id":"masterclass-1","label":"Masterclass 1","page":"https://promptugal.news/places/masterclass-1/index.html"}
]}
"""

private let eventRecord = """
{"id":"startup-guide","type":"event","label":"A guide to Portugal's startup scene",
 "data":{"kind":"session","date":"2026-11-10","time":"12:00-12:45","where":"Masterclass 1","track":"Masterclasses"},
 "links":{"out":[{"verb":"organised_by","to":"organisation:web-summit","label":"Web Summit"},
                 {"verb":"organised_by","to":"organisation:web-summit","label":"Web Summit"},
                 {"verb":"bad","to":"nonsense:x","label":"Skipped"}],
          "in":[{"verb":"speaks_at","from":"person:joao-sao","label":"João São Paulo"}]}}
"""

private let base = URL(string: "https://promptugal.news")!

private func makeIndex() throws -> ExploreIndex {
    try ExploreWire.index(searchDocs: Data(docsJSON.utf8), places: Data(placesJSON.utf8), base: base)
}

@Suite("Reading the site's files")
struct WireTests {
    @Test("Docs and places become entries; other page types are left out")
    func index() throws {
        let index = try makeIndex()
        #expect(index.version == "v0.1.700")
        #expect(index.items.count == 7)
        #expect(Set(index.items.map(\.kind)) == [.event, .person, .company, .place])
        #expect(index.item(ref: "place:albufeira")?.title == "Albufeira")
    }

    @Test("A talk's line gives its day, times and place")
    func talk() throws {
        let talk = try #require(try makeIndex().item(ref: "event:startup-guide"))
        #expect(talk.day == "2026-11-10")
        #expect(talk.start == "12:00")
        #expect(talk.end == "12:45")
        #expect(talk.subtitle.hasPrefix("Masterclass 1"))
        #expect(talk.page?.absoluteString == "https://promptugal.news/events/startup-guide/index.html")
        #expect(talk.slug == "startup-guide")
    }

    @Test("A talk line without a time is kept, with no time")
    func talkWithoutTime() throws {
        let odd = try #require(try makeIndex().item(ref: "event:odd"))
        #expect(odd.day == nil)
        #expect(odd.text == "just words")
    }

    @Test("A broken file throws")
    func broken() {
        #expect(throws: (any Error).self) { _ = try ExploreWire.index(searchDocs: Data("{".utf8), places: nil, base: base) }
    }

    @Test("A broken places file does not lose the rest")
    func brokenPlaces() throws {
        let index = try ExploreWire.index(searchDocs: Data(docsJSON.utf8), places: Data("nope".utf8), base: base)
        #expect(index.items.count == 5)
    }
}

@Suite("Search")
struct SearchTests {
    @Test("Accents and case do not matter")
    func accents() throws {
        let hits = ExploreSearch.search(try makeIndex(), query: "SAO paulo")
        #expect(hits.map(\.id) == ["person:joao-sao"])
    }

    @Test("Title matches rank above matches in other text")
    func ranking() throws {
        let hits = ExploreSearch.search(try makeIndex(), query: "masterclass")
        #expect(hits.first?.id == "place:masterclass-1")
        #expect(hits.contains { $0.id == "event:startup-guide" })
    }

    @Test("Every word must match")
    func allWords() throws {
        #expect(ExploreSearch.search(try makeIndex(), query: "opening banana").isEmpty)
        #expect(ExploreSearch.search(try makeIndex(), query: "opening night").count == 1)
    }

    @Test("The kind filter limits the results; an empty query lists talks by time")
    func kindAndOrder() throws {
        let talks = ExploreSearch.search(try makeIndex(), query: "", kind: .event)
        #expect(talks.map(\.id) == ["event:opening-night", "event:startup-guide", "event:odd"])
        #expect(ExploreSearch.search(try makeIndex(), query: "bow", kind: .person).isEmpty)
        #expect(ExploreSearch.search(try makeIndex(), query: "bow", kind: .company).count == 1)
    }

    @Test("Counts per kind follow the query")
    func counts() throws {
        let counts = ExploreSearch.counts(try makeIndex(), query: "masterclass")
        #expect(counts[.place] == 1)
        #expect(counts[.person] == 0)
    }
}

@Suite("Lists")
struct ListTests {
    @MainActor @Test("People are grouped A to Z with accents folded, symbols last")
    func letters() throws {
        let items = [ExploreItem(id: "person:b", kind: .person, title: "Bea"),
                     ExploreItem(id: "person:a", kind: .person, title: "Álvaro"),
                     ExploreItem(id: "person:z", kind: .person, title: "0xbow"),
                     ExploreItem(id: "person:a2", kind: .person, title: "Ana")]
        let sections = ExploreStore.letterSections(items)
        #expect(sections.map(\.letter) == ["A", "B", "#"])
        #expect(sections[0].items.map(\.title) == ["Álvaro", "Ana"])
    }

    @MainActor @Test("A search groups results by kind and skips kinds with no hits")
    func grouped() async throws {
        let store = ExploreStore(source: StubSource(stored: try makeIndex()))
        await store.load()
        store.query = "masterclass"
        #expect(store.grouped().map(\.kind) == [.event, .place])
        #expect(store.isSearching)
    }

    @Test("The speakers of a talk are the people who speak at it")
    func speakers() throws {
        let detail = try ExploreDetail.decode(Data(eventRecord.utf8), kind: .event)
        #expect(detail.speakers.map(\.label) == ["João São Paulo"])
        #expect(detail.otherLinks.map(\.label) == ["Web Summit"])
    }
}

private struct StubSource: ExploreSource {
    var stored: ExploreIndex
    func index() async throws -> ExploreIndex { stored }
    func detail(for item: ExploreItem) async throws -> ExploreDetail { throw URLError(.badURL) }
}

@Suite("Detail and offline")
struct DetailTests {
    @Test("A record gives its facts and de-duplicated, known links")
    func detail() throws {
        let detail = try ExploreDetail.decode(Data(eventRecord.utf8), kind: .event)
        #expect(detail.facts.map(\.label) == ["Kind", "Day", "Time", "Where", "Track"])
        #expect(detail.links.count == 2)
        #expect(detail.links[0].verb == "organised by")
        #expect(detail.links[1].verb == "← speaks at")
        #expect(detail.links[1].ref == "person:joao-sao")
    }

    @Test("The index is read again offline, from disk")
    func offline() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ptexplore-\(UUID().uuidString)")
        let cache = ExploreDiskCache(directory: dir)
        defer { cache.clear() }
        let online = PublishedExploreSource(base: base, cache: cache, fetch: { url in
            if url.lastPathComponent == "search-docs.json" { return Data(docsJSON.utf8) }
            if url.lastPathComponent == "places.json" { return Data(placesJSON.utf8) }
            return Data(eventRecord.utf8)
        })
        let first = try await online.index()
        _ = try await online.detail(for: try #require(first.item(ref: "event:startup-guide")))

        let offline = PublishedExploreSource(base: base, cache: cache, fetch: { _ in throw URLError(.notConnectedToInternet) })
        let again = try await offline.index()
        #expect(again.items.count == first.items.count)
        let detail = try await offline.detail(for: try #require(again.item(ref: "event:startup-guide")))
        #expect(detail.links.count == 2)
    }

    @Test("Offline with nothing stored throws")
    func offlineEmpty() async {
        let cache = ExploreDiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ptexplore-\(UUID().uuidString)"))
        let source = PublishedExploreSource(base: base, cache: cache, fetch: { _ in throw URLError(.notConnectedToInternet) })
        await #expect(throws: URLError.self) { _ = try await source.index() }
    }
}
