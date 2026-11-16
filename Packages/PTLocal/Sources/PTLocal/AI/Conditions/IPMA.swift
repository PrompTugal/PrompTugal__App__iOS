import Foundation

// Local conditions from IPMA (Instituto Português do Mar e da Atmosfera) open data, read directly by the app: public,
// no key. Three feeds, as the storm incident's weather connectors used them:
//   warnings      https://api.ipma.pt/open-data/forecast/warnings/warnings_www.json   (area "FAR" is the whole Algarve)
//   forecast      https://api.ipma.pt/open-data/forecast/meteorology/cities/daily/<globalIdLocal>.json
//   observations  https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json (hourly, UTC, last 24 h)
//                 with the stations at .../observation/meteorology/stations/stations.json
// -99 in an observation means "no reading"; it is shown as missing, never as a number.

public enum IPMA {
    public static let base = URL(string: "https://api.ipma.pt/open-data/")!
    public static let warningsURL = base.appendingPathComponent("forecast/warnings/warnings_www.json")
    public static let observationsURL = base.appendingPathComponent("observation/meteorology/stations/observations.json")
    public static let stationsURL = base.appendingPathComponent("observation/meteorology/stations/stations.json")
    public static func forecastURL(_ id: Int) -> URL { base.appendingPathComponent("forecast/meteorology/cities/daily/\(id).json") }
    /// IPMA's public page for people, linked from the card.
    public static let page = URL(string: "https://www.ipma.pt/en/")!
    /// The warning area of the Algarve (district of Faro).
    public static let algarveArea = "FAR"

    /// The four Algarve places IPMA forecasts daily; each of the 17 towns uses the nearest.
    public static let forecastCities: [ForecastCity] = [
        ForecastCity(id: 1080500, name: "Faro", latitude: 37.0146, longitude: -7.9331),
        ForecastCity(id: 1080800, name: "Loulé", latitude: 37.1397, longitude: -8.0202),
        ForecastCity(id: 1081100, name: "Portimão", latitude: 37.1500, longitude: -8.5200),
        ForecastCity(id: 1081505, name: "Sagres", latitude: 37.0168, longitude: -8.9403),
    ]

    public struct ForecastCity: Sendable, Hashable, Identifiable {
        public let id: Int
        public let name: String
        public let latitude: Double
        public let longitude: Double
    }

    /// The forecast city nearest a town.
    public static func forecastCity(for town: PlaceInfo) -> ForecastCity {
        forecastCities.min {
            NearMe.distance(lat1: town.latitude, lon1: town.longitude, lat2: $0.latitude, lon2: $0.longitude)
                < NearMe.distance(lat1: town.latitude, lon1: town.longitude, lat2: $1.latitude, lon2: $1.longitude)
        }!
    }

    // MARK: Warnings

    /// Warnings for an area that are above green and not yet over, worst first.
    public static func activeWarnings(_ all: [Warning], area: String = algarveArea, now: Date = Date()) -> [Warning] {
        all.filter { $0.area == area && $0.level.rank > 0 && ($0.end.map { $0 > now } ?? true) }
            .sorted { $0.level.rank != $1.level.rank ? $0.level.rank > $1.level.rank : ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    public struct Warning: Decodable, Sendable, Hashable, Identifiable {
        public var id: String { area + "|" + type + "|" + startTime }
        public let text: String
        public let type: String
        public let area: String
        public let startTime: String
        public let endTime: String
        public let levelID: String

        enum CodingKeys: String, CodingKey {
            case text, startTime, endTime
            case type = "awarenessTypeName", area = "idAreaAviso", levelID = "awarenessLevelID"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = (try? c.decode(String.self, forKey: .text)) ?? ""
            type = (try? c.decode(String.self, forKey: .type)) ?? "Aviso"
            area = (try? c.decode(String.self, forKey: .area)) ?? ""
            startTime = (try? c.decode(String.self, forKey: .startTime)) ?? ""
            endTime = (try? c.decode(String.self, forKey: .endTime)) ?? ""
            levelID = (try? c.decode(String.self, forKey: .levelID)) ?? "green"
        }

        public var level: Level { Level(rawValue: levelID.lowercased()) ?? .green }
        /// IPMA writes warning times in Portugal's local time, without a zone.
        public var start: Date? { IPMA.lisbonDate(startTime) }
        public var end: Date? { IPMA.lisbonDate(endTime) }
        /// The warning type in English, with IPMA's Portuguese name kept beside it.
        public var typeEnglish: String { IPMA.warningTypes[type] ?? type }
    }

    public enum Level: String, Sendable {
        case green, yellow, orange, red
        public var rank: Int { switch self { case .green: 0; case .yellow: 1; case .orange: 2; case .red: 3 } }
        public var label: String { rawValue.capitalized }
    }

    static let warningTypes: [String: String] = [
        "Agitação Marítima": "Rough sea", "Nevoeiro": "Fog", "Vento": "Wind", "Precipitação": "Rain",
        "Neve": "Snow", "Trovoada": "Thunderstorms", "Tempo Quente": "Hot weather", "Tempo Frio": "Cold weather",
    ]

    // MARK: Forecast

    public struct ForecastFile: Decodable, Sendable {
        public let globalIdLocal: Int
        public let dataUpdate: String?
        public let data: [Day]
    }

    public struct Day: Decodable, Sendable, Hashable {
        public let forecastDate: String
        public let tMin: String?
        public let tMax: String?
        public let precipitaProb: String?
        public let predWindDir: String?
        public let idWeatherType: Int?
        public let classWindSpeed: Int?

        public var weather: String? { idWeatherType.flatMap { IPMA.weatherTypes[$0] } }
        public var windClass: String? {
            switch classWindSpeed { case 1: "weak"; case 2: "moderate"; case 3: "strong"; case 4: "very strong"; default: nil }
        }
        public var rainChance: Int? { precipitaProb.flatMap(Double.init).map { Int($0.rounded()) } }
    }

    /// IPMA's weather types (its weather-type-classe list), in English.
    static let weatherTypes: [Int: String] = [
        0: "No information", 1: "Clear sky", 2: "Partly cloudy", 3: "Sunny intervals", 4: "Cloudy",
        5: "Cloudy (high cloud)", 6: "Showers", 7: "Light showers", 8: "Heavy showers", 9: "Rain", 10: "Light rain",
        11: "Heavy rain", 12: "Intermittent rain", 13: "Intermittent light rain", 14: "Intermittent heavy rain",
        15: "Drizzle", 16: "Mist", 17: "Fog", 18: "Snow", 19: "Thunderstorms", 20: "Showers and thunderstorms",
        21: "Hail", 22: "Frost", 23: "Rain and thunderstorms", 24: "Convective clouds", 25: "Partly cloudy",
        26: "Fog", 27: "Cloudy",
    ]

    // MARK: Observations

    public struct Station: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let latitude: Double
        public let longitude: Double
    }

    /// stations.json is GeoJSON: features with [lon, lat] and properties idEstacao, localEstacao.
    public static func decodeStations(_ data: Data) throws -> [Station] {
        struct Feature: Decodable {
            struct Geometry: Decodable { let coordinates: [Double] }
            struct Properties: Decodable { let idEstacao: Int; let localEstacao: String }
            let geometry: Geometry
            let properties: Properties
        }
        return try JSONDecoder().decode([Lenient<Feature>].self, from: data).compactMap(\.value).compactMap { f in
            guard f.geometry.coordinates.count >= 2 else { return nil }
            return Station(id: String(f.properties.idEstacao), name: f.properties.localEstacao,
                           latitude: f.geometry.coordinates[1], longitude: f.geometry.coordinates[0])
        }
    }

    public struct Observation: Decodable, Sendable, Hashable {
        let intensidadeVentoKM: Double?
        let temperatura: Double?
        let idDireccVento: Int?
        let precAcumulada: Double?
        let humidade: Double?

        /// -99 (and anything absurd) is "no reading".
        static func valid(_ value: Double?) -> Double? { value.flatMap { $0 <= -90 ? nil : $0 } }

        public var windKmh: Double? { Self.valid(intensidadeVentoKM) }
        public var temperature: Double? { Self.valid(temperatura) }
        public var rainMm: Double? { Self.valid(precAcumulada) }
        public var humidity: Double? { Self.valid(humidade) }
        public var wind: WindDirection? { idDireccVento.flatMap(WindDirection.init(code:)) }
        var isUseful: Bool { temperature != nil || windKmh != nil }
        var isComplete: Bool { temperature != nil && windKmh != nil }
    }

    /// observations.json: hour ("2026-11-15T23:00", UTC) → station id → reading or null.
    public typealias Observations = [String: [String: Observation?]]

    public static func decodeObservations(_ data: Data) throws -> Observations {
        // One odd reading must not lose the hour: decode each leniently.
        let raw = try JSONDecoder().decode([String: [String: Lenient<Observation>?]].self, from: data)
        return raw.mapValues { hour in hour.mapValues { $0?.value } }
    }

    public struct Reading: Sendable, Hashable {
        public let station: Station
        /// Metres from the town.
        public let distance: Double
        public let time: Date
        public let observation: Observation
    }

    /// The latest reading near a point: the newest hour (of the last three) in which a station within `radius` has a
    /// reading; the nearest station with both temperature and wind, else the nearest with either.
    public static func latestReading(_ observations: Observations, stations: [Station], latitude: Double, longitude: Double,
                                     radius: Double = 40_000) -> Reading? {
        let near = stations
            .map { (station: $0, distance: NearMe.distance(lat1: latitude, lon1: longitude, lat2: $0.latitude, lon2: $0.longitude)) }
            .filter { $0.distance <= radius }
            .sorted { $0.distance < $1.distance }
        guard !near.isEmpty else { return nil }
        for hour in observations.keys.sorted(by: >).prefix(3) {
            guard let readings = observations[hour], let time = utcHour(hour) else { continue }
            let found = near.first { readings[$0.station.id]??.isComplete == true }
                ?? near.first { readings[$0.station.id]??.isUseful == true }
            if let found, let observation = readings[found.station.id] ?? nil {
                return Reading(station: found.station, distance: found.distance, time: time, observation: observation)
            }
        }
        return nil
    }

    // MARK: Dates

    static func lisbonDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Lisbon")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: text)
    }

    static func utcHour(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)
    }
}

/// IPMA's wind direction codes: 1 N, 2 NE, 3 E, 4 SE, 5 S, 6 SW, 7 W, 8 NW, 9 N; 0 is calm or variable.
public struct WindDirection: Sendable, Hashable {
    public let label: String
    /// Compass degrees the wind blows from.
    public let degrees: Double

    public init?(code: Int) {
        let table: [Int: (String, Double)] = [1: ("N", 0), 2: ("NE", 45), 3: ("E", 90), 4: ("SE", 135), 5: ("S", 180),
                                               6: ("SW", 225), 7: ("W", 270), 8: ("NW", 315), 9: ("N", 0)]
        guard let entry = table[code] else { return nil }
        label = entry.0
        degrees = entry.1
    }

    /// From a forecast's letters ("NW").
    public init?(letters: String) {
        let codes = ["N": 1, "NE": 2, "E": 3, "SE": 4, "S": 5, "SW": 6, "W": 7, "NW": 8]
        guard let code = codes[letters.uppercased()] else { return nil }
        self.init(code: code)
    }

    /// The way an arrow points: where the wind goes, opposite where it comes from.
    public var arrowDegrees: Double { (degrees + 180).truncatingRemainder(dividingBy: 360) }
}
