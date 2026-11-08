import Foundation

/// The files of one source on this device, in generations. Files are stored by their SHA-256 (`objects/<sha>`), and a
/// generation is only a list of `path → entry` (`gen-N.json`). Switching is writing the new list, then replacing the
/// small `CURRENT` pointer atomically: a sync that stops half way never changes what the app shows, and downloaded
/// files are kept for the next try.
///
///     <directory>/<source id>/
///         CURRENT              the number of the live generation
///         gen-3.json           a generation: version, time and entries
///         objects/<sha256>     verified file contents
///         remote.json          the last manifest the site sent, and remote.etag
///         tmp/                 downloads in progress
public final class ContentStore: ContentSource, @unchecked Sendable {
    public let source: SyncSource

    private struct State {
        var number = 0
        var entries: [String: ManifestEntry] = [:]
        var version = ""
        var syncedAt: Date?
        var fromSeed = false
    }

    private struct StoredGeneration: Codable {
        var number: Int
        var version: String
        var syncedAt: Date?
        var fromSeed: Bool
        var entries: [ManifestEntry]
    }

    let root: URL
    let objectsDirectory: URL
    let tempDirectory: URL
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var state = State()
    /// Files nothing in the two newest generations refers to are deleted once they are this old.
    private let pruneGrace: TimeInterval

    public init(source: SyncSource, directory: URL? = nil, seed: URL? = nil, pruneGrace: TimeInterval = 3_600) {
        self.source = source
        self.pruneGrace = pruneGrace
        let parent = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PTSync", isDirectory: true)
        root = parent.appendingPathComponent(source.id, isDirectory: true)
        objectsDirectory = root.appendingPathComponent("objects", isDirectory: true)
        tempDirectory = root.appendingPathComponent("tmp", isDirectory: true)
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        for folder in [root, objectsDirectory, tempDirectory] {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: attributes)
        }
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true            // everything here can be downloaded again
        var mutableRoot = root
        try? mutableRoot.setResourceValues(excluded)
        clearTemp(olderThan: 3_600)
        if let loaded = loadCurrent() {
            state = loaded
        } else if let seed {
            installSeed(from: seed)
        }
    }

    /// Opens the store off the main thread. Installing a seed hashes every file in it, so a launch should use this.
    public static func open(source: SyncSource, directory: URL? = nil, seed: URL? = nil) async -> ContentStore {
        await Task.detached(priority: .userInitiated) {
            ContentStore(source: source, directory: directory, seed: seed)
        }.value
    }

    // MARK: Reading

    public var generation: Int { lock.withLock { state.number } }
    public var version: String { lock.withLock { state.version } }
    /// When a sync last finished. Nil when the files came from the build's seed and no sync has run.
    public var syncedAt: Date? { lock.withLock { state.syncedAt } }
    public var isFromSeed: Bool { lock.withLock { state.fromSeed } }
    public var entries: [ManifestEntry] { lock.withLock { state.entries.values.sorted { $0.path < $1.path } } }

    func entriesByPath() -> [String: ManifestEntry] { lock.withLock { state.entries } }

    public func entry(for path: String) -> ManifestEntry? { lock.withLock { state.entries[path] } }

    public func data(at path: String) -> Data? {
        guard let entry = entry(for: path) else { return nil }
        return try? Data(contentsOf: objectURL(entry.sha256))
    }

    /// The file on disk, for views that read a file (images, video). Valid until two more switches have happened.
    public func fileURL(for path: String) -> URL? {
        guard let entry = entry(for: path) else { return nil }
        let url = objectURL(entry.sha256)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    public func snapshot() -> ContentSnapshot {
        lock.withLock {
            ContentSnapshot(generation: state.number, version: state.version, syncedAt: state.syncedAt,
                            entries: state.entries, objects: objectsDirectory)
        }
    }

    /// A closure other packages can take: `ContentStore.loader` is `(String) -> Data?`.
    public var loader: @Sendable (String) -> Data? {
        { [self] path in self.data(at: path) }
    }

    // MARK: Objects

    func objectURL(_ sha256: String) -> URL { objectsDirectory.appendingPathComponent(sha256) }

    func hasObject(_ sha256: String) -> Bool { fileManager.fileExists(atPath: objectURL(sha256).path) }

    func makeTempURL() -> URL { tempDirectory.appendingPathComponent(UUID().uuidString + ".part") }

    /// Moves a verified download into place. If the same content is already there, the download is discarded.
    func adopt(file: URL, sha256: String) throws {
        let destination = objectURL(sha256)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: file)
            return
        }
        do {
            try fileManager.moveItem(at: file, to: destination)
        } catch {
            if fileManager.fileExists(atPath: destination.path) {   // another download won the race
                try? fileManager.removeItem(at: file)
            } else {
                throw error
            }
        }
    }

    // MARK: Switching

    /// Makes `entries` the live generation. Every entry's file must already be in `objects/`.
    @discardableResult
    func switchGeneration(entries: [ManifestEntry], version: String, at date: Date, fromSeed: Bool = false) throws -> Int {
        let number = lock.withLock { state.number } + 1
        let syncedAt: Date? = fromSeed ? nil : date      // a seed has not been synced yet
        let stored = StoredGeneration(number: number, version: version, syncedAt: syncedAt, fromSeed: fromSeed,
                                      entries: entries.sorted { $0.path < $1.path })
        try write(stored)
        try Data("\(number)\n".utf8).write(to: root.appendingPathComponent("CURRENT"), options: .atomic)
        lock.withLock {
            state = State(number: number, entries: Dictionary(entries.map { ($0.path, $0) }, uniquingKeysWith: { _, last in last }),
                          version: version, syncedAt: syncedAt, fromSeed: fromSeed)
        }
        prune()
        return number
    }

    /// A sync found nothing to change: remember when it looked.
    func markChecked(at date: Date) throws {
        let stored: StoredGeneration? = lock.withLock {
            guard state.number > 0 else { return nil }
            state.syncedAt = date
            state.fromSeed = false
            return StoredGeneration(number: state.number, version: state.version, syncedAt: date, fromSeed: false,
                                    entries: state.entries.values.sorted { $0.path < $1.path })
        }
        if let stored { try write(stored) }
    }

    // MARK: The site's last manifest

    func cachedRemote() -> (manifest: Manifest, etag: String?)? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("remote.json")),
              let parsed = try? Manifest.parse(data) else { return nil }
        let etag = (try? String(contentsOf: root.appendingPathComponent("remote.etag"), encoding: .utf8))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return (parsed.manifest, (etag?.isEmpty ?? true) ? nil : etag)
    }

    func saveRemote(_ data: Data, etag: String?) {
        try? data.write(to: root.appendingPathComponent("remote.json"), options: .atomic)
        let tagURL = root.appendingPathComponent("remote.etag")
        if let etag { try? Data(etag.utf8).write(to: tagURL, options: .atomic) } else { try? fileManager.removeItem(at: tagURL) }
    }

    // MARK: Disk

    private func generationURL(_ number: Int) -> URL { root.appendingPathComponent("gen-\(number).json") }

    private func write(_ stored: StoredGeneration) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(stored).write(to: generationURL(stored.number), options: .atomic)
    }

    private func read(_ number: Int) -> StoredGeneration? {
        guard let data = try? Data(contentsOf: generationURL(number)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StoredGeneration.self, from: data)
    }

    private func loadCurrent() -> State? {
        guard let text = try? String(contentsOf: root.appendingPathComponent("CURRENT"), encoding: .utf8),
              let number = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let stored = read(number) else { return nil }
        return State(number: stored.number, entries: Dictionary(stored.entries.map { ($0.path, $0) }, uniquingKeysWith: { _, last in last }),
                     version: stored.version, syncedAt: stored.syncedAt, fromSeed: stored.fromSeed)
    }

    /// The seed is a folder that looks like the site: `manifest.json` and each file at its manifest path. Only files whose
    /// size and SHA-256 match the seed's own manifest are kept.
    private func installSeed(from seed: URL) {
        guard let data = try? Data(contentsOf: seed.appendingPathComponent("manifest.json")),
              let parsed = try? Manifest.parse(data) else { return }
        var accepted: [ManifestEntry] = []
        for entry in parsed.manifest.files {
            if hasObject(entry.sha256) { accepted.append(entry); continue }
            let file = seed.appendingPathComponent(entry.path)
            let size = ((try? fileManager.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue
            guard size == entry.bytes, (try? SHA256Hex.of(fileAt: file)) == entry.sha256 else { continue }
            let copy = makeTempURL()
            guard (try? fileManager.copyItem(at: file, to: copy)) != nil, (try? adopt(file: copy, sha256: entry.sha256)) != nil else { continue }
            accepted.append(entry)
        }
        guard !accepted.isEmpty else { return }
        saveRemote(data, etag: nil)
        _ = try? switchGeneration(entries: accepted, version: parsed.manifest.version, at: Date(), fromSeed: true)
    }

    /// Keeps the two newest generations. Files only older generations used are deleted after `pruneGrace`.
    func prune() {
        let current = lock.withLock { state.number }
        let names = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        var keep = Set<String>()
        for name in names where name.hasPrefix("gen-") && name.hasSuffix(".json") {
            guard let number = Int(name.dropFirst(4).dropLast(5)) else { continue }
            if number >= current - 1 {
                if let stored = read(number) { keep.formUnion(stored.entries.map(\.sha256)) }
            } else {
                try? fileManager.removeItem(at: root.appendingPathComponent(name))
            }
        }
        let cutoff = Date().addingTimeInterval(-pruneGrace)
        for name in (try? fileManager.contentsOfDirectory(atPath: objectsDirectory.path)) ?? [] where !keep.contains(name) {
            let url = objectsDirectory.appendingPathComponent(name)
            let modified = ((try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date) ?? .distantPast
            if modified <= cutoff { try? fileManager.removeItem(at: url) }
        }
    }

    private func clearTemp(olderThan age: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-age)
        for name in (try? fileManager.contentsOfDirectory(atPath: tempDirectory.path)) ?? [] {
            let url = tempDirectory.appendingPathComponent(name)
            let modified = ((try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date) ?? .distantPast
            if modified <= cutoff { try? fileManager.removeItem(at: url) }
        }
    }
}
