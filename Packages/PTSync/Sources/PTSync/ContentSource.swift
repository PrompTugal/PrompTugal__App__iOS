import Foundation
import PTCore

/// The files of one generation, frozen. A screen holds one so a sync that switches meanwhile never mixes old and new.
/// It conforms to PTCore's `ContentSource`, the seam other packages read through.
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
