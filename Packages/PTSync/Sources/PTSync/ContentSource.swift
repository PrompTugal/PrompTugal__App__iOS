import Foundation

/// Read access to synced files. Other packages never import PTSync: a package that wants synced data takes a
/// closure (`(String) -> Data?`) and the app passes `store.loader` at launch.
public protocol ContentSource: Sendable {
    /// The bytes of a file by its manifest path (`api/v1/live/agenda.json`), or nil when it is not held.
    func data(at path: String) -> Data?
    /// Counts up with every switch.
    var generation: Int { get }
}

/// The files of one generation, frozen. A screen holds one so a sync that switches meanwhile never mixes old and new.
public struct ContentSnapshot: ContentSource {
    public let generation: Int
    public let version: String
    public let syncedAt: Date?
    let entries: [String: ManifestEntry]
    let objects: URL

    public func data(at path: String) -> Data? {
        guard let entry = entries[path] else { return nil }
        return try? Data(contentsOf: objects.appendingPathComponent(entry.sha256))
    }

    public var paths: [String] { entries.keys.sorted() }
}
