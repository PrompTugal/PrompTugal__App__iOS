import Foundation
import Observation
import PTCore

/// Reads ci-status.json: first the live copy on the `ci-status` branch (rewritten about every ten minutes by
/// ci-status.yml), then the copy the product site was last built with, then this device's last copy.
@MainActor @Observable
public final class CIStatusStore {
    public static let shared = CIStatusStore()

    /// The live copy. raw.githubusercontent.com caches for up to five minutes; a query string asks for a fresh one.
    public nonisolated static let liveURL = URL(string: "https://raw.githubusercontent.com/PrompTugal/PrompTugal__App__iOS/ci-status/ci-status.json")!
    /// The copy from the last site build (website.yml), when the live one cannot be read.
    public nonisolated static let siteURL = URL(string: "https://ios.app.promptugal.news/ci-status.json")!
    public nonisolated static let pageURL = URL(string: "https://ios.app.promptugal.news/admin/status.html")!

    /// Where the status on screen came from.
    public enum Source: Equatable, Sendable {
        case live(Date)
        case siteCopy(Date)
        case cached(Date?)
        case none

        public var label: String {
            switch self {
            case .live: LocalText.string("Live from the ci-status branch")
            case .siteCopy: LocalText.string("The copy from the last site build")
            case .cached: LocalText.string("Offline: the last copy this device read")
            case .none: LocalText.string("Not loaded")
            }
        }

        public var isLive: Bool { if case .live = self { true } else { false } }
    }

    public private(set) var status: CIStatus?
    public private(set) var source: Source = .none
    public private(set) var phase: LoadPhase = .idle
    public let installed: InstalledBuild

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    static let cacheKey = "ci-status"

    public init(fetch: @escaping LocalFetch = CIStatusStore.liveFetch, cache: LocalDiskCache = .standard(),
                installed: InstalledBuild = .current()) {
        self.fetch = fetch
        self.cache = cache
        self.installed = installed
        if let data = cache.load(key: Self.cacheKey), let decoded = Self.decode(data) {
            status = decoded
            source = .cached(cache.modified(key: Self.cacheKey))
        }
    }

    public nonisolated static let liveFetch: LocalFetch = { url in
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await HTTPClient.shared.data(for: request, label: "ci-status", maxBytes: 2 * 1024 * 1024)
        guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    nonisolated static func decode(_ data: Data) -> CIStatus? {
        guard let status = try? JSONDecoder().decode(CIStatus.self, from: data), !status.pipelines.isEmpty else { return nil }
        return status
    }

    /// The latest TestFlight build of the app running this code.
    public var latestForThisApp: TestFlightBuild? { status?.testFlightBuild(bundle: installed.bundle) }
    public var update: InstalledBuild.Update { installed.update(against: latestForThisApp) }

    public func refresh(now: Date = .now) async {
        phase = .loading
        var live = URLComponents(url: Self.liveURL, resolvingAgainstBaseURL: false)!
        live.queryItems = [URLQueryItem(name: "t", value: String(Int(now.timeIntervalSince1970) / 30))]
        for (url, isLive) in [(live.url ?? Self.liveURL, true), (Self.siteURL, false)] {
            guard let data = try? await fetch(url), let decoded = Self.decode(data) else { continue }
            // A site copy older than what this device already has does not replace it.
            if !isLive, let current = status?.generatedAt, let other = decoded.generatedAt, other < current {
                continue
            }
            status = decoded
            source = isLive ? .live(now) : .siteCopy(now)
            cache.store(data, key: Self.cacheKey)
            phase = .loaded
            return
        }
        if status != nil {
            if case .none = source { source = .cached(cache.modified(key: Self.cacheKey)) }
            if case .live = source { source = .cached(cache.modified(key: Self.cacheKey)) }
            phase = .loaded
        } else {
            phase = .failed(LocalText.string("Could not read the CI status. Check the connection and try again."))
        }
    }
}
