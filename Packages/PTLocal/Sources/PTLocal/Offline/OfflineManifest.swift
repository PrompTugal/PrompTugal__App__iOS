import CryptoKit
import Foundation

/// promptugal.news's list of every file in its JSON API (api/v1/manifest.json): path, size, SHA-256 and feature.
public struct EditionManifest: Decodable, Sendable {
    public let version: String?
    public let files: [File]

    public static let url = URL(string: "https://promptugal.news/api/v1/manifest.json")!
    public static let base = URL(string: "https://promptugal.news/")!

    enum CodingKeys: String, CodingKey { case version, files }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try? c.decode(String.self, forKey: .version)
        files = c.lenientArray(File.self, forKey: .files)
    }

    public struct File: Codable, Sendable, Hashable {
        public let path: String
        public let bytes: Int
        public let sha256: String
        public let feature: String?
    }

    /// The offline edition: the same files for every reader (so the requests say nothing about who reads what):
    /// the articles index and each article, since.json, the by-place index and the file of every place the app knows
    /// (every id in the by-place index: Portugal, the Algarve, its towns and the district capitals), and the newsletter. Only safe relative paths under api/v1/.
    public func editionFiles(places: [String] = PlaceDirectory.all.map(\.id)) -> [File] {
        let placeFiles = Set(places.map { "api/v1/by-place/\($0).json" })
        var out: [File] = []
        for file in files where Self.isSafe(file.path) {
            if Self.wanted(file.path, placeFiles: placeFiles) { out.append(file) }
        }
        return out.sorted { $0.path < $1.path }
    }

    static let singles: Set<String> = [
        "api/v1/articles.json", "api/v1/since.json", "api/v1/by-place/index.json", "api/v1/newsletter.json",
    ]

    static func wanted(_ path: String, placeFiles: Set<String>) -> Bool {
        if singles.contains(path) || placeFiles.contains(path) { return true }
        if path.hasPrefix("api/v1/articles/") && path.hasSuffix(".json") {
            return !path.dropFirst("api/v1/articles/".count).contains("/")
        }
        if path.hasPrefix("api/v1/newsletter/") && path.hasSuffix(".txt") {
            return !path.dropFirst("api/v1/newsletter/".count).contains("/")
        }
        return false
    }

    static let placeIndexPath = "api/v1/by-place/index.json"

    /// The place ids in by-place/index.json (`places[].id`), only plain ids (letters, digits, dashes).
    static func placeIDs(fromIndex data: Data) -> [String]? {
        struct Index: Decodable {
            struct Place: Decodable { let id: String }
            let places: [Place]
        }
        guard let index = try? JSONDecoder().decode(Index.self, from: data) else { return nil }
        return index.places.map(\.id).filter { id in
            !id.isEmpty && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    /// A relative path under api/v1/ with no "..", no leading slash and no scheme.
    static func isSafe(_ path: String) -> Bool {
        guard path.hasPrefix("api/v1/"), !path.contains(".."), !path.contains("//"), !path.contains("\\") else { return false }
        return !path.contains(":")
    }
}

/// SHA-256 as lowercase hex.
public enum EditionHash {
    public static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func matches(_ data: Data, _ expected: String) -> Bool {
        hex(data) == expected.lowercased()
    }
}

/// What this device saved: the edition's version, when, and each file.
public struct SavedEdition: Codable, Sendable, Equatable {
    public let version: String?
    public let savedAt: Date
    public let files: [EditionManifest.File]

    public var bytes: Int { files.reduce(0) { $0 + $1.bytes } }

    public func contains(_ path: String) -> Bool { files.contains { $0.path == path } }
}

/// The saved files on disk, readable from any thread. The app's readers ask it when the network fails.
public struct EditionFiles: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static func standard() -> EditionFiles {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return EditionFiles(directory: base.appendingPathComponent("PTLocal/offline-edition", isDirectory: true))
    }

    var recordURL: URL { directory.appendingPathComponent("edition.json") }
    var filesRoot: URL { directory.appendingPathComponent("files", isDirectory: true) }

    func url(for path: String) -> URL? {
        guard EditionManifest.isSafe(path) else { return nil }
        return filesRoot.appendingPathComponent(path)
    }

    /// The saved edition's record, if there is one.
    public func record() -> SavedEdition? {
        guard let data = try? Data(contentsOf: recordURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SavedEdition.self, from: data)
    }

    /// A saved file by its site path ("api/v1/by-place/faro.json"), or nil.
    public func load(_ path: String) -> Data? {
        guard let url = url(for: path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Replaces the saved edition with the files in `staged` (written there first, all verified), then the record.
    func install(staged: URL, record: SavedEdition) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        if manager.fileExists(atPath: filesRoot.path) { try manager.removeItem(at: filesRoot) }
        try manager.moveItem(at: staged, to: filesRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: recordURL, options: .atomic)
    }

    /// Deletes everything saved.
    public func delete() { try? FileManager.default.removeItem(at: directory) }
}
