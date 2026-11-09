import CryptoKit
import Foundation
import Security

/// The published keys that messaging reads (WS-203), from web-summit.sgit.ai:
/// data/keys.json (agents: RSA to read, P-256 to sign), data/person-keys.json (people: P-256 JWK),
/// data/messaging/device-keys.json (devices: P-256 JWK) and data/messaging/groups.json.
/// Public halves only. An entry that does not parse is skipped, never trusted.
public struct MessageDirectory: @unchecked Sendable {
    struct Entry {
        var name: String            // person id or agent name
        var device: String?
        var fingerprint: String
        var signingFingerprint: String
        var read: MessageReader.Key
        var sign: P256.Signing.PublicKey
    }
    var entries: [Entry] = []
    public var groups: [String: [String]] = [:]

    public static let base = URL(string: "https://web-summit.sgit.ai/")!
    static let paths = (agents: "data/keys.json", people: "data/person-keys.json",
                        devices: "data/messaging/device-keys.json", groups: "data/messaging/groups.json")

    public init(agents: Data?, people: Data?, devices: Data?, groups: Data? = nil) {
        if let agents, let file = try? JSONDecoder().decode(AgentFile.self, from: agents) {
            for k in file.keys where Self.active(k.status) {
                guard let b = k.bundle, let encPEM = b.encrypt, let signPEM = b.sign,
                      let fp = b.fingerprint, let sfp = b.signing_fingerprint,
                      let enc = try? LaneCrypto.publicKey(pem: encPEM),
                      let sig = try? P256.Signing.PublicKey(pemRepresentation: signPEM) else { continue }
                let name = k.agent ?? (b.label ?? k.label ?? "").split(separator: " ").first.map(String.init) ?? ""
                guard !name.isEmpty else { continue }
                entries.append(Entry(name: name, fingerprint: fp, signingFingerprint: sfp, read: .rsa(enc), sign: sig))
            }
        }
        for data in [people, devices].compactMap({ $0 }) {
            guard let file = try? JSONDecoder().decode(PersonFile.self, from: data) else { continue }
            for k in file.keys where Self.active(k.status) {
                guard let encX = k.encrypt?.x963, let sigX = k.sign?.x963,
                      let enc = try? P256.KeyAgreement.PublicKey(x963Representation: encX),
                      let sig = try? P256.Signing.PublicKey(x963Representation: sigX),
                      let fp = k.fingerprint, let sfp = k.signing_fingerprint else { continue }
                entries.append(Entry(name: k.person, device: k.device, fingerprint: fp, signingFingerprint: sfp, read: .p256(enc), sign: sig))
            }
        }
        if let groups, let g = try? JSONDecoder().decode(GroupFile.self, from: groups) { self.groups = g.groups }
    }

    static func active(_ status: String?) -> Bool { status == nil || status!.hasPrefix("active") }

    /// Every key that reads for a person (site key and devices) or an agent.
    public func readers(of name: String) -> [MessageReader] {
        entries.filter { $0.name == name }.map { MessageReader(to: name, fingerprint: $0.fingerprint, key: $0.read) }
    }

    /// Who a signing fingerprint speaks for. A device's key speaks for its person.
    public func signer(_ fingerprint: String) -> MessageSigner? {
        entries.first { $0.signingFingerprint == fingerprint }.map { MessageSigner(name: $0.name, key: $0.sign) }
    }

    /// People and agents with at least one key, for "new chat".
    public var names: [String] { Array(Set(entries.map(\.name))).sorted() }
    public func isAgent(_ name: String) -> Bool { name.contains("@") }

    /// Fetches the four files. A missing device or group file is fine (empty).
    public static func fetch(base: URL = MessageDirectory.base) async throws -> MessageDirectory {
        async let a = get(base.appendingPathComponent(paths.agents))
        async let p = get(base.appendingPathComponent(paths.people))
        async let d = get(base.appendingPathComponent(paths.devices))
        async let g = get(base.appendingPathComponent(paths.groups))
        let (agents, people, devices, groups) = try await (a, p, d, g)
        guard agents != nil || people != nil else { throw URLError(.cannotLoadFromNetwork) }
        return MessageDirectory(agents: agents, people: people, devices: devices, groups: groups)
    }

    private static func get(_ url: URL) async throws -> Data? {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadRevalidatingCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        return (resp as? HTTPURLResponse)?.statusCode == 200 ? data : nil
    }

    // The files' shapes (only what messaging reads).
    struct AgentFile: Decodable {
        struct Key: Decodable {
            var agent: String?
            var label: String?
            var status: String?
            var bundle: Bundle?
        }
        struct Bundle: Decodable {
            var encrypt: String?
            var sign: String?
            var label: String?
            var fingerprint: String?
            var signing_fingerprint: String?
        }
        var keys: [Key]
    }
    struct PersonFile: Decodable {
        struct Key: Decodable {
            var person: String
            var device: String?
            var status: String?
            var fingerprint: String?
            var signing_fingerprint: String?
            var encrypt: JWK?
            var sign: JWK?
        }
        var keys: [Key]
    }
    struct GroupFile: Decodable { var groups: [String: [String]] }
}
