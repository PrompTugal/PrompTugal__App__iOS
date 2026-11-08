import Foundation
import Network

/// How much of the network to use. Big packs wait for an unmetered connection.
public struct SyncPolicy: Sendable {
    /// Packs that are only fetched when the connection is neither expensive (cellular, hotspot) nor constrained (Low Data Mode).
    public var wifiOnly: Set<SyncPack>
    /// Files downloaded at the same time.
    public var concurrency: Int
    /// Extra tries for a file that fails or does not verify.
    public var retries: Int
    public var retryDelay: TimeInterval

    public init(wifiOnly: Set<SyncPack> = [.full, .media], concurrency: Int = 4, retries: Int = 1, retryDelay: TimeInterval = 0.5) {
        self.wifiOnly = wifiOnly
        self.concurrency = max(1, concurrency)
        self.retries = max(0, retries)
        self.retryDelay = retryDelay
    }
}

/// What the connection is like right now.
public protocol NetworkPath: Sendable {
    var isExpensive: Bool { get }
    var isConstrained: Bool { get }
}

/// `NWPathMonitor`, with the latest path kept for synchronous reads.
public final class SystemNetworkPath: NetworkPath, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var latest: NWPath?
    private var onReachable: (@Sendable () -> Void)?

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasSatisfied = self.lock.withLock { () -> Bool in
                let before = self.latest?.status == .satisfied
                self.latest = path
                return before
            }
            if path.status == .satisfied, !wasSatisfied { self.currentHandler()?() }
        }
        monitor.start(queue: DispatchQueue(label: "PTSync.path"))
    }

    deinit { monitor.cancel() }

    public var isExpensive: Bool { lock.withLock { latest?.isExpensive ?? false } }
    public var isConstrained: Bool { lock.withLock { latest?.isConstrained ?? false } }
    public var isReachable: Bool { lock.withLock { latest?.status == .satisfied } }

    /// Called when the network comes back (for example to flush the outbox).
    public func onBecameReachable(_ handler: @escaping @Sendable () -> Void) {
        lock.withLock { onReachable = handler }
    }

    private func currentHandler() -> (@Sendable () -> Void)? { lock.withLock { onReachable } }
}

public enum SyncStatus: Sendable, Equatable {
    case idle
    case fetchingManifest
    case downloading(done: Int, total: Int)
    case switched(generation: Int)
    case upToDate
    case failed(String)
}

public struct SyncReport: Sendable, Equatable {
    /// The site's manifest version.
    public var version = ""
    /// The site answered 304: its manifest has not changed since the last sync.
    public var notModified = false
    public var added = 0
    public var changed = 0
    public var removed = 0
    /// Files fetched in this run (files already held by content are not fetched again).
    public var downloaded = 0
    public var bytes = 0
    /// Packs left out because the connection is expensive or constrained.
    public var skippedPacks: Set<SyncPack> = []
    /// Paths that did not download or did not verify. While any are missing nothing is switched.
    public var failures: [String] = []
    /// Manifest entries dropped as malformed or unsafe.
    public var rejectedEntries = 0
    /// A new generation is live.
    public var switched = false
    public var generation = 0

    public var isUpToDate: Bool { failures.isEmpty && !switched }
    public init() {}
}

/// Fetches the manifest, finds what changed, downloads only that, verifies every file, and switches generation once
/// everything wanted is there. One sync runs at a time; a second call joins the one in progress.
public actor SyncEngine {
    private let store: ContentStore
    private let rules: PackRules
    private let transport: SyncTransport
    private let network: NetworkPath?
    private let policy: SyncPolicy
    private let now: @Sendable () -> Date
    private let hub = StatusHub()
    private var running: Task<SyncReport, Error>?

    public init(store: ContentStore, rules: PackRules, transport: SyncTransport = URLSessionTransport(),
                network: NetworkPath? = nil, policy: SyncPolicy = SyncPolicy(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.rules = rules
        self.transport = transport
        self.network = network
        self.policy = policy
        self.now = now
    }

    /// Progress, for a "syncing…" line. Each call gets its own stream.
    public nonisolated func statusUpdates() -> AsyncStream<SyncStatus> { hub.stream() }

    public func sync(_ packs: Set<SyncPack>) async throws -> SyncReport {
        if let running { return try await running.value }
        let task = Task { try await self.run(packs) }
        running = task
        defer { running = nil }
        do {
            return try await task.value
        } catch {
            hub.send(.failed(error.localizedDescription))
            throw error
        }
    }

    private func run(_ packs: Set<SyncPack>) async throws -> SyncReport {
        var report = SyncReport()
        hub.send(.fetchingManifest)

        // 1. The manifest, or the copy kept from last time when the site says nothing changed.
        guard let manifestURL = store.source.manifestURL else { throw SyncError.unsafeURL(store.source.manifestPath) }
        let cached = store.cachedRemote()
        let response = try await transport.download(manifestURL, ifNoneMatch: cached?.etag, into: store.tempDirectory)
        let parsed: (manifest: Manifest, rejected: Int)
        if response.status == 304, let cached {
            parsed = (cached.manifest, 0)
            report.notModified = true
        } else if (200..<300).contains(response.status), let file = response.file {
            defer { try? FileManager.default.removeItem(at: file) }
            let size = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue ?? 0
            guard size <= SyncLimits.maxManifestBytes else { throw SyncError.manifestTooLarge }
            let data = try Data(contentsOf: file)
            if let cached, cached.bodySHA256 == SHA256Hex.of(data) {
                parsed = (cached.manifest, 0)           // same body, whether or not the site sent an ETag
                report.notModified = true
            } else {
                parsed = try Manifest.parse(data)
            }
            store.saveRemote(data, etag: response.etag)
        } else {
            if let file = response.file { try? FileManager.default.removeItem(at: file) }
            throw SyncError.badStatus(response.status)
        }
        report.version = parsed.manifest.version
        report.rejectedEntries = parsed.rejected

        // 2. Which packs this connection allows.
        var wanted = packs
        if let network, network.isExpensive || network.isConstrained {
            for pack in policy.wifiOnly where wanted.contains(pack) {
                wanted.remove(pack)
                report.skippedPacks.insert(pack)
            }
        }

        // 3. The generation to build: new versions of wanted files, old versions of the rest, nothing for removed files.
        let current = store.entriesByPath()
        var target: [ManifestEntry] = []
        var needed: [ManifestEntry] = []
        for entry in parsed.manifest.files {
            guard let pack = rules.pack(for: entry) else { continue }
            if wanted.contains(pack) {
                target.append(entry)
                if current[entry.path]?.sha256 != entry.sha256 || !store.hasObject(entry.sha256) { needed.append(entry) }
            } else if let old = current[entry.path] {
                target.append(old)
            }
        }
        let diff = ManifestDiff.between(current: current, next: target)
        report.added = diff.added.count
        report.changed = diff.changed.count
        report.removed = diff.removed.count

        // 4. Download and verify what is missing.
        var failures: [String] = []
        let total = needed.count
        if total > 0 {
            hub.send(.downloading(done: 0, total: total))
            var done = 0
            var inFlight = 0
            await withTaskGroup(of: FetchResult.self) { group in
                func record(_ result: FetchResult) {
                    done += 1
                    switch result.outcome {
                    case .success(let bytes):
                        if bytes > 0 { report.downloaded += 1; report.bytes += bytes }
                    case .failure:
                        failures.append(result.path)
                    }
                    hub.send(.downloading(done: done, total: total))
                }
                for entry in needed {
                    if inFlight >= policy.concurrency, let finished = await group.next() {
                        inFlight -= 1
                        record(finished)
                    }
                    let store = self.store, transport = self.transport, policy = self.policy
                    group.addTask { await Self.fetch(entry, store: store, transport: transport, policy: policy) }
                    inFlight += 1
                }
                for await finished in group { record(finished) }
            }
        }
        try Task.checkCancellation()
        report.failures = failures.sorted()

        // 5. Switch only when everything wanted is here. A half-done sync never shows.
        guard failures.isEmpty else {
            hub.send(.failed("\(failures.count) of \(total) files did not download"))
            report.generation = store.generation
            return report
        }
        let unchanged = diff.added.isEmpty && diff.changed.isEmpty && diff.removed.isEmpty
        if unchanged, store.generation > 0 {
            try store.markChecked(at: now())
            report.generation = store.generation
            hub.send(.upToDate)
        } else {
            report.generation = try store.switchGeneration(entries: target, version: parsed.manifest.version, at: now())
            report.switched = true
            hub.send(.switched(generation: report.generation))
        }
        return report
    }

    private struct FetchResult: Sendable {
        let path: String
        let outcome: Result<Int, Error>
    }

    /// One file: refuse a wrong size or hash, try again, and only a verified file reaches `objects/`.
    private static func fetch(_ entry: ManifestEntry, store: ContentStore, transport: SyncTransport, policy: SyncPolicy) async -> FetchResult {
        guard let url = store.source.url(for: entry.path) else {
            return FetchResult(path: entry.path, outcome: .failure(SyncError.unsafeURL(entry.path)))
        }
        if store.hasObject(entry.sha256) { return FetchResult(path: entry.path, outcome: .success(0)) }
        var lastError: Error = SyncError.hashMismatch(entry.path)
        for attempt in 0...policy.retries {
            if Task.isCancelled { return FetchResult(path: entry.path, outcome: .failure(CancellationError())) }
            if attempt > 0, policy.retryDelay > 0 { try? await Task.sleep(nanoseconds: UInt64(policy.retryDelay * 1_000_000_000)) }
            do {
                let download = try await transport.download(url, ifNoneMatch: nil, into: store.tempDirectory)
                guard (200..<300).contains(download.status), let file = download.file else {
                    if let file = download.file { try? FileManager.default.removeItem(at: file) }
                    lastError = SyncError.badStatus(download.status)
                    continue
                }
                let size = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue ?? -1
                guard size == entry.bytes else {
                    try? FileManager.default.removeItem(at: file)
                    lastError = SyncError.sizeMismatch(entry.path)
                    continue
                }
                guard (try? SHA256Hex.of(fileAt: file)) == entry.sha256 else {
                    try? FileManager.default.removeItem(at: file)
                    lastError = SyncError.hashMismatch(entry.path)
                    continue
                }
                try store.adopt(file: file, sha256: entry.sha256)
                return FetchResult(path: entry.path, outcome: .success(entry.bytes))
            } catch {
                lastError = error
            }
        }
        return FetchResult(path: entry.path, outcome: .failure(lastError))
    }
}

/// Hands each subscriber its own stream of statuses.
final class StatusHub: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]

    func stream() -> AsyncStream<SyncStatus> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
            continuation.yield(.idle)
        }
    }

    func send(_ status: SyncStatus) {
        let all = lock.withLock { Array(continuations.values) }
        for continuation in all { continuation.yield(status) }
    }
}
