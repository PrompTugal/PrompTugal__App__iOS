import Foundation
import Testing
@testable import PTExplore

// Small copies of the newsroom's files, in the shapes read on 25 Nov 2026.

private let articlesJSON = """
{"version":"v0.1.2280","count":3,"items":[
 {"id":"five-coding-agents","title":"A study of five coding agents","date":"2026-11-24","author":"journalist-ai@PrompTugal.vicky",
  "town":null,"region":null,"sources":6,"page":"https://promptugal.news/articles/five-coding-agents.html"},
 {"id":"faro-startups","title":"Faro's start-ups find each other","date":"2026-11-20","town":"Faro","sources":3},
 {"title":"No id, skipped"},
 {"id":"old-piece","title":"An older piece","date":"2026-11-02","page":"articles/old-piece.html"}
]}
"""

private let companiesJSON = """
{"type":"company","count":2,"items":[
 {"id":"0xbow","label":"0xbow","page":"https://promptugal.news/companies/0xbow/index.html"},
 {"id":"skild","label":"Skild AI"},
 {"id":"","label":"Empty id, skipped"}
]}
"""

private let placesJSON = """
{"type":"place","count":1,"items":[{"id":"faro","label":"Faro","page":"https://promptugal.news/places/faro/index.html"}]}
"""

private let libraryJSON = """
{"count":2,"items":[
 {"id":"WS26-2026-0001","call_number":"WS26 2026/0001","title":"Day Three replay","kind":"replay-day",
  "publisher":"The organiser's channel","published":"2026-11-12","collection":"ws26",
  "url":"https://www.youtube.com/watch?v=-MGZdAtbTrs","tags":["agents"],"page":"/item/WS26-2026-0001/"},
 {"id":"WS26-2026-0060","title":"An essay on sovereign AI","kind":"article","publisher":"A newspaper",
  "published":"2026-11-15","url":"https://example.org/essay","page":"/item/WS26-2026-0060/"}
]}
"""

private let videosJSON = """
{"count":2,"videos":[
 {"id":"yt-dJi_pXLxwno","title":"Opening Night","channel":"The organiser","kind":"official-replay","day":"2026-11-09",
  "published":"2026-11-09","page":"https://videos.promptugal.news/videos/yt-dJi_pXLxwno/"},
 {"id":"yt--MGZdAtbTrs","title":"Day Three","channel":{"name":"The organiser"},"published":"2026-11-12",
  "url":"https://www.youtube.com/watch?v=-MGZdAtbTrs"}
]}
"""

private let articleRecord = """
{"id":"five-coding-agents","title":"A study of five coding agents","date":"2026-11-24","author":"journalist-ai@PrompTugal.vicky",
 "summary":"A paper on arXiv studies code changes from five agents.","town":null,
 "page":"https://promptugal.news/articles/five-coding-agents.html",
 "sources":[{"url":"https://arxiv.org/abs/2609.17598","host":"arxiv.org","text":"arXiv, the paper"},
            {"url":"https://arxiv.org/abs/2609.17598","host":"arxiv.org","text":"duplicate, skipped"},
            {"url":"not a link","text":"skipped"},
            {"url":"https://arxiv.org/pdf/2609.17598","host":"arxiv.org"}]}
"""

private func files() -> [NewsroomWire.Part: Data] {
    [.articles: Data(articlesJSON.utf8), .companies: Data(companiesJSON.utf8), .places: Data(placesJSON.utf8),
     .library: Data(libraryJSON.utf8), .videos: Data(videosJSON.utf8)]
}

private func data(for url: URL) -> Data {
    let part = NewsroomWire.Part.allCases.first { $0.url == url }
    return part.flatMap { files()[$0] } ?? Data(articleRecord.utf8)
}

@Suite("Reading the newsroom")
struct NewsroomWireTests {
    @Test("Articles become stories that link to their page; an entry without an id is skipped")
    func articles() throws {
        let items = NewsroomWire.articles(Data(articlesJSON.utf8))
        #expect(items.map(\.id) == ["article:five-coding-agents", "article:faro-startups", "article:old-piece"])
        #expect(items.allSatisfy { $0.kind == .article && $0.page != nil })
        #expect(items[0].page?.absoluteString == "https://promptugal.news/articles/five-coding-agents.html")
        #expect(items[1].page?.absoluteString == "https://promptugal.news/articles/faro-startups.html")
        #expect(items[2].page?.absoluteString == "https://promptugal.news/articles/old-piece.html")
        #expect(items[1].subtitle.contains("Faro"))
        #expect(items[0].date == "2026-11-24")
    }

    @Test("Companies and places keep their pages; an empty id is skipped")
    func graphLists() {
        let companies = NewsroomWire.graphList(Data(companiesJSON.utf8), kind: .company)
        #expect(companies.map(\.id) == ["company:0xbow", "company:skild"])
        #expect(companies[1].page?.absoluteString == "https://promptugal.news/companies/skild/index.html")
        #expect(NewsroomWire.graphList(Data(placesJSON.utf8), kind: .place).first?.title == "Faro")
    }

    @Test("Library items point at the original and at the library's page")
    func library() throws {
        let items = NewsroomWire.library(Data(libraryJSON.utf8))
        let essay = try #require(items.first { $0.id == "library:WS26-2026-0060" })
        #expect(essay.link?.absoluteString == "https://example.org/essay")
        #expect(essay.page?.absoluteString == "https://library.promptugal.news/item/WS26-2026-0060/")
        #expect(essay.facts?.contains { $0.value == "A newspaper" } == true)
    }

    @Test("A video's YouTube address is made from its id when the record has none")
    func videos() throws {
        let items = NewsroomWire.videos(Data(videosJSON.utf8))
        #expect(items.first?.link?.absoluteString == "https://www.youtube.com/watch?v=dJi_pXLxwno")
        #expect(items.last?.subtitle.contains("The organiser") == true)
        #expect(NewsroomWire.youTube(id: "vimeo-1") == nil)
        #expect(NewsroomWire.youTubeID(URL(string: "https://youtu.be/abc")) == "abc")
    }

    @Test("A video the library also holds shows once, as the video")
    func dedupe() {
        let index = NewsroomWire.index(files())
        let library = index.items.filter { $0.kind == .library }
        #expect(library.count == 3)
        #expect(!library.contains { $0.id == "library:WS26-2026-0001" })
        #expect(library.contains { $0.id == "video:yt--MGZdAtbTrs" })
        #expect(index.version == "v0.1.2280")
    }

    @Test("Broken or missing files give no entries, not an error")
    func lenient() {
        #expect(NewsroomWire.articles(Data("{".utf8)).isEmpty)
        #expect(NewsroomWire.videos(nil).isEmpty)
        #expect(NewsroomWire.index([.places: Data(placesJSON.utf8)]).items.count == 1)
    }

    @Test("An article's record gives its summary and its sources, de-duplicated")
    func articleDetail() throws {
        let detail = try ExploreDetail.decode(Data(articleRecord.utf8), kind: .article)
        #expect(detail.title == "A study of five coding agents")
        #expect(detail.facts.first?.value.hasPrefix("A paper on arXiv") == true)
        #expect(detail.sources.map(\.url.absoluteString) == ["https://arxiv.org/abs/2609.17598", "https://arxiv.org/pdf/2609.17598"])
        #expect(detail.sources[0].label == "arXiv, the paper")
        #expect(detail.sources[1].label == "arxiv.org")
        #expect(detail.pageURL?.host() == "promptugal.news")
    }
}

@Suite("Newsroom search and order")
struct NewsroomSearchTests {
    @Test("Stories list newest first")
    func newestFirst() {
        let index = NewsroomWire.index(files())
        let stories = ExploreSearch.search(index, query: "", kind: .article)
        #expect(stories.map(\.id) == ["article:five-coding-agents", "article:faro-startups", "article:old-piece"])
    }

    @Test("A search finds stories, places and companies by any word")
    func search() {
        let index = NewsroomWire.index(files())
        #expect(ExploreSearch.search(index, query: "faro").map(\.kind).contains(.place))
        #expect(ExploreSearch.search(index, query: "faro").map(\.kind).contains(.article))
        #expect(ExploreSearch.search(index, query: "skild", kind: .company).count == 1)
        #expect(ExploreSearch.search(index, query: "sovereign").first?.id == "library:WS26-2026-0060")
    }

    @MainActor @Test("The newsroom store offers Stories, Companies, Places, Library and groups a search")
    func store() async {
        let source = NewsroomExploreSource(cache: tempCache(), fetch: { data(for: $0) }, builtIn: { _ in nil })
        let store = ExploreStore.newsroom(source: source)
        await store.load()
        #expect(store.shownKinds == [.article, .company, .place, .library])
        #expect(store.kind == .article)
        #expect(store.origin?.kind == .live)
        store.query = "faro"
        #expect(store.grouped().map(\.kind) == [.article, .place])
    }

    @MainActor @Test("The summit store hides a segment with no entries")
    func summitHidesEmpty() async throws {
        let index = ExploreIndex(items: [ExploreItem(id: "company:a", kind: .company, title: "A")])
        let store = ExploreStore.summit(source: FixedSource(fixed: index))
        await store.load()
        #expect(store.shownKinds == [.company])
        #expect(store.kind == .company)
    }
}

@Suite("Where the newsroom's data came from")
struct NewsroomOriginTests {
    @Test("Online, every part is live and kept on this device")
    func live() async throws {
        let cache = tempCache()
        defer { cache.clear() }
        let source = NewsroomExploreSource(cache: cache, fetch: { data(for: $0) }, builtIn: { _ in nil })
        let index = try await source.index()
        #expect(index.origin?.kind == .live)
        #expect(index.items.count == 3 + 2 + 1 + 3)
        #expect(cache.load(key: NewsroomWire.Part.videos.fileName) != nil)
    }

    @Test("Offline, the index is this device's copy and says so")
    func cached() async throws {
        let cache = tempCache()
        defer { cache.clear() }
        _ = try await NewsroomExploreSource(cache: cache, fetch: { data(for: $0) }, builtIn: { _ in nil }).index()
        let offline = NewsroomExploreSource(cache: cache, fetch: { _ in throw URLError(.notConnectedToInternet) },
                                            builtIn: { _ in nil })
        let index = try await offline.index()
        #expect(index.origin?.kind == .cached)
        #expect(index.items.count == 9)
    }

    @Test("With no network and no copy, the built-in copy shows and is labelled")
    func builtIn() async throws {
        let source = NewsroomExploreSource(cache: tempCache(), fetch: { _ in throw URLError(.notConnectedToInternet) },
                                           builtIn: { files()[$0] })
        let index = try await source.index()
        #expect(index.origin?.kind == .builtIn)
        #expect(index.origin?.snapshotDay == NewsroomExploreSource.snapshotDay)
        #expect(ExploreOriginLine.label(index.origin, loading: false).contains(NewsroomExploreSource.snapshotDay))
    }

    @Test("One part failing makes the whole screen say it is not all live")
    func mixed() async throws {
        let source = NewsroomExploreSource(cache: tempCache(), fetch: { url in
            if url == NewsroomWire.Part.videos.url { throw URLError(.timedOut) }
            return data(for: url)
        }, builtIn: { files()[$0] })
        let index = try await source.index()
        #expect(index.origin?.kind == .builtIn)
        #expect(index.items.contains { $0.id.hasPrefix("video:") })
    }

    @Test("An error page does not replace a good copy")
    func errorPage() async throws {
        let cache = tempCache()
        defer { cache.clear() }
        _ = try await NewsroomExploreSource(cache: cache, fetch: { data(for: $0) }, builtIn: { _ in nil }).index()
        let broken = NewsroomExploreSource(cache: cache, fetch: { _ in Data("<html>busy</html>".utf8) }, builtIn: { _ in nil })
        let index = try await broken.index()
        #expect(index.origin?.kind == .cached)
        #expect(index.items.count == 9)
    }

    @Test("Nothing anywhere throws")
    func nothing() async {
        let source = NewsroomExploreSource(cache: tempCache(), fetch: { _ in throw URLError(.notConnectedToInternet) },
                                           builtIn: { _ in nil })
        await #expect(throws: URLError.self) { _ = try await source.index() }
    }

    @Test("The built-in copy in the package decodes")
    func bundled() {
        for part in NewsroomWire.Part.allCases {
            let data = NewsroomExploreSource.bundled(part)
            #expect(data != nil, "missing \(part.fileName)")
            #expect(!NewsroomExploreSource.items(part, data ?? Data()).isEmpty, "empty \(part.fileName)")
        }
    }

    @Test("A library item's detail comes from the list, no fetch")
    func libraryDetail() async throws {
        let source = NewsroomExploreSource(cache: tempCache(), fetch: { _ in throw URLError(.badURL) }, builtIn: { _ in nil })
        let item = try #require(NewsroomWire.library(Data(libraryJSON.utf8)).last)
        let detail = try await source.detail(for: item)
        #expect(detail.facts.contains { $0.value == "A newspaper" })
    }

    @Test("Between two copies the older date wins; built-in beats cached beats live")
    func combine() {
        let old = Date(timeIntervalSince1970: 1_000)
        let new = Date(timeIntervalSince1970: 2_000)
        let a = ExploreOrigin(kind: .cached, date: new).combined(with: ExploreOrigin(kind: .cached, date: old))
        #expect(a.date == old)
        #expect(ExploreOrigin(kind: .live, date: new).combined(with: ExploreOrigin(kind: .cached, date: old)).kind == .cached)
        #expect(ExploreOrigin(kind: .builtIn).combined(with: ExploreOrigin(kind: .cached)).kind == .builtIn)
    }

    @Test("New starts open the newsroom's segments")
    func starts() {
        #expect(ExploreStart.stories.kind == .article)
        #expect(ExploreStart.library.kind == .library)
    }
}

private struct FixedSource: ExploreSource {
    var fixed: ExploreIndex
    func index() async throws -> ExploreIndex { fixed }
    func detail(for item: ExploreItem) async throws -> ExploreDetail { ExploreDetail(item: item) }
}

private func tempCache() -> ExploreDiskCache {
    ExploreDiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ptexplore-news-\(UUID().uuidString)"))
}
