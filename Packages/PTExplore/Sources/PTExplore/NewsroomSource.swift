import Foundation

/// Reads the newsroom's lists into entries. Pure and lenient: an entry without an id or a title is skipped,
/// a missing field is left empty, a broken file gives no entries. Tested with fixtures.
public enum NewsroomWire {
    /// The files Explore reads, with where each lives.
    public enum Part: String, CaseIterable, Sendable {
        case articles, companies, places, library, videos

        public var url: URL {
            switch self {
            case .articles: URL(string: "https://promptugal.news/api/v1/articles.json")!
            case .companies: URL(string: "https://promptugal.news/api/v1/companies.json")!
            case .places: URL(string: "https://promptugal.news/api/v1/places.json")!
            case .library: URL(string: "https://library.promptugal.news/api/v1/items/index.json")!
            case .videos: URL(string: "https://videos.promptugal.news/api/v1/videos/index.json")!
            }
        }

        /// The start of the ids this part gives, so a part that failed can be filled from the built-in copy.
        var prefix: String {
            switch self {
            case .articles: "article:"
            case .companies: "company:"
            case .places: "place:"
            case .library: "library:"
            case .videos: "video:"
            }
        }

        /// The file name of the part's built-in copy (in the package's resources) and of this device's copy.
        var fileName: String { "newsroom-\(rawValue).json" }
    }

    static let site = URL(string: "https://promptugal.news")!
    static let librarySite = URL(string: "https://library.promptugal.news")!
    static let videoSite = URL(string: "https://videos.promptugal.news")!

    static func list(_ data: Data?, key: String) -> [[String: Any]] {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return (root[key] as? [[String: Any]]) ?? []
    }

    static func string(_ any: Any?) -> String? {
        guard let s = any as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func url(_ any: Any?, base: URL? = nil) -> URL? {
        guard let s = string(any), let u = URL(string: s, relativeTo: base)?.absoluteURL,
              u.scheme == "https" || u.scheme == "http" else { return nil }
        return u
    }

    /// The `version` a file carries, if any.
    public static func version(_ data: Data?) -> String? {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return string(root["version"])
    }

    // MARK: Parts

    /// `articles.json`: every published article, newest first on screen. Each links to its page on promptugal.news.
    public static func articles(_ data: Data?) -> [ExploreItem] {
        list(data, key: "items").compactMap { (e: [String: Any]) -> ExploreItem? in
            guard let id = string(e["id"]), let title = string(e["title"]) else { return nil }
            let date = string(e["date"])
            let town = string(e["town"]) ?? string(e["region"])
            let count = e["sources"] as? Int
            var line: [String] = []
            if let date { line.append(ExploreFormat.date(date)) }
            if let town { line.append(town) }
            if let count, count > 0 { line.append(String(localized: "\(count) sources", bundle: .module)) }
            var facts: [ExploreFact] = []
            if let author = string(e["author"]) { facts.append(ExploreFact(label: String(localized: "By", bundle: .module), value: author)) }
            let page = url(e["page"], base: site) ?? site.appendingPathComponent("articles/\(id).html")
            return ExploreItem(id: "article:\(id)", kind: .article, title: title, subtitle: line.joined(separator: " · "),
                               text: [string(e["author"]), town].compactMap { $0 }.joined(separator: " "),
                               page: page, date: date, facts: facts)
        }
    }

    /// `companies.json` or `places.json`: id, label and page.
    public static func graphList(_ data: Data?, kind: ExploreKind) -> [ExploreItem] {
        list(data, key: "items").compactMap { (e: [String: Any]) -> ExploreItem? in
            guard let id = string(e["id"]), let title = string(e["label"]) ?? string(e["name"]) else { return nil }
            let page = url(e["page"], base: site) ?? site.appendingPathComponent("\(kind.folder)/\(id)/index.html")
            return ExploreItem(id: "\(kind.rawValue):\(id)", kind: kind, title: title, page: page)
        }
    }

    /// The library's `items/index.json`: talks, replays and articles held by library.promptugal.news.
    public static func library(_ data: Data?) -> [ExploreItem] {
        list(data, key: "items").compactMap { (e: [String: Any]) -> ExploreItem? in
            guard let id = string(e["id"]), let title = string(e["title"]) else { return nil }
            let publisher = string(e["publisher"])
            let date = string(e["published"])
            let kind = string(e["kind"]).map(prettyKind)
            var facts: [ExploreFact] = []
            if let kind { facts.append(ExploreFact(label: String(localized: "Kind", bundle: .module), value: kind)) }
            if let publisher { facts.append(ExploreFact(label: String(localized: "Publisher", bundle: .module), value: publisher)) }
            if let date { facts.append(ExploreFact(label: String(localized: "Published", bundle: .module), value: ExploreFormat.date(date))) }
            if let call = string(e["call_number"]) { facts.append(ExploreFact(label: String(localized: "Call number", bundle: .module), value: call)) }
            let line = [kind, publisher, date.map(ExploreFormat.date)].compactMap { $0 }.joined(separator: " · ")
            let tags = (e["tags"] as? [String]) ?? []
            return ExploreItem(id: "library:\(id)", kind: .library, title: title, subtitle: line,
                               text: ([publisher, string(e["collection"])].compactMap { $0 } + tags).joined(separator: " "),
                               page: url(e["page"], base: librarySite), date: date,
                               link: url(e["url"]), facts: facts)
        }
    }

    /// The videos site's `videos/index.json`. A YouTube video's address is made from its id (`yt-<id>`) when the
    /// record does not give one.
    public static func videos(_ data: Data?) -> [ExploreItem] {
        list(data, key: "videos").compactMap { (e: [String: Any]) -> ExploreItem? in
            guard let id = string(e["id"]), let title = string(e["title"]) else { return nil }
            let channel = string(e["channel"]) ?? string((e["channel"] as? [String: Any])?["name"])
            let date = string(e["published"]) ?? string(e["day"])
            let kind = string(e["kind"]).map(prettyKind)
            var facts: [ExploreFact] = [ExploreFact(label: String(localized: "Kind", bundle: .module),
                                                    value: kind ?? String(localized: "Video", bundle: .module))]
            if let channel { facts.append(ExploreFact(label: String(localized: "Channel", bundle: .module), value: channel)) }
            if let date { facts.append(ExploreFact(label: String(localized: "Published", bundle: .module), value: ExploreFormat.date(date))) }
            let line = [String(localized: "Video", bundle: .module), channel, date.map(ExploreFormat.date)]
                .compactMap { $0 }.joined(separator: " · ")
            return ExploreItem(id: "video:\(id)", kind: .library, title: title, subtitle: line,
                               text: [channel, kind].compactMap { $0 }.joined(separator: " "),
                               page: url(e["page"], base: videoSite), date: date,
                               link: url(e["url"]) ?? youTube(id: id), facts: facts)
        }
    }

    /// `yt-dJi_pXLxwno` → `https://www.youtube.com/watch?v=dJi_pXLxwno`.
    static func youTube(id: String) -> URL? {
        guard id.hasPrefix("yt-"), id.count > 3 else { return nil }
        var parts = URLComponents(string: "https://www.youtube.com/watch")!
        parts.queryItems = [URLQueryItem(name: "v", value: String(id.dropFirst(3)))]
        return parts.url
    }

    /// The YouTube id a link points at, for spotting the same video in the library and on the videos site.
    static func youTubeID(_ url: URL?) -> String? {
        guard let url, let host = url.host()?.lowercased() else { return nil }
        if host.hasSuffix("youtu.be") { return url.pathComponents.dropFirst().first }
        guard host.hasSuffix("youtube.com") else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
    }

    /// `official-replay` → `Official replay`.
    static func prettyKind(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The whole index from the five files. A video also held by the library shows once, as the video (it has the
    /// videos site's page and the YouTube link); the library's copy is left out.
    public static func index(_ files: [Part: Data], version: String? = nil, origin: ExploreOrigin? = nil) -> ExploreIndex {
        let videos = videos(files[.videos])
        let seen = Set(videos.compactMap { youTubeID($0.link) })
        let library = library(files[.library]).filter { item in
            guard let id = youTubeID(item.link) else { return true }
            return !seen.contains(id)
        }
        let items = articles(files[.articles])
            + graphList(files[.companies], kind: .company)
            + graphList(files[.places], kind: .place)
            + library + videos
        return ExploreIndex(version: version ?? self.version(files[.articles]), items: items, origin: origin)
    }
}

/// Explore's newsroom: stories, companies and places from promptugal.news, items from library.promptugal.news and
/// videos from videos.promptugal.news. Each file is read live; when that fails, from this device's last copy; when
/// there is none, from the copy built into the app. The index's `origin` says which, for the screen.
public struct NewsroomExploreSource: ExploreSource {
    /// The day the built-in copy was taken, said on screen when it is shown.
    public static let snapshotDay = "25 Nov 2026"

    public let fetch: ExploreFetch
    public let cache: ExploreDiskCache
    /// The built-in copy of a part, or nil. Injected for tests.
    public let builtIn: @Sendable (NewsroomWire.Part) -> Data?
    /// Reads the details of articles, companies and places from promptugal.news.
    let site: PublishedExploreSource

    public init(cache: ExploreDiskCache = .standard(), fetch: @escaping ExploreFetch = ExploreFetchers.live,
                builtIn: @escaping @Sendable (NewsroomWire.Part) -> Data? = NewsroomExploreSource.bundled) {
        self.cache = cache
        self.fetch = fetch
        self.builtIn = builtIn
        self.site = PublishedExploreSource(cache: cache, fetch: fetch)
    }

    /// The copy of each part in the package's resources.
    public static let bundled: @Sendable (NewsroomWire.Part) -> Data? = { part in
        guard let url = Bundle.module.url(forResource: "newsroom-\(part.rawValue)", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    struct Read {
        var data: Data
        var origin: ExploreOrigin
    }

    /// One part: live, else this device's copy, else the built-in copy, else nothing.
    func read(_ part: NewsroomWire.Part) async -> Read? {
        do {
            let data = try await fetch(part.url)
            // Only keep a copy that decodes to something: an error page must not replace a good copy.
            if !NewsroomExploreSource.items(part, data).isEmpty {
                cache.store(data, key: part.fileName)
                return Read(data: data, origin: ExploreOrigin(kind: .live, date: Date()))
            }
        } catch {}
        if let stored = cache.load(key: part.fileName), !NewsroomExploreSource.items(part, stored).isEmpty {
            return Read(data: stored, origin: ExploreOrigin(kind: .cached, date: cache.modified(key: part.fileName)))
        }
        if let data = builtIn(part) {
            return Read(data: data, origin: ExploreOrigin(kind: .builtIn, snapshotDay: Self.snapshotDay))
        }
        return nil
    }

    static func items(_ part: NewsroomWire.Part, _ data: Data) -> [ExploreItem] {
        switch part {
        case .articles: NewsroomWire.articles(data)
        case .companies: NewsroomWire.graphList(data, kind: .company)
        case .places: NewsroomWire.graphList(data, kind: .place)
        case .library: NewsroomWire.library(data)
        case .videos: NewsroomWire.videos(data)
        }
    }

    public func index() async throws -> ExploreIndex {
        async let articles = read(.articles)
        async let companies = read(.companies)
        async let places = read(.places)
        async let library = read(.library)
        async let videos = read(.videos)
        let reads: [(NewsroomWire.Part, Read?)] = await [(.articles, articles), (.companies, companies), (.places, places),
                                                         (.library, library), (.videos, videos)]
        try Task.checkCancellation()
        var files: [NewsroomWire.Part: Data] = [:]
        var origin: ExploreOrigin?
        for (part, got) in reads {
            guard let read = got else { continue }
            files[part] = read.data
            origin = origin.map { $0.combined(with: read.origin) } ?? read.origin
        }
        guard !files.isEmpty else { throw URLError(.notConnectedToInternet) }
        return NewsroomWire.index(files, origin: origin)
    }

    public func detail(for item: ExploreItem) async throws -> ExploreDetail {
        switch item.kind {
        case .library:
            return ExploreDetail(item: item)
        case .article:
            var detail = try await site.detail(for: item)
            // The list's facts (the byline) when the record lacks them.
            if detail.facts.isEmpty { detail.facts = ExploreDetail(item: item).facts }
            return detail
        default:
            return try await site.detail(for: item)
        }
    }
}
