import Foundation
import Testing
@testable import PTLocal

// Fixtures in the shapes IPMA's open data had on 15 November 2026.
private let warningsJSON = """
[{"text":"Na costa Ocidental, ondas de noroeste com 4 a 5 metros.","awarenessTypeName":"Agitação Marítima","idAreaAviso":"FAR",
  "startTime":"2026-11-18T12:00:00","awarenessLevelID":"yellow","endTime":"2026-11-18T19:00:00"},
 {"text":"","awarenessTypeName":"Nevoeiro","idAreaAviso":"FAR","startTime":"2026-11-15T19:16:00","awarenessLevelID":"green","endTime":"2026-11-18T19:00:00"},
 {"text":"Vento forte","awarenessTypeName":"Vento","idAreaAviso":"FAR","startTime":"2026-11-14T00:00:00","awarenessLevelID":"orange","endTime":"2026-11-14T12:00:00"},
 {"text":"","awarenessTypeName":"Vento","idAreaAviso":"LSB","startTime":"2026-11-18T00:00:00","awarenessLevelID":"red","endTime":"2026-11-19T00:00:00"},
 {"text":"Chuva","awarenessTypeName":"Precipitação","idAreaAviso":"FAR","startTime":"2026-11-17T06:00:00","awarenessLevelID":"orange","endTime":"2026-11-17T18:00:00"}]
"""

private let stationsJSON = """
[{"geometry":{"type":"Point","coordinates":[-7.97,37.016]},"type":"Feature","properties":{"idEstacao":1200554,"localEstacao":"Faro (Aeródromo)"}},
 {"geometry":{"type":"Point","coordinates":[-7.821,37.033]},"type":"Feature","properties":{"idEstacao":1210881,"localEstacao":"Olhão, EPPO"}},
 {"geometry":{"type":"Point","coordinates":[-8.949,37.012]},"type":"Feature","properties":{"idEstacao":1200533,"localEstacao":"Sagres"}},
 {"geometry":{"type":"Point","coordinates":[-9.14,38.72]},"type":"Feature","properties":{"idEstacao":1200579,"localEstacao":"Lisboa"}}]
"""

private let observationsJSON = """
{"2026-11-15T22:00":{"1200554":{"intensidadeVentoKM":9.0,"temperatura":15.5,"idDireccVento":7,"precAcumulada":0.0,"humidade":90.0},
                      "1210881":null},
 "2026-11-15T23:00":{"1200554":{"intensidadeVentoKM":7.2,"temperatura":-99.0,"idDireccVento":1,"precAcumulada":-99.0,"humidade":-99.0},
                      "1210881":{"intensidadeVentoKM":4.3,"temperatura":14.9,"idDireccVento":8,"precAcumulada":0.2,"humidade":97.0},
                      "1200533":{"intensidadeVentoKM":4.3,"temperatura":12.3,"idDireccVento":3,"precAcumulada":0.0,"humidade":100.0}}}
"""

@Suite("IPMA conditions")
struct ConditionsTests {
    @Test("Warnings: only the Algarve, above green, not over yet, worst first")
    func warnings() throws {
        let all = try JSONDecoder().decode([IPMA.Warning].self, from: Data(warningsJSON.utf8))
        let now = try #require(IPMA.lisbonDate("2026-11-16T00:30:00"))
        let active = IPMA.activeWarnings(all, now: now)
        #expect(active.map(\.type) == ["Precipitação", "Agitação Marítima"])
        #expect(active.first?.level == .orange)
        #expect(active.last?.typeEnglish == "Rough sea")
        #expect(active.allSatisfy { $0.area == "FAR" })
    }

    @Test("Each town uses the nearest of IPMA's four Algarve forecast points")
    func forecastCities() {
        func city(_ id: String) -> String { IPMA.forecastCity(for: PlaceDirectory.info(id)!).name }
        #expect(city("faro") == "Faro")
        #expect(city("olhao") == "Faro")
        #expect(city("loule") == "Loulé")
        #expect(city("lagos") == "Portimão")
        #expect(city("vila-do-bispo") == "Sagres")
        #expect(PlaceDirectory.towns.allSatisfy { IPMA.forecastCities.contains(IPMA.forecastCity(for: $0)) })
    }

    @Test("Stations decode from GeoJSON, [lon, lat]")
    func stations() throws {
        let stations = try IPMA.decodeStations(Data(stationsJSON.utf8))
        #expect(stations.count == 4)
        #expect(stations[0].id == "1200554")
        #expect(abs(stations[0].latitude - 37.016) < 0.0001)
        #expect(abs(stations[0].longitude + 7.97) < 0.0001)
    }

    @Test("The latest hour wins; -99 is missing; a complete reading beats a nearer partial one")
    func latestReading() throws {
        let stations = try IPMA.decodeStations(Data(stationsJSON.utf8))
        let observations = try IPMA.decodeObservations(Data(observationsJSON.utf8))
        let faro = PlaceDirectory.info("faro")!
        let reading = try #require(IPMA.latestReading(observations, stations: stations, latitude: faro.latitude, longitude: faro.longitude))
        // Faro airport is nearer but has no temperature at 23:00; Olhão has both.
        #expect(reading.station.name == "Olhão, EPPO")
        #expect(reading.time == IPMA.utcHour("2026-11-15T23:00"))
        #expect(reading.observation.temperature == 14.9)
        #expect(reading.observation.wind?.label == "NW")
        #expect(reading.observation.rainMm == 0.2)

        let airport = observations["2026-11-15T23:00"]?["1200554"] ?? nil
        #expect(airport?.temperature == nil)
        #expect(airport?.rainMm == nil)
        #expect(airport?.windKmh == 7.2)

        // Nothing within 40 km of Alcoutim in the fixture.
        let alcoutim = PlaceDirectory.info("alcoutim")!
        #expect(IPMA.latestReading(observations, stations: stations, latitude: alcoutim.latitude, longitude: alcoutim.longitude) == nil)
    }

    @Test("Wind codes: 1 and 9 are north, 0 is calm; the arrow points where the wind goes")
    func wind() {
        #expect(WindDirection(code: 1)?.label == "N")
        #expect(WindDirection(code: 9)?.label == "N")
        #expect(WindDirection(code: 0) == nil)
        #expect(WindDirection(code: 8)?.degrees == 315)
        #expect(WindDirection(code: 8)?.arrowDegrees == 135)
        #expect(WindDirection(letters: "sw")?.degrees == 225)
    }

    @Test("Forecast days read IPMA's strings and codes")
    func forecast() throws {
        let json = """
        {"owner":"IPMA","country":"PT","globalIdLocal":1080500,"dataUpdate":"2026-11-15T23:31:02","data":[
         {"precipitaProb":"7.0","tMin":"12.4","tMax":"19.7","predWindDir":"W","idWeatherType":3,"classWindSpeed":1,
          "longitude":"-7.9331","forecastDate":"2026-11-15","latitude":"37.0146"}]}
        """
        let file = try JSONDecoder().decode(IPMA.ForecastFile.self, from: Data(json.utf8))
        let day = try #require(file.data.first)
        #expect(day.weather == "Sunny intervals")
        #expect(day.windClass == "weak")
        #expect(day.rainChance == 7)
    }

    @Test("The store reads every feed once, then serves its copy offline and says so")
    @MainActor func store() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ipma-\(UUID().uuidString)")
        let cache = LocalDiskCache(directory: dir)
        defer { cache.clear() }
        let forecast = #"{"globalIdLocal":1080500,"data":[{"forecastDate":"2026-11-16","tMin":"11","tMax":"18","idWeatherType":1}]}"#
        let live = ConditionsStore(fetch: { url in
            let path = url.path
            if path.hasSuffix("warnings_www.json") { return Data(warningsJSON.utf8) }
            if path.hasSuffix("observations.json") { return Data(observationsJSON.utf8) }
            if path.hasSuffix("stations.json") { return Data(stationsJSON.utf8) }
            return Data(forecast.utf8)
        }, cache: cache)
        await live.refresh(force: true)
        #expect(live.provenance.isLive)
        #expect(live.stations.count == 4)
        let now = try #require(IPMA.lisbonDate("2026-11-16T00:30:00"))
        let faro = live.conditions(for: PlaceDirectory.info("faro")!, now: now)
        #expect(faro.forecastCity.name == "Faro")
        #expect(faro.today?.tMax == "18")
        #expect(faro.reading?.station.name == "Olhão, EPPO")
        #expect(faro.warnings.count == 2)

        let offline = ConditionsStore(fetch: { _ in throw URLError(.notConnectedToInternet) }, cache: cache)
        #expect(!offline.provenance.isLive)
        #expect(offline.stations.count == 4)
        await offline.refresh(force: true)
        #expect(!offline.provenance.isLive)
        #expect(offline.problem != nil)
        #expect(offline.conditions(for: PlaceDirectory.info("faro")!, now: now).reading != nil)
    }
}
