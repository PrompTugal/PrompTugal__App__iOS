import CoreLocation
import Foundation
import MapKit
import SwiftUI

// The venue map (Indi's option B, 9 November 2026): Apple Maps with our own venue drawing on top.
// venue.geojson is ours: buildings from OpenStreetMap (© OpenStreetMap contributors, ODbL) and places Web Summit
// publishes in words. It is never Web Summit's own map. The same file is on the team site for the web and Android.

/// One building or area: a coloured, labelled shape.
struct VenueArea: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: String
    let rings: [[CLLocationCoordinate2D]]
    let centre: CLLocationCoordinate2D

    static func == (a: VenueArea, b: VenueArea) -> Bool { a.id == b.id }
}

/// One named place: registration, an entrance, a stage, our stand.
struct VenuePoint: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let kind: String
    let detail: String
    let hours: String?
    let source: String
    let approximate: Bool
    var coordinate = CLLocationCoordinate2D()

    enum CodingKeys: String, CodingKey { case id, name, kind, detail, hours, source, approximate }

    static func == (a: VenuePoint, b: VenuePoint) -> Bool { a.id == b.id }
}

struct VenueMapData {
    let areas: [VenueArea]
    let points: [VenuePoint]

    static let credit = "Map data © OpenStreetMap contributors"

    enum LoadError: Error { case missingFile, badFeature(String) }

    private struct AreaProps: Decodable { let id: String; let name: String; let kind: String }

    /// Decodes our GeoJSON with MapKit's own decoder.
    static func decode(_ data: Data) throws -> VenueMapData {
        let objects = try MKGeoJSONDecoder().decode(data)
        var areas: [VenueArea] = []
        var points: [VenuePoint] = []
        for case let feature as MKGeoJSONFeature in objects {
            guard let props = feature.properties else { throw LoadError.badFeature(feature.identifier ?? "?") }
            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon {
                    let p = try JSONDecoder().decode(AreaProps.self, from: props)
                    areas.append(VenueArea(id: p.id, name: p.name, kind: p.kind, rings: [polygon.coordinateList],
                                           centre: polygon.coordinate))
                } else if let point = geometry as? MKPointAnnotation {
                    var p = try JSONDecoder().decode(VenuePoint.self, from: props)
                    p.coordinate = point.coordinate
                    points.append(p)
                } else {
                    throw LoadError.badFeature(feature.identifier ?? "?")
                }
            }
        }
        return VenueMapData(areas: areas, points: points)
    }

    static func bundled(_ bundle: Bundle = .main) throws -> VenueMapData {
        guard let url = bundle.url(forResource: "venue", withExtension: "geojson") else { throw LoadError.missingFile }
        return try decode(Data(contentsOf: url))
    }

    /// The venue itself, not the airport: where the map opens.
    var venueRegion: MKCoordinateRegion {
        let all = areas.flatMap { $0.rings.flatMap { $0 } }
        guard !all.isEmpty else { return MKCoordinateRegion(center: .init(latitude: 38.769, longitude: -9.095), latitudinalMeters: 1200, longitudinalMeters: 1200) }
        let lats = all.map(\.latitude), lons = all.map(\.longitude)
        let centre = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        return MKCoordinateRegion(center: centre, span: .init(latitudeDelta: (lats.max()! - lats.min()!) * 1.3,
                                                              longitudeDelta: (lons.max()! - lons.min()!) * 1.3))
    }
}

extension MKMultiPoint {
    var coordinateList: [CLLocationCoordinate2D] {
        var list = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&list, range: NSRange(location: 0, length: pointCount))
        return list
    }
}

enum VenueStyle {
    static func colour(for kind: String) -> Color {
        switch kind {
        case "hall": Palette.blue
        case "arena": Palette.red
        case "landmark": Palette.amber
        case "station": Palette.green
        case "site": Palette.muted
        default: Palette.ink
        }
    }

    static func symbol(for kind: String) -> String {
        switch kind {
        case "registration": "person.text.rectangle"
        case "entrance": "door.left.hand.open"
        case "stage": "music.mic"
        case "stand": "star.fill"
        default: "mappin"
        }
    }

    static func tint(for kind: String) -> Color {
        switch kind {
        case "registration": Palette.green
        case "entrance": Palette.blue
        case "stage": Palette.red
        case "stand": Palette.amber
        default: Palette.ink
        }
    }
}

/// Asks for location only when the person taps "Show me", and only while the app is in use.
/// The position stays on this iPhone: the app draws it and sends it nowhere.
@MainActor @Observable
final class VenueLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    func ask() { manager.requestWhenInUseAuthorization() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.status = s }
    }
}

struct VenueMapView: View {
    @State private var data: VenueMapData?
    @State private var failed = false
    @State private var position: MapCameraPosition = .automatic
    @State private var chosen: VenuePoint?
    @State private var location = VenueLocation()
    @Environment(\.openURL) private var openURL

    static let webSummitApp = URL(string: "https://websummit.com/app/")!

    var body: some View {
        Group {
            if let data {
                map(data)
            } else if failed {
                ContentUnavailableView("The venue map could not be read", systemImage: "map")
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Venue map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let d = try VenueMapData.bundled()
                data = d
                position = .region(d.venueRegion)
            } catch { failed = true }
        }
        .sheet(item: $chosen) { p in VenuePointSheet(point: p).presentationDetents([.medium, .large]) }
    }

    private func map(_ data: VenueMapData) -> some View {
        Map(position: $position) {
            ForEach(data.areas) { area in
                ForEach(Array(area.rings.enumerated()), id: \.offset) { _, ring in
                    MapPolygon(coordinates: ring)
                        .foregroundStyle(VenueStyle.colour(for: area.kind).opacity(area.kind == "site" ? 0.08 : 0.25))
                        .stroke(VenueStyle.colour(for: area.kind), lineWidth: area.kind == "site" ? 1 : 2)
                }
                if area.kind != "site" {
                    Annotation(area.name, coordinate: area.centre, anchor: .center) {
                        Text(area.name).font(.caption.weight(.bold)).foregroundStyle(VenueStyle.colour(for: area.kind))
                            .padding(.horizontal, 4).background(Palette.card.opacity(0.85), in: Capsule())
                    }
                    .annotationTitles(.hidden)
                }
            }
            ForEach(data.points) { p in
                Annotation(p.name, coordinate: p.coordinate) {
                    Button { chosen = p } label: {
                        Image(systemName: VenueStyle.symbol(for: p.kind))
                            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(VenueStyle.tint(for: p.kind), in: Circle())
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(p.name)
                }
            }
            if location.allowed { UserAnnotation() }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .bottom) { footer(data) }
    }

    private func footer(_ data: VenueMapData) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Button { position = .region(data.venueRegion) } label: {
                    Label("Venue", systemImage: "building.2").frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                if location.allowed {
                    Button { withAnimation { position = .userLocation(fallback: .region(data.venueRegion)) } } label: {
                        Label("Me", systemImage: "location.fill").frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                } else if location.status == .notDetermined {
                    Button { location.ask() } label: {
                        Label("Show me", systemImage: "location").frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button { openURL(Self.webSummitApp) } label: {
                    Label("Open Web Summit's app", systemImage: "arrow.up.right.square").frame(minHeight: 44)
                }
                .buttonStyle(.bordered).tint(Palette.red)
            }
            Text("Our own simple drawing, not Web Summit's floor plan. Your position stays on this iPhone. \(VenueMapData.credit).")
                .font(.caption2).foregroundStyle(Palette.muted)
        }
        .padding(Space.m)
        .background(.regularMaterial)
    }
}

private struct VenuePointSheet: View {
    let point: VenuePoint
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Label(point.name, systemImage: VenueStyle.symbol(for: point.kind))
                        .font(Typo.title).foregroundStyle(VenueStyle.tint(for: point.kind))
                    Text(point.detail)
                    if let hours = point.hours {
                        Text("HOURS").font(Typo.kicker).tracking(1).foregroundStyle(Palette.red)
                        Text(hours)
                    }
                    if point.approximate {
                        Text("The pin is approximate.").font(Typo.meta).foregroundStyle(Palette.muted)
                    }
                    Button { VenueDirections.open(point) } label: {
                        Label("Directions in Apple Maps", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(Palette.red)
                    Text("Source: \(point.source)").font(.caption2).foregroundStyle(Palette.muted)
                }
                .padding(Space.l)
            }
            .background(Palette.paper)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

enum VenueDirections {
    /// Opens Apple Maps with the place as the destination. Apple Maps asks for the start itself.
    static func mapItem(for point: VenuePoint) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coordinate))
        item.name = point.name
        return item
    }

    @MainActor static func open(_ point: VenuePoint) {
        mapItem(for: point).openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
