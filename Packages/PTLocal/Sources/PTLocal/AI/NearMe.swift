import CoreLocation
import Foundation
import Observation

// MARK: - The nearest town

public struct NearestTown: Sendable, Hashable {
    public let town: PlaceInfo
    /// Straight-line distance, metres.
    public let distance: Double

    /// Within the region: the reader is in or near one of the 17 places.
    public var isLocal: Bool { distance <= NearMe.localRadius }

    public var distanceText: String { NearMe.text(distance: distance) }
}

public enum NearMe {
    /// Farther than this from every town (about the width of the Algarve's municipalities), the screen says the reader
    /// is not in the Algarve rather than pretend a town is local.
    public static let localRadius: Double = 30_000

    /// "under 1 km", "4.2 km", "68 km".
    public static func text(distance: Double) -> String {
        let km = distance / 1000
        return km < 1 ? "under 1 km" : km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km"
    }

    /// The great-circle distance in metres (haversine, mean Earth radius). Pure, so tests need no location services.
    public static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// The nearest of the towns given (the 17 by default) to a point; nil only when the list is empty.
    public static func nearest(latitude: Double, longitude: Double,
                               among towns: [PlaceInfo] = PlaceDirectory.towns) -> NearestTown? {
        towns.map { NearestTown(town: $0, distance: distance(lat1: latitude, lon1: longitude, lat2: $0.latitude, lon2: $0.longitude)) }
            .min { $0.distance < $1.distance }
    }
}

// MARK: - Location while using the app

/// Asks for the reader's location only when they tap "Near me", only while the app is in use, once per tap. The
/// location stays on the device: the app works out which of the 17 towns is closest and keeps only that town's id.
/// Without permission the reader picks a town instead.
@MainActor @Observable
public final class NearMeLocator {
    public static let shared = NearMeLocator()

    public enum State: Equatable {
        case idle
        case asking
        case locating
        case found(NearestTown, Date)
        case denied
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// The town the reader picked by hand, when they would rather not share their location.
    public var pickedTown: String? {
        didSet { UserDefaults.standard.set(pickedTown, forKey: Self.pickedKey) }
    }
    static let pickedKey = "local.nearme.picked"

    @ObservationIgnored private var manager: CLLocationManager?
    @ObservationIgnored private var delegate: LocationDelegate?

    public init() {
        pickedTown = UserDefaults.standard.string(forKey: Self.pickedKey)
    }

    /// The town to show first: the one located this session, else the one picked.
    public var townID: String? {
        if case .found(let near, _) = state, near.isLocal { return near.town.id }
        return pickedTown
    }

    /// One location fix, asking for when-in-use permission first if it has not been asked.
    public func locate() {
        let manager = self.manager ?? CLLocationManager()
        if self.manager == nil {
            let delegate = LocationDelegate(owner: self)
            manager.delegate = delegate
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            self.delegate = delegate
            self.manager = manager
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .asking
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        default:
            state = .locating
            manager.requestLocation()
        }
    }

    public func pick(_ id: String?) {
        pickedTown = id
        if id != nil { state = .idle } // the reader's pick wins over an earlier fix
    }

    fileprivate func authorisationChanged(_ status: CLAuthorizationStatus) {
        guard state == .asking || state == .locating else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            state = .locating
            manager?.requestLocation()
        case .denied, .restricted:
            state = .denied
        default:
            break
        }
    }

    fileprivate func located(latitude: Double, longitude: Double) {
        guard let near = NearMe.nearest(latitude: latitude, longitude: longitude) else { return }
        state = .found(near, Date())
    }

    fileprivate func failed(_ error: Error) {
        if let error = error as? CLError, error.code == .denied {
            state = .denied
        } else if let error = error as? CLError, error.code == .locationUnknown {
            return // Core Location keeps trying; a later fix or failure follows.
        } else {
            state = .failed(error.localizedDescription)
        }
    }
}

/// Core Location's delegate, kept apart from the observable locator; hands each callback to the main actor.
final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private weak var owner: NearMeLocator?

    @MainActor init(owner: NearMeLocator) {
        self.owner = owner
        super.init()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus, owner = self.owner
        Task { @MainActor in owner?.authorisationChanged(status) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude, lon = last.coordinate.longitude, owner = self.owner
        Task { @MainActor in owner?.located(latitude: lat, longitude: lon) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError, owner = self.owner
        Task { @MainActor in owner?.failed(nsError) }
    }
}
