import Foundation
import Observation
import PTCore
import SwiftUI

// The offline edition (c.ios.local's EditionFiles, verified files saved on the device) as a fallback for the places
// screens, without PTPlaces importing PTLocal. The shell sets it once, high in the tree:
//
//   PublicShell().placesOfflineData { path in EditionFiles.standard().load(path) }
//
// `path` is the site path of a JSON file: "api/v1/since.json", "api/v1/by-place/index.json",
// "api/v1/by-place/<id>.json", "api/v1/articles/<id>.json". A screen uses it only when it has nothing from the
// network or the feed's own saved copy, and then says "This device's offline copy".

private struct PlacesOfflineDataKey: EnvironmentKey {
    static let defaultValue: (@Sendable (String) -> Data?)? = nil
}

extension EnvironmentValues {
    /// Reads a saved file of the offline edition by its site path, or nil.
    public var placesOfflineData: (@Sendable (String) -> Data?)? {
        get { self[PlacesOfflineDataKey.self] }
        set { self[PlacesOfflineDataKey.self] = newValue }
    }
}

extension View {
    /// The offline edition's saved files, for the places screens to fall back to when the network fails.
    public func placesOfflineData(_ read: (@Sendable (String) -> Data?)?) -> some View {
        environment(\.placesOfflineData, read)
    }
}

@MainActor @Observable
final class PlacesOffline {
    static let shared = PlacesOffline()

    /// Set by the screens from the environment; observed, so screens refresh when it arrives.
    private(set) var reader: (@Sendable (String) -> Data?)?
    @ObservationIgnored private var decoded: [String: Any] = [:]

    func use(_ reader: (@Sendable (String) -> Data?)?) {
        guard let reader, self.reader == nil else { return }
        self.reader = reader
        // The edition beats the built-in copy: forget what was read from the app's own copy.
        for (path, source) in sources where source == .builtIn {
            decoded[path] = nil
            sources[path] = nil
        }
    }

    enum Source: Equatable { case edition, builtIn }
    @ObservationIgnored private var sources: [String: Source] = [:]

    /// The built-in copy shipped with the app (read when the release was made), for a first launch with no signal:
    /// since.json and the places index only.
    static let builtIn: [String: String] = [
        Path.since: "snapshot-since",
        Path.index: "snapshot-index",
    ]

    /// The saved file at a site path, decoded once: the offline edition first, else the copy built into the app.
    func value<T: Decodable>(_ type: T.Type, _ path: String) -> T? {
        if let value = decoded[path] as? T { return value }
        if let reader, let data = reader(path), let value = try? JSONDecoder().decode(T.self, from: data) {
            decoded[path] = value
            sources[path] = .edition
            return value
        }
        if let name = Self.builtIn[path], let url = Bundle.module.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(T.self, from: data) {
            decoded[path] = value
            sources[path] = .builtIn
            return value
        }
        return nil
    }

    /// Where a fallback value came from, once read.
    func source(_ path: String) -> Source? { sources[path] }

    /// The origin line for a fallback value: the offline edition or the built-in copy.
    func origin(_ path: String, dataDate: String?) -> PlacesOrigin {
        guard source(path) == .builtIn else { return Self.origin(dataDate: dataDate) }
        guard let dataDate, !dataDate.isEmpty else {
            return PlacesOrigin(kind: .snapshot, text: String(localized: "Built-in copy, not live", bundle: .module))
        }
        return PlacesOrigin(kind: .snapshot,
                            text: String(localized: "Built-in copy, newest \(PlaceDates.short(dataDate))", bundle: .module))
    }

    enum Path {
        static let since = "api/v1/since.json"
        static let index = "api/v1/by-place/index.json"
        static func place(_ id: String) -> String { "api/v1/by-place/\(id).json" }
        static func article(_ id: String) -> String { "api/v1/articles/\(id).json" }
    }

    /// The origin line for data read from the offline edition, with the date the data carries.
    static func origin(dataDate: String?) -> PlacesOrigin {
        guard let dataDate, !dataDate.isEmpty else {
            return PlacesOrigin(kind: .deviceCopy, text: String(localized: "This device's offline copy", bundle: .module))
        }
        return PlacesOrigin(kind: .deviceCopy,
                            text: String(localized: "This device's offline copy, newest \(PlaceDates.short(dataDate))", bundle: .module))
    }
}

extension PlacesStore {
    /// since.json from the network or the feed's saved copy, else from the offline edition.
    var sinceFeed: SinceFeed? {
        since.value ?? PlacesOffline.shared.value(SinceFeed.self, PlacesOffline.Path.since)
    }

    /// Where since.json came from, with the newest story's date.
    func sinceOrigin(dataDate: String?) -> PlacesOrigin {
        if since.value == nil, sinceFeed != nil { return PlacesOffline.shared.origin(PlacesOffline.Path.since, dataDate: dataDate) }
        return since.origin(dataDate: dataDate, story: true)
    }

    /// Where the places index came from, for the lines under the map and the capitals.
    func indexOrigin(dataDate: String?, story: Bool = false) -> PlacesOrigin {
        if index.value == nil, list.value == nil, PlacesOffline.shared.value(PlaceIndex.self, PlacesOffline.Path.index) != nil {
            return PlacesOffline.shared.origin(PlacesOffline.Path.index, dataDate: dataDate)
        }
        return index.origin(dataDate: dataDate, story: story)
    }

    /// True when a place's file comes from the offline edition.
    func placeIsOffline(_ id: String) -> Bool {
        files[id]?.value == nil && PlacesOffline.shared.value(PlaceFile.self, PlacesOffline.Path.place(id)) != nil
    }
}
