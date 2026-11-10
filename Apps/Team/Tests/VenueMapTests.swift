import CoreLocation
import Foundation
import Testing
@testable import Team

/// The bundled venue.geojson (our own drawing, option B of Indi's venue map, 9 November 2026).
@Suite("Venue map: venue.geojson")
struct VenueMapTests {
    private func bundled() throws -> VenueMapData { try VenueMapData.bundled() }

    @Test("The file is bundled and MapKit decodes it")
    func decodes() throws {
        let data = try bundled()
        #expect(data.areas.count >= 8)
        #expect(data.points.count >= 6)
    }

    @Test("Every building the brief names is there, with a closed outline")
    func buildings() throws {
        let data = try bundled()
        let names = Set(data.areas.map(\.name))
        for name in ["Pavilion 1", "Pavilion 2", "Pavilion 3", "Pavilion 4", "MEO Arena", "Pavilhão de Portugal", "Oriente station"] {
            #expect(names.contains(name), "missing \(name)")
        }
        for area in data.areas {
            let ring = try #require(area.rings.first)
            #expect(ring.count >= 4)
        }
    }

    @Test("Both registration points, with hours and the source")
    func registration() throws {
        let reg = try bundled().points.filter { $0.kind == "registration" }
        #expect(reg.count == 2)
        #expect(reg.allSatisfy { $0.hours?.isEmpty == false })
        #expect(reg.allSatisfy { $0.source == "https://websummit.com/essentials/registration-essentials/" })
        #expect(reg.contains { $0.name.contains("Terminal 1") })
        #expect(reg.contains { $0.name.contains("Pavilhão de Portugal") })
    }

    @Test("Our stand, Centre Stage and the North Entrance are placed")
    func places() throws {
        let kinds = Set(try bundled().points.map(\.kind))
        #expect(kinds.isSuperset(of: ["stand", "stage", "entrance"]))
    }

    @Test("Everything at the venue is in Parque das Nações, and the airport is west of it")
    func coordinates() throws {
        let data = try bundled()
        let venue = data.areas.flatMap { $0.rings.flatMap { $0 } } + data.points.filter { $0.id != "registration-airport" }.map(\.coordinate)
        #expect(venue.allSatisfy { (38.76...38.78).contains($0.latitude) && (-9.11 ... -9.08).contains($0.longitude) })
        let airport = try #require(data.points.first { $0.id == "registration-airport" })
        #expect(airport.coordinate.longitude < -9.11)
        // negative control: a swapped longitude and latitude would land far from Lisbon
        #expect(!(38.76...38.78).contains(airport.coordinate.longitude))
    }

    @Test("The opening view frames the venue, not the airport")
    func region() throws {
        let region = try bundled().venueRegion
        #expect(abs(region.center.latitude - 38.77) < 0.01)
        #expect(abs(region.center.longitude - -9.095) < 0.01)
    }

    @Test("A broken file is refused, not drawn")
    func refusesBroken() {
        #expect(throws: (any Error).self) { try VenueMapData.decode(Data("{\"type\":\"Nope\"}".utf8)) }
        let noProps = #"{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[-9.09,38.77]},"properties":null}]}"#
        #expect(throws: (any Error).self) { try VenueMapData.decode(Data(noProps.utf8)) }
    }

    @Test("Directions go to the point, named")
    func directions() throws {
        let p = try #require(try bundled().points.first { $0.kind == "stand" })
        let item = VenueDirections.mapItem(for: p)
        #expect(item.name == p.name)
        #expect(abs(item.placemark.coordinate.latitude - p.coordinate.latitude) < 1e-9)
    }
}
