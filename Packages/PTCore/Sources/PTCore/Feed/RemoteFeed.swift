import Foundation
import Observation

/// One public JSON file: fetched, decoded off the main actor, cached on disk for
/// offline use. Requests go through the shared `HTTPClient`, so Debug → Network shows them.
@MainActor @Observable
public final class RemoteFeed<Value: Decodable & Sendable> {
    public let name: String
    public let url: URL
    /// How long a load is skipped after a good one, unless forced.
    public var freshFor: TimeInterval = 120

    public private(set) var value: Value?
    public private(set) var updated: Date?
    public private(set) var phase: LoadPhase = .idle
    public private(set) var bytes = 0
    private var cacheLoaded = false
    /// Set by `preview(_:)`: sample data stays as it is and is never replaced from the network.
    public private(set) var pinned = false

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }

    public var failed: Bool { if case .failed = phase { true } else { false } }

    /// Loads the cached copy (once), then the network copy if the cache is older than `freshFor`.
    public func load(force: Bool = false) async {
        if pinned { return }
        if !cacheLoaded { await loadCache() }
        if phase == .loading { return }
        if !force, let updated, Date.now.timeIntervalSince(updated) < freshFor, value != nil { return }
        phase = .loading
        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await HTTPClient.shared.data(for: request, label: "feed.\(name)")
            guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
            let decoded = try await Self.decode(data)
            value = decoded
            bytes = data.count
            updated = .now
            phase = .loaded
            FeedCache.write(data, name: name)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Puts a value in without loading, for previews and tests.
    public func preview(_ value: Value, updated: Date = .now) {
        self.value = value
        self.updated = updated
        cacheLoaded = true
        pinned = true
        phase = .loaded
    }

    private func loadCache() async {
        cacheLoaded = true
        guard value == nil, let cached = FeedCache.read(name: name) else { return }
        if let decoded = try? await Self.decode(cached.data) {
            value = decoded
            updated = cached.date
            bytes = cached.data.count
        }
    }

    nonisolated private static func decode(_ data: Data) async throws -> Value {
        try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(Value.self, from: data)
        }.value
    }

    nonisolated private static func message(for error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: return String(localized: "You are offline.", bundle: .module)
            case .timedOut: return String(localized: "The server took too long to answer.", bundle: .module)
            case .badServerResponse: return String(localized: "The server answered with an error.", bundle: .module)
            default: return String(localized: "The request failed (\(error.code.rawValue)).", bundle: .module)
            }
        }
        if error is DecodingError { return String(localized: "The data changed shape and could not be read.", bundle: .module) }
        return error.localizedDescription
    }
}

/// Raw bytes of each feed, kept in Caches so the dashboards open offline.
public enum FeedCache {
    public static var directory: URL {
        URL.cachesDirectory.appendingPathComponent("PrompTugal/feeds", isDirectory: true)
    }

    public static func write(_ data: Data, name: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file(name), options: .atomic)
    }

    public static func read(name: String) -> (data: Data, date: Date)? {
        let url = file(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        return (data, date)
    }

    public static func file(_ name: String) -> URL {
        directory.appendingPathComponent(name.replacingOccurrences(of: "/", with: "_") + ".json")
    }
}
