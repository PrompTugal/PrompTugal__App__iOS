import Foundation

// The seam between synced files and the screens that read them (contracts §8). PTSync implements `ContentSource`;
// PTNews, PTDeck, PTAgenda and the apps read through it and never import PTSync. The app registers its sources once at launch.

/// Read access to a site's synced files, by their manifest path.
public protocol ContentSource: Sendable {
    /// The bytes of a file by its manifest path (`api/v1/live/agenda.json`), or nil when it is not held on this device.
    func data(at path: String) -> Data?
    /// Counts up with every switch to a new set of files, so a reader can tell when to reload.
    var generation: Int { get }
}

/// The sources the app registered, by site id (`"promptugal.news"`).
public enum ContentSources {
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var sources: [String: any ContentSource] = [:]

        func set(_ source: (any ContentSource)?, for id: String) {
            lock.lock()
            defer { lock.unlock() }
            sources[id] = source
        }

        func get(_ id: String) -> (any ContentSource)? {
            lock.lock()
            defer { lock.unlock() }
            return sources[id]
        }
    }

    private static let registry = Registry()

    /// Registers (or replaces) the source for a site. Called by the app at launch.
    public static func register(_ source: any ContentSource, for id: String) { registry.set(source, for: id) }

    public static func unregister(_ id: String) { registry.set(nil, for: id) }

    /// The source for a site, or nil when the app has not registered one (a reader then uses the network, as before).
    public static func source(for id: String) -> (any ContentSource)? { registry.get(id) }
}
