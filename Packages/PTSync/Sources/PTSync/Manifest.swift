import Foundation

/// One file in a site's manifest: `{ "path", "bytes", "sha256", "feature" }`. Other keys (`schema`) are ignored.
public struct ManifestEntry: Codable, Sendable, Hashable, Identifiable {
    public let path: String
    public let bytes: Int
    public let sha256: String
    public let feature: String?

    public var id: String { path }

    public init(path: String, bytes: Int, sha256: String, feature: String? = nil) {
        self.path = path
        self.bytes = bytes
        self.sha256 = sha256
        self.feature = feature
    }

    /// A safe path, a sane size and a 64-character lowercase hex digest.
    public var isWellFormed: Bool {
        SyncPath.isSafe(path) && bytes >= 0 && bytes <= SyncLimits.maxFileBytes && Self.isSHA256(sha256)
    }

    static func isSHA256(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }
}

/// The list of files a site publishes. Decoding keeps the well-formed entries and counts the rest.
public struct Manifest: Codable, Sendable, Equatable {
    public var version: String
    public var files: [ManifestEntry]

    public init(version: String, files: [ManifestEntry]) {
        self.version = version
        self.files = files
    }

    private struct Lossy: Decodable {
        let value: ManifestEntry?
        init(from decoder: Decoder) throws { value = try? ManifestEntry(from: decoder) }
    }

    private struct Raw: Decodable {
        var version: String?
        var files: [Lossy]
    }

    /// Parses a manifest. Entries that are malformed or unsafe are dropped and counted; a repeated path keeps the last.
    public static func parse(_ data: Data) throws -> (manifest: Manifest, rejected: Int) {
        guard data.count <= SyncLimits.maxManifestBytes else { throw SyncError.manifestTooLarge }
        let raw: Raw
        do { raw = try JSONDecoder().decode(Raw.self, from: data) } catch { throw SyncError.manifestInvalid }
        guard raw.files.count <= SyncLimits.maxFiles else { throw SyncError.manifestTooLarge }
        var byPath: [String: ManifestEntry] = [:]
        var order: [String] = []
        var accepted = 0
        for item in raw.files {
            guard let entry = item.value, entry.isWellFormed else { continue }
            accepted += 1
            if byPath[entry.path] == nil { order.append(entry.path) }
            byPath[entry.path] = entry
        }
        let files = order.compactMap { byPath[$0] }
        return (Manifest(version: raw.version ?? "", files: files), raw.files.count - accepted)
    }
}

/// How much to fetch. `core` is what the app needs to start, `full` is the rest of the data, `media` is opt-in.
public enum SyncPack: String, Codable, Sendable, CaseIterable, Hashable {
    case core, full, media
}

/// Which pack a file belongs to, by path prefix (first match wins). A rule with no pack means "never fetch".
public struct PackRules: Sendable {
    public struct Rule: Sendable {
        public let prefix: String
        public let pack: SyncPack?
        public init(_ prefix: String, _ pack: SyncPack?) {
            self.prefix = prefix
            self.pack = pack
        }
    }

    public var rules: [Rule]
    /// For a file no rule matches. Nil: never fetch.
    public var fallback: SyncPack?

    public init(rules: [Rule], fallback: SyncPack? = .full) {
        self.rules = rules
        self.fallback = fallback
    }

    public func pack(for entry: ManifestEntry) -> SyncPack? {
        for rule in rules where entry.path.hasPrefix(rule.prefix) { return rule.pack }
        return fallback
    }

    /// promptugal.news: the agenda, days, stories, newsletter, entity indexes and event pages are `core` (about 1.5 MB);
    /// the graph, the search index, entity pages and the newsroom are `full` (about 18 MB). The service worker and the
    /// deploy list are for browsers and are never fetched.
    public static let promptugalNews = PackRules(rules: [
        Rule("sw.js", nil), Rule("api/v1/deploy-exclude.txt", nil),
        Rule("api/v1/live/", .core), Rule("api/v1/days", .core), Rule("api/v1/events", .core),
        Rule("api/v1/stories", .core), Rule("api/v1/newsletter", .core), Rule("api/v1/index.json", .core),
        Rule("api/v1/ontology.json", .core), Rule("api/v1/people.json", .core),
        Rule("api/v1/organisations.json", .core), Rule("api/v1/companies.json", .core),
        Rule("api/v1/places.json", .core), Rule("api/v1/topics.json", .core),
    ], fallback: .full)
}

/// What changed between the files held now and a manifest.
public struct ManifestDiff: Sendable, Equatable {
    public var added: [String] = []
    public var changed: [String] = []
    public var removed: [String] = []
    public var unchanged = 0

    public init() {}

    public static func between(current: [String: ManifestEntry], next: [ManifestEntry]) -> ManifestDiff {
        var diff = ManifestDiff()
        var seen = Set<String>()
        for entry in next {
            seen.insert(entry.path)
            if let old = current[entry.path] {
                if old.sha256 == entry.sha256 { diff.unchanged += 1 } else { diff.changed.append(entry.path) }
            } else {
                diff.added.append(entry.path)
            }
        }
        diff.removed = current.keys.filter { !seen.contains($0) }.sorted()
        diff.added.sort()
        diff.changed.sort()
        return diff
    }
}

public enum SyncError: Error, LocalizedError, Equatable {
    case manifestInvalid, manifestTooLarge
    case unsafeURL(String)
    case badStatus(Int)
    case sizeMismatch(String)
    case hashMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .manifestInvalid: "The site's manifest could not be read."
        case .manifestTooLarge: "The site's manifest is too large."
        case .unsafeURL(let path): "Refused an unsafe address: \(path)"
        case .badStatus(let code): "The site answered with status \(code)."
        case .sizeMismatch(let path): "\(path) is not the size the manifest says."
        case .hashMismatch(let path): "\(path) does not match its SHA-256."
        }
    }
}
