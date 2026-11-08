import CryptoKit
import Foundation

public enum SHA256Hex {
    public static func of(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    /// Streams the file, so a large file is never held in memory.
    public static func of(fileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let chunk = try handle.read(upToCount: 262_144), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hex(hasher.finalize())
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
