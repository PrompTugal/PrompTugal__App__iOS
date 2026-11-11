import Foundation
import Observation

/// The events and the storm headline the screens show. First launch and offline read the seed bundled in the app (or
/// the last good copy kept on the device); a refresh reads fringe.promptugal.news and the storm site over an
/// ephemeral session: no cookies, no disk cache, no credentials, nothing that identifies the reader.
@MainActor @Observable
public final class FringeStore {
    public enum Source: String, Sendable { case seed, cache, network }

    public private(set) var events: [FringeEvent] = []
    public private(set) var storm: StormHeadline?
    public private(set) var source: Source = .seed
    public private(set) var eventsUpdated: Date?
    public private(set) var stormUpdated: Date?
    public private(set) var refreshing = false
    public private(set) var eventsUnavailable = false
    public private(set) var stormUnavailable = false

    private let directory: URL
    private let session: URLSession
    private let minimumInterval: TimeInterval
    private var lastRefresh: Date?

    /// - Parameters:
    ///   - seed: the events file for first launch; by default the one bundled with this package.
    ///   - session: replace only in tests; the default is ephemeral.
    public init(directory: URL? = nil, seed: Data? = FringeStore.bundledSeed(), session: URLSession? = nil,
                minimumInterval: TimeInterval = 60) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("LisbonFringe", isDirectory: true)
        self.session = session ?? FringeStore.ephemeralSession()
        self.minimumInterval = minimumInterval
        if let kept = try? Data(contentsOf: self.directory.appendingPathComponent("events.json")),
           let list = try? FringeFeed.events(from: kept), !list.isEmpty {
            events = list
            source = .cache
            eventsUpdated = (try? FileManager.default.attributesOfItem(atPath: self.directory.appendingPathComponent("events.json").path))?[.modificationDate] as? Date
        } else if let seed, let list = try? FringeFeed.events(from: seed) {
            events = list
            source = .seed
        }
        if let kept = try? Data(contentsOf: self.directory.appendingPathComponent("storm.json")) {
            storm = StormHeadline.parse(kept)
        }
    }

    nonisolated public static func bundledSeed() -> Data? {
        Bundle.module.url(forResource: "seed-events", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    nonisolated public static func ephemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        configuration.httpAdditionalHeaders = ["User-Agent": "LisbonFringe/\(version)"]
        return URLSession(configuration: configuration)
    }

    /// Reads both files. Skipped when the last read began less than `minimumInterval` ago, unless `force`.
    public func refresh(force: Bool = false, now: Date = .now) async {
        guard !refreshing else { return }
        if !force, let lastRefresh, now.timeIntervalSince(lastRefresh) < minimumInterval { return }
        refreshing = true
        lastRefresh = now
        defer { refreshing = false }
        async let eventsDone: Void = refreshEvents()
        async let stormDone: Void = refreshStorm()
        _ = await (eventsDone, stormDone)
    }

    private func get(_ url: URL) async throws -> Data {
        guard FringeHosts.isAllowed(url) else { throw URLError(.appTransportSecurityRequiresSecureConnection) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private func refreshEvents() async {
        do {
            let data = try await get(FringeHosts.events)
            let list = try FringeFeed.events(from: data)
            guard !list.isEmpty else { throw URLError(.cannotParseResponse) }   // never replace good data with an empty file
            try? keep(data, as: "events.json")
            events = list
            source = .network
            eventsUpdated = .now
            eventsUnavailable = false
        } catch {
            if !Task.isCancelled { eventsUnavailable = true }
        }
    }

    private func refreshStorm() async {
        do {
            let data = try await get(FringeHosts.storm)
            guard let headline = StormHeadline.parse(data) else { throw URLError(.cannotParseResponse) }
            // Keep only what the app shows, not the whole index.
            try? keep(try JSONEncoder().encode(headline.asIndex), as: "storm.json")
            storm = headline
            stormUpdated = .now
            stormUnavailable = false
        } catch {
            if !Task.isCancelled { stormUnavailable = true }
        }
    }

    private func keep(_ data: Data, as name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}

extension StormHeadline {
    /// The headline written back in the index's own shape, so the one parser reads the file kept on the device.
    struct KeptIndex: Encodable {
        struct Incident: Encodable {
            struct Headline: Encodable { let text: String; let source: String; let url: String?; let at: String }
            let title: String
            let status = "open"
            let headline: Headline
        }
        let incidents: [Incident]
        let built_at: String?
        let site: String
    }

    var asIndex: KeptIndex {
        KeptIndex(incidents: [.init(title: incident, headline: .init(text: text, source: source, url: sourceURL?.absoluteString, at: at))],
                  built_at: builtAt, site: siteURL.absoluteString)
    }
}
