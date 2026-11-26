import Foundation
import Observation
import PTCore

/// Where the conditions came from, said on the card.
public enum ConditionsProvenance: Equatable, Sendable {
    case live(Date)
    case cached(Date?)
    case none

    public var label: String {
        switch self {
        case .live: LocalText.string("Live from IPMA")
        case .cached: LocalText.string("Offline: the last IPMA data this device read")
        case .none: LocalText.string("Not loaded yet")
        }
    }

    public var isLive: Bool { if case .live = self { true } else { false } }
}

/// One town's conditions now: the Algarve's active warnings, the nearest station's latest reading, and today's
/// forecast for the nearest IPMA forecast city.
public struct TownConditions: Sendable {
    public let town: PlaceInfo
    public let warnings: [IPMA.Warning]
    public let reading: IPMA.Reading?
    public let forecastCity: IPMA.ForecastCity
    public let today: IPMA.Day?
}

/// Reads IPMA's open data (no key), at most every ten minutes, with this device's last copy when offline.
@MainActor @Observable
public final class ConditionsStore {
    public static let shared = ConditionsStore()
    public static let interval: TimeInterval = 600

    public private(set) var warnings: [IPMA.Warning] = []
    public private(set) var stations: [IPMA.Station] = []
    public private(set) var observations: IPMA.Observations = [:]
    public private(set) var forecasts: [Int: IPMA.ForecastFile] = [:]
    public private(set) var provenance: ConditionsProvenance = .none
    public private(set) var loading = false
    public private(set) var problem: String?

    @ObservationIgnored private let fetch: LocalFetch
    @ObservationIgnored private let cache: LocalDiskCache
    @ObservationIgnored private var lastAttempt: Date?

    public init(fetch: @escaping LocalFetch = { url in
        try await HTTPClient.shared.get(url, timeout: 25, label: "ipma", maxBytes: 4 * 1024 * 1024)
    }, cache: LocalDiskCache = .standard()) {
        self.fetch = fetch
        self.cache = cache
        loadCache()
    }

    public func conditions(for town: PlaceInfo, now: Date = Date()) -> TownConditions {
        let city = IPMA.forecastCity(for: town)
        let days = forecasts[city.id]?.data ?? []
        let today = Self.dayString(now)
        return TownConditions(
            town: town,
            warnings: IPMA.activeWarnings(warnings, now: now),
            reading: IPMA.latestReading(observations, stations: stations, latitude: town.latitude, longitude: town.longitude),
            forecastCity: city,
            today: days.first { $0.forecastDate == today } ?? days.first)
    }

    /// Reads everything again unless it was read less than ten minutes ago.
    public func refresh(force: Bool = false) async {
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < Self.interval - 5 { return }
        guard !loading else { return }
        lastAttempt = Date()
        loading = true
        defer { loading = false }

        var jobs: [(key: String, url: URL)] = [("ipma-warnings", IPMA.warningsURL), ("ipma-observations", IPMA.observationsURL)]
        if stations.isEmpty { jobs.append(("ipma-stations", IPMA.stationsURL)) }
        for city in IPMA.forecastCities { jobs.append(("ipma-forecast-\(city.id)", IPMA.forecastURL(city.id))) }

        var results: [String: Data] = [:]
        var live = 0, failed = 0
        await withTaskGroup(of: (String, Data?, Bool).self) { group in
            for job in jobs {
                group.addTask { [fetch, cache] in
                    let result = await Self.load(job.url, key: job.key, fetch: fetch, cache: cache)
                    return (job.key, result?.data, result?.live ?? false)
                }
            }
            for await (key, data, isLive) in group {
                if let data { results[key] = data }
                if isLive { live += 1 } else { failed += 1 }
            }
        }

        if let data = results["ipma-warnings"],
           let decoded = try? JSONDecoder().decode([Lenient<IPMA.Warning>].self, from: data) {
            warnings = decoded.compactMap(\.value)
        }
        if let data = results["ipma-observations"], let decoded = try? IPMA.decodeObservations(data) { observations = decoded }
        if let data = results["ipma-stations"], let decoded = try? IPMA.decodeStations(data) { stations = decoded }
        for city in IPMA.forecastCities {
            if let data = results["ipma-forecast-\(city.id)"],
               let decoded = try? JSONDecoder().decode(IPMA.ForecastFile.self, from: data) {
                forecasts[city.id] = decoded
            }
        }

        if live > 0 && failed == 0 {
            provenance = .live(Date())
            problem = nil
        } else if live > 0 {
            provenance = .live(Date())
            problem = LocalText.string("Some IPMA feeds could not be read; their last copy is shown.")
        } else {
            provenance = .cached(cache.modified(key: "ipma-observations") ?? cache.modified(key: "ipma-warnings"))
            problem = LocalText.string("IPMA could not be reached.")
        }
    }

    /// The live bytes (true), or this device's last copy (false), or nil.
    private nonisolated static func load(_ url: URL, key: String, fetch: LocalFetch,
                                         cache: LocalDiskCache) async -> (data: Data, live: Bool)? {
        do {
            let data = try await fetch(url)
            cache.store(data, key: key)
            return (data, true)
        } catch {
            return cache.load(key: key).map { (data: $0, live: false) }
        }
    }

    private func loadCache() {
        if let data = cache.load(key: "ipma-warnings"),
           let decoded = try? JSONDecoder().decode([Lenient<IPMA.Warning>].self, from: data) {
            warnings = decoded.compactMap(\.value)
        }
        if let data = cache.load(key: "ipma-stations"), let decoded = try? IPMA.decodeStations(data) { stations = decoded }
        if let data = cache.load(key: "ipma-observations"), let decoded = try? IPMA.decodeObservations(data) { observations = decoded }
        for city in IPMA.forecastCities {
            if let data = cache.load(key: "ipma-forecast-\(city.id)"),
               let decoded = try? JSONDecoder().decode(IPMA.ForecastFile.self, from: data) {
                forecasts[city.id] = decoded
            }
        }
        if !observations.isEmpty || !warnings.isEmpty {
            provenance = .cached(cache.modified(key: "ipma-observations") ?? cache.modified(key: "ipma-warnings"))
        }
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Lisbon")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
