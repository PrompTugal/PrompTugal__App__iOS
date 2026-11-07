import CryptoKit
import Foundation
import Observation

// Skeleton of the API in contracts §5, so the app can depend on the package
// before the reader exists. The vault session replaces this file.

public struct VaultAddress: Sendable, Hashable {
    public let vaultId: String
    public let server: URL

    public static let defaultServer = URL(string: "https://dev.send.sgraph.ai")!

    public init(vaultId: String, server: URL = VaultAddress.defaultServer) {
        self.vaultId = vaultId
        self.server = server
    }
}

public struct VaultCommit: Sendable, Hashable, Identifiable {
    public let id: String
    public let message: String
    public let parents: [String]
    public let date: Date?

    public init(id: String, message: String, parents: [String] = [], date: Date? = nil) {
        self.id = id
        self.message = message
        self.parents = parents
        self.date = date
    }
}

public struct VaultFile: Sendable, Hashable, Identifiable {
    public let path: String
    public let size: Int
    public let blobId: String
    public var id: String { path }

    public init(path: String, size: Int, blobId: String) {
        self.path = path
        self.size = size
        self.blobId = blobId
    }
}

public enum VaultError: Error, Sendable, Equatable {
    case notImplemented
}

public actor SGitVault {
    public let address: VaultAddress
    private let readKey: SymmetricKey
    private let cache: URL
    private let log: VaultTrafficLog

    public init(address: VaultAddress, readKey: SymmetricKey, cache: URL, log: VaultTrafficLog) {
        self.address = address
        self.readKey = readKey
        self.cache = cache
        self.log = log
    }

    /// Fetch the ref and walk new objects only.
    public func pull() async throws -> VaultCommit { throw VaultError.notImplemented }
    /// Path, size and blob id of every file at the head commit.
    public func files() async throws -> [VaultFile] { throw VaultError.notImplemented }
    public func read(_ path: String) async throws -> Data { throw VaultError.notImplemented }
    public func history(limit: Int) async throws -> [VaultCommit] { throw VaultError.notImplemented }
}

/// Feeds the Vault traffic debug panel. Newest first, capped at 2,000. Never holds a key.
@MainActor @Observable
public final class VaultTrafficLog {
    public static let capacity = 2_000
    public private(set) var events: [VaultTrafficEvent] = []

    public nonisolated init() {}

    public func append(_ event: VaultTrafficEvent) {
        events.insert(event, at: 0)
        if events.count > Self.capacity { events.removeLast(events.count - Self.capacity) }
    }

    public func clear() { events.removeAll() }
}

public struct VaultTrafficEvent: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case request, cacheHit, decrypt, verify, keyDerivation, error
    }

    public let id: UUID
    public let at: Date
    public let kind: Kind
    /// e.g. "bare/refs/ref-pid-muw-…". Never a key.
    public let path: String
    public let bytes: Int
    public let durationMs: Double
    public let status: Int?
    /// e.g. "AES-256-GCM, read key, 547 B → 512 B".
    public let detail: String

    public init(id: UUID = UUID(), at: Date = .now, kind: Kind, path: String, bytes: Int = 0,
                durationMs: Double = 0, status: Int? = nil, detail: String = "") {
        self.id = id
        self.at = at
        self.kind = kind
        self.path = path
        self.bytes = bytes
        self.durationMs = durationMs
        self.status = status
        self.detail = detail
    }
}
