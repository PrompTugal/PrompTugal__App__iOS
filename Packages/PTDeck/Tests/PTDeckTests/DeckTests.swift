import Foundation
import Testing
@testable import PTDeck

private let deckJSON = """
{"id":"1-the-investment-case","lang":"pt","title":"A tese de investimento","summary":"Porquê investir","version":"v0.1.697",
 "slides":[
  {"title":"Capa","body":"Uma linha","image":"https://promptugal.news/img/a.jpg","notes":"Dizer olá"},
  {"title":"O problema","body":"**Sem anúncios**\\nTexto"},
  {"title":"Sem corpo"}
 ]}
"""

private let catalogJSON = """
{"version":"v0.1.697","decks":[
 {"id":"0-the-map","number":"0","title":{"en":"The map","pt":"O mapa"},"summary":{"en":"Start here"},
  "cover":"/board/cover.jpg","languages":["en","pt","xx"]},
 {"id":"2-the-industry","title":"The industry","languages":["en"]}
]}
"""

private let listHTML = """
<article class="dc"><a class="dc-img" href="../../investors/decks/0-the-map/index.html"><img src="x.jpg"></a>
<div class="dc-b"><p class="dc-n">0</p><h3><a href="../../investors/decks/0-the-map/index.html">The map of the decks</a></h3><p>Start here: how the nine decks fit together</p>
<p class="dc-a"><a href="x">Open →</a></p></div></article>
<article class="dc"><div class="dc-b"><p class="dc-n">1</p><h3><a href="../../investors/decks/1-the-investment-case/index.html">The investment case</a></h3><p>Investors &amp; partners</p></div></article>
"""

private let markdown = """
# PrompTugal: the investment case

> Why invest.

*Source: <https://x>*

---

[Download the PDF](../../board/deck.pdf)

## The next generation is running.
A newsroom of people and agents.

## The problem
### The reader was the product
Since 1833.
### Then it went to rent
Subscriptions.
"""

private let page = """
<main><section class="slide pic"><img class="bg" src="../../../board/hero.jpg"></section>
<section class="slide v"><h2>x</h2></section></main>
"""

private struct FakeSource: DeckSource {
    var failing: Set<DeckLanguage> = []
    var offline = false
    func catalog() async throws -> DeckCatalog {
        if offline { throw URLError(.notConnectedToInternet) }
        return DeckCatalog(version: "v1", decks: [DeckSummary(id: "d", title: LocalizedText(["en": "D"]))])
    }
    func deck(id: String, language: DeckLanguage) async throws -> Deck {
        if offline || failing.contains(language) { throw URLError(.notConnectedToInternet) }
        return Deck(id: id, language: language, title: "T-\(language.rawValue)", slides: [DeckSlide(title: "S")])
    }
}

private func tempCache() -> DeckDiskCache {
    DeckDiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ptdeck-\(UUID().uuidString)"))
}

@Suite("Deck decoding")
struct DecodingTests {
    @Test("A deck decodes with its slides, notes and numbering")
    func deck() throws {
        let deck = try JSONDecoder().decode(Deck.self, from: Data(deckJSON.utf8))
        #expect(deck.language == .pt)
        #expect(deck.slides.count == 3)
        #expect(deck.slides.map(\.index) == [0, 1, 2])
        #expect(deck.slides[0].notes == "Dizer olá")
        #expect(deck.slides[0].image?.absoluteString == "https://promptugal.news/img/a.jpg")
        #expect(deck.slides[2].body == "")
        #expect(deck.slides[2].image == nil)
    }

    @Test("A deck survives encode and decode")
    func roundTrip() throws {
        let deck = try JSONDecoder().decode(Deck.self, from: Data(deckJSON.utf8))
        let again = try JSONDecoder().decode(Deck.self, from: JSONEncoder().encode(deck))
        #expect(again == deck)
    }

    @Test("The catalog accepts a plain string or a language map, and drops unknown languages")
    func catalog() throws {
        let catalog = try JSONDecoder().decode(DeckCatalog.self, from: Data(catalogJSON.utf8))
        #expect(catalog.decks.count == 2)
        #expect(catalog.decks[0].languages == [.en, .pt])
        #expect(catalog.decks[0].title.text(in: .pt) == "O mapa")
        #expect(catalog.decks[1].title.text(in: .fr) == "The industry")
    }

    @Test("A relative cover path is made absolute against the file")
    func resolve() {
        let base = URL(string: "https://promptugal.news/api/v1/decks/index.json")!
        #expect(HTTPDeckSource.resolve(URL(string: "/board/cover.jpg")!, against: base)?.absoluteString
                == "https://promptugal.news/board/cover.jpg")
    }
}

@Suite("Site pages")
struct SiteParserTests {
    @Test("The list page gives id, number, title and summary")
    func list() {
        let entries = SiteDeckParser.listEntries(html: listHTML)
        #expect(entries.map(\.id) == ["0-the-map", "1-the-investment-case"])
        #expect(entries[0].number == "0")
        #expect(entries[0].title == "The map of the decks")
        #expect(entries[1].summary == "Investors & partners")
    }

    @Test("The Markdown twin gives one slide per heading, with sub-headings in bold")
    func markdownDeck() throws {
        let deck = try #require(SiteDeckParser.deck(markdown: markdown, id: "1", language: .en))
        #expect(deck.title == "PrompTugal: the investment case")
        #expect(deck.summary == "Why invest.")
        #expect(deck.slides.map(\.title) == ["The next generation is running.", "The problem"])
        #expect(deck.slides[0].body == "A newsroom of people and agents.")
        #expect(deck.slides[1].body.contains("**The reader was the product**\nSince 1833."))
    }

    @Test("Slide images come from each slide block, in order")
    func images() {
        let images = SiteDeckParser.slideImages(html: page, pageURL: URL(string: "https://promptugal.news/investors/decks/1/index.html")!)
        #expect(images.count == 2)
        #expect(images[0]?.absoluteString == "https://promptugal.news/board/hero.jpg")
        #expect(images[1] == nil)
    }

    @Test("Markdown without slides is not a deck")
    func empty() {
        #expect(SiteDeckParser.deck(markdown: "# T\n\n---\nnothing", id: "x", language: .en) == nil)
    }
}

@Suite("Language fallback")
struct LanguageTests {
    @Test("Preferred language wins, then English, then the first available")
    func resolve() {
        #expect(DeckLanguage.resolve(.pt, available: [.en, .pt]) == .pt)
        #expect(DeckLanguage.resolve(.fr, available: [.es, .en]) == .en)
        #expect(DeckLanguage.resolve(.fr, available: [.es, .pt]) == .pt)
        #expect(DeckLanguage.resolve(.fr, available: []) == nil)
    }

    @Test("The device language picks a supported language, else English")
    func device() {
        #expect(DeckLanguage.deviceDefault(preferredLanguages: ["pt-PT", "en"]) == .pt)
        #expect(DeckLanguage.deviceDefault(preferredLanguages: ["de-DE", "fr-FR"]) == .fr)
        #expect(DeckLanguage.deviceDefault(preferredLanguages: ["ja"]) == .en)
    }

    @Test("A failing language falls through to English")
    func loaderFallback() async throws {
        let source = FakeSource(failing: [.fr])
        let deck = try await source.deck(id: "d", preferring: .fr, available: [.en, .fr])
        #expect(deck.language == .en)
    }

    @Test("A deck with no languages throws")
    func none() async {
        await #expect(throws: DeckError.self) {
            _ = try await FakeSource().deck(id: "d", preferring: .en, available: [])
        }
    }
}

@Suite("Offline cache")
struct CacheTests {
    @Test("The disk cache keeps what it is given")
    func disk() {
        let cache = tempCache()
        defer { cache.clear() }
        #expect(cache.load(key: "a/b") == nil)
        cache.store(Data("hi".utf8), key: "a/b")
        #expect(cache.load(key: "a/b") == Data("hi".utf8))
    }

    @Test("A deck read online is read again offline")
    func offline() async throws {
        let cache = tempCache()
        defer { cache.clear() }
        _ = try await CachedDeckSource(source: FakeSource(), cache: cache).catalog()
        _ = try await CachedDeckSource(source: FakeSource(), cache: cache).deck(id: "d", language: .pt)

        let offline = CachedDeckSource(source: FakeSource(offline: true), cache: cache)
        #expect(try await offline.catalog().decks.first?.id == "d")
        #expect(try await offline.deck(id: "d", language: .pt).title == "T-pt")
        #expect(offline.cachedLanguages(of: "d") == [.pt])
    }

    @Test("Offline with nothing cached throws the source's error")
    func offlineEmpty() async {
        let cache = tempCache()
        defer { cache.clear() }
        let offline = CachedDeckSource(source: FakeSource(offline: true), cache: cache)
        await #expect(throws: URLError.self) { _ = try await offline.catalog() }
        await #expect(throws: URLError.self) { _ = try await offline.deck(id: "d", language: .en) }
    }

    @Test("The site source reads the decks through the injected fetcher")
    func siteSource() async throws {
        let source = SiteDeckSource(fetch: { url in
            let path = url.path
            if path.hasSuffix("/decks/index.html") { return Data(listHTML.utf8) }
            if path.hasSuffix("index.md") { return Data(markdown.utf8) }
            if path.hasSuffix("index.html") { return Data(page.utf8) }
            throw URLError(.badServerResponse)
        })
        let catalog = try await source.catalog()
        #expect(catalog.decks.count == 2)
        #expect(catalog.decks[0].languages == DeckLanguage.allCases)
        let deck = try await source.deck(id: "1-the-investment-case", language: .pt)
        #expect(deck.slides.count == 2)
        #expect(deck.slides[0].image != nil)
    }

    @Test("The timer adds time while running and holds it when paused")
    @MainActor func timer() {
        let t = PresenterTimer()
        let t0 = Date(timeIntervalSince1970: 1_000)
        t.start(now: t0)
        #expect(t.elapsed(now: t0.addingTimeInterval(65)) == 65)
        t.pause(now: t0.addingTimeInterval(65))
        #expect(t.elapsed(now: t0.addingTimeInterval(500)) == 65)
        #expect(PresenterTimer.format(65) == "01:05")
        #expect(PresenterTimer.format(3725) == "1:02:05")
    }
}
