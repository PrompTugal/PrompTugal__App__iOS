import Foundation

/// Every way a vault read can fail. Messages never contain key material.
public enum VaultError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The pasted text is not a key sgit recognises.
    case invalidKey(String)
    /// Neither the branch index nor the default ref exists under ids derived from this key:
    /// the key is wrong, or the vault id is wrong, or the vault was never pushed.
    case vaultNotFoundOrWrongKey(vaultId: String)
    /// A file the server should hold is missing (HTTP 404, or no file in a local folder).
    case notFound(path: String)
    /// The server answered with an unexpected HTTP status.
    case http(status: Int, path: String)
    /// AES-GCM refused the object with both the read key and the structure key.
    case decryptFailed(path: String)
    /// The ciphertext does not hash to its `obj-cas-imm-` id. The object was changed.
    case integrity(objectId: String, actual: String)
    /// A decrypted blob does not match the size or content hash its tree entry records.
    case contentMismatch(path: String, detail: String)
    /// The vault uses a feature this reader does not implement (for example `packs`).
    case unsupportedFormat(String)
    /// Decrypted JSON did not have the expected shape.
    case malformed(path: String, detail: String)
    /// No named branch with that name in the branch index.
    case branchNotFound(String)
    /// No file at that path in the head tree.
    case fileNotFound(String)
    /// The deflate envelope or the zlib stream inside it is damaged.
    case inflateFailed(path: String)
    /// A commit signature did not verify and the vault requires signatures.
    case signatureInvalid(commitId: String)

    public var description: String {
        switch self {
        case .invalidKey(let why): "Not a vault key: \(why)"
        case .vaultNotFoundOrWrongKey(let id): "Vault \(id) not found with this key (wrong key, wrong vault id, or never pushed)"
        case .notFound(let path): "Not found: \(path)"
        case .http(let status, let path): "HTTP \(status) for \(path)"
        case .decryptFailed(let path): "Could not decrypt \(path) (wrong key or damaged object)"
        case .integrity(let id, let actual): "Object \(id) failed its hash check (ciphertext hashes to \(actual))"
        case .contentMismatch(let path, let detail): "\(path) does not match its tree entry: \(detail)"
        case .unsupportedFormat(let why): "Unsupported vault format: \(why)"
        case .malformed(let path, let detail): "Malformed \(path): \(detail)"
        case .branchNotFound(let name): "No branch named \(name)"
        case .fileNotFound(let path): "No file \(path) in this commit"
        case .inflateFailed(let path): "Could not inflate \(path)"
        case .signatureInvalid(let id): "Commit \(id) has an invalid signature"
        }
    }
}
