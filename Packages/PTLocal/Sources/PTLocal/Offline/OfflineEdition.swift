import Foundation
import Network
import Observation
import PTCore

/// Whether the current connection costs the reader (mobile data, a hotspot) or is in Low Data Mode.
public struct NetworkCost: Sendable, Equatable {
    public let expensive: Bool
    public let constrained: Bool
    public let online: Bool

    public init(expensive: Bool, constrained: Bool, online: Bool) {
        self.expensive = expensive
        self.constrained = constrained
        self.online = online
    }

    /// Fine for a download nobody asked for just now.
    public var freeForAutomatic: Bool { online && !expensive && !constrained }

    /// One reading of the current path.
    public static func current() async -> NetworkCost {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = OnceFlag()
            monitor.pathUpdateHandler = { path in
                guard once.take() else { return }
                monitor.cancel()
                continuation.resume(returning: NetworkCost(expensive: path.isExpensive, constrained: path.isConstrained,
                                                           online: path.status == .satisfied))
            }
            monitor.start(queue: DispatchQueue(label: "ptlocal.network-cost"))
        }
    }
}

/// True once, then false: a continuation is resumed exactly once.
final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false
    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}

/// The last edition of promptugal.news kept on this device for reading offline. It reads the site's manifest, picks
/// the same subset for every reader (articles, since.json, the place files, the newsletter), downloads each file,
/// checks its SHA-256 against the manifest and only then replaces the saved copy. Plain GETs: nothing about the
/// reader is sent. Saves by itself only on Wi-Fi (not on mobile data or in Low Data Mode), and only once the reader has
/// saved an edition by hand.
@MainActor @Observable
public final class OfflineEdition {
    public static let shared = OfflineEdition()

    public enum State: Equatable, Sendable {
        case idle
        case saving(done: Int, total: Int)
        case failed(String)
    }

    public private(set) var saved: SavedEdition?
    public private(set) var state: State = .idle
    /// The size of the next download, once the manifest has been read.
    public private(set) var plannedBytes: Int?

    @ObservationIgnored public let files: EditionFiles
    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cost: @Sendable () async -> NetworkCost
    @ObservationIgnored private let clock: @Sendable () -> Date

    /// An automatic save waits at least this long after the last one.
    nonisolated static let autoGap: TimeInterval = 6 * 3600

    public init(files: EditionFiles = .standard(), fetch: @escaping LocalFetch = OfflineEdition.liveFetch,
                cost: @escaping @Sendable () async -> NetworkCost = { await NetworkCost.current() },
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.files = files
        self.fetch = fetch
        self.cost = cost
        self.clock = clock
        saved = files.record()
    }

    /// The manifest is about 0.7 MB; one article file is under 0.1 MB, a place file under 0.3 MB.
    public nonisolated static let liveFetch: LocalFetch = { url in
        try await HTTPClient.shared.get(url, timeout: 30, label: "offline-edition", maxBytes: 4 * 1024 * 1024)
    }

    public var isSaving: Bool { if case .saving = state { true } else { false } }

    /// Saves the edition now (the reader asked). Returns whether it was saved.
    @discardableResult
    public func save() async -> Bool {
        guard !isSaving else { return false }
        state = .saving(done: 0, total: 0)
        do {
            let manifestData = try await fetch(EditionManifest.url)
            let manifest = try JSONDecoder().decode(EditionManifest.self, from: manifestData)
            let wanted = manifest.editionFiles()
            guard !wanted.isEmpty else { throw OfflineError.emptyManifest }
            plannedBytes = wanted.reduce(0) { $0 + $1.bytes }
            let staged = files.directory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: staged) }
            try await download(wanted, into: staged)
            let record = SavedEdition(version: manifest.version, savedAt: clock(), files: wanted)
            try files.install(staged: staged, record: record)
            saved = record
            state = .idle
            return true
        } catch {
            state = .failed(Self.describe(error))
            return false
        }
    }

    /// Saves again by itself when the reader has saved before, the last save is 6 hours old or more, and the
    /// connection is free (Wi-Fi, not Low Data Mode).
    public func refreshIfFree() async {
        guard let saved, !isSaving, clock().timeIntervalSince(saved.savedAt) >= Self.autoGap else { return }
        guard await cost().freeForAutomatic else { return }
        await save()
    }

    /// Whether a save now would use mobile data (ask first).
    public func onMobileData() async -> Bool {
        let now = await cost()
        return now.online && (now.expensive || now.constrained)
    }

    /// Deletes the saved edition.
    public func delete() {
        files.delete()
        saved = nil
        state = .idle
    }

    /// The saved copy of a site file ("api/v1/by-place/faro.json"), for readers when the network fails.
    public nonisolated func data(for path: String) -> Data? { files.load(path) }

    private func download(_ wanted: [EditionManifest.File], into staged: URL) async throws {
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        var done = 0
        state = .saving(done: 0, total: wanted.count)
        // Six at a time: quick on Wi-Fi without opening a connection per file.
        var start = 0
        while start < wanted.count {
            let batch = Array(wanted[start..<min(start + 6, wanted.count)])
            let results = try await fetchBatch(batch)
            for (file, data) in results {
                let target = staged.appendingPathComponent(file.path)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: target, options: .atomic)
                done += 1
            }
            state = .saving(done: done, total: wanted.count)
            start += 6
        }
    }

    /// One batch, each file checked against its SHA-256; any mismatch fails the whole save.
    private func fetchBatch(_ batch: [EditionManifest.File]) async throws -> [(EditionManifest.File, Data)] {
        try await withThrowingTaskGroup(of: (EditionManifest.File, Data).self) { group in
            for file in batch {
                group.addTask { [fetch] in
                    guard let url = URL(string: file.path, relativeTo: EditionManifest.base)?.absoluteURL else {
                        throw OfflineError.badPath(file.path)
                    }
                    let data = try await fetch(url)
                    guard EditionHash.matches(data, file.sha256) else { throw OfflineError.hashMismatch(file.path) }
                    return (file, data)
                }
            }
            var out: [(EditionManifest.File, Data)] = []
            for try await pair in group { out.append(pair) }
            return out
        }
    }

    static func describe(_ error: Error) -> String {
        if let offline = error as? OfflineError { return offline.text }
        return "promptugal.news could not be reached. The saved edition, if any, is kept."
    }
}

enum OfflineError: Error, Equatable {
    case emptyManifest
    case badPath(String)
    case hashMismatch(String)

    var text: String {
        switch self {
        case .emptyManifest: "The site's manifest lists no files to save. The saved edition, if any, is kept."
        case .badPath(let path): "The manifest lists a file the app will not save (\(path)). Nothing was changed."
        case .hashMismatch(let path): "A file did not match the site's manifest (\(path)), so nothing was changed. Try again later."
        }
    }
}
