import Foundation
import Security
import PTCore

/// The append-lane API (sgit.ai `/api/append-lanes`), through the shared `HTTPClient` so each call shows in
/// Debug → Network. `HTTPClient` keeps no bodies or headers, so the append token (in the body) and the enum key
/// (in a header) are not logged there; `LanesLog` shows a shortened token.
struct LaneClient: Sendable {
    let http: HTTPClient

    init(http: HTTPClient = .shared) { self.http = http }

    enum Failure: Error, Equatable, LocalizedError {
        case refused(Int, String)
        var errorDescription: String? {
            switch self {
            case .refused(404, _): "The lane refused it (404): the vault id or token is wrong, or the lane is not set up."
            case .refused(413, _): "Too large for the lane (413, 5 MB at most)."
            case .refused(507, _): "The lane is full (507, 1,000 waiting messages)."
            case .refused(let status, let detail): "The lane answered \(status)\(detail.isEmpty ? "" : ": \(detail)")."
            }
        }
    }

    // MARK: Sending (account-less)

    static func writeRequest(to address: LaneAddress, payload: String) throws -> URLRequest {
        guard LaneAddress.isAllowedEndpoint(address.endpoint) else {
            throw LaneAddress.Failure.hostNotAllowed(address.endpoint.host() ?? "")
        }
        var request = URLRequest(url: address.writeURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["append_token": address.token, "payload": payload],
                                                      options: [.sortedKeys])
        return request
    }

    /// Encrypts `message` to the lane's recipient and appends it. The answer is blind: `{"ok": true}`.
    @MainActor
    func send(_ message: LaneMessage, to address: LaneAddress, log: LanesLog = .shared) async throws {
        try await send(Data(message.eml().utf8), subject: message.subject, to: address, log: log)
    }

    /// Encrypts `text` to the lane's recipient and appends it.
    @MainActor
    func send(_ text: Data, subject: String, to address: LaneAddress, log: LanesLog = .shared) async throws {
        let lane = LanesLog.describe(address)
        let started = ContinuousClock.now
        let encText: String
        do {
            let key = try LaneCrypto.publicKey(pem: address.publicKeyPEM)
            encText = try LaneCrypto.encrypt(text, to: key)
        } catch {
            log.add(.error, lane: lane, detail: "encrypt: \(CollabErrorText.short(error))")
            throw error
        }
        log.add(.encrypt, lane: lane, bytes: encText.utf8.count, ms: Self.ms(since: started),
                detail: "RSA-OAEP-SHA256 to \(address.fingerprint) + AES-256-GCM, \(text.count) B → \(encText.utf8.count) B .enc; subject \"\(LaneMessage.header(subject).prefix(60))\"")
        let request = try Self.writeRequest(to: address, payload: LaneCrypto.lanePayload(encText: encText))
        let sent = ContinuousClock.now
        do {
            let (data, response) = try await http.data(for: request, label: "lanes.write")
            guard (200..<300).contains(response.statusCode) else {
                let detail = String(decoding: data.prefix(200), as: UTF8.self).contains("<html") ? "" : String(decoding: data.prefix(200), as: UTF8.self)
                log.add(.error, lane: lane, bytes: request.httpBody?.count ?? 0, ms: Self.ms(since: sent),
                        status: response.statusCode, detail: "write refused")
                throw Failure.refused(response.statusCode, detail)
            }
            log.add(.write, lane: lane, bytes: request.httpBody?.count ?? 0, ms: Self.ms(since: sent),
                    status: response.statusCode, detail: "POST \(address.endpoint.host() ?? "")/api/vault/append/write/\(address.vault) → \(String(decoding: data.prefix(40), as: UTF8.self))")
        } catch let error as Failure {
            throw error
        } catch {
            log.add(.error, lane: lane, ms: Self.ms(since: sent), detail: "write: \(CollabErrorText.short(error))")
            throw error
        }
    }

    // MARK: Reading my inbox (enum key)

    struct Entry: Decodable, Identifiable, Hashable, Sendable {
        var id: String { fileId }
        let fileId: String
        let inbox: String?
        let size: Int?
        let content: String?
        enum CodingKeys: String, CodingKey {
            case fileId = "file_id", inbox, size, content
            case altId = "id", name
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            fileId = try c.decodeIfPresent(String.self, forKey: .fileId) ?? c.decodeIfPresent(String.self, forKey: .altId)
                ?? c.decode(String.self, forKey: .name)
            inbox = try c.decodeIfPresent(String.self, forKey: .inbox)
            size = try c.decodeIfPresent(Int.self, forKey: .size)
            content = try c.decodeIfPresent(String.self, forKey: .content)
        }
        /// Server file ids are `{epoch_ms:013d}_{24 hex}.enc`.
        var sentAt: Date? {
            Double(fileId.prefix(13)).map { Date(timeIntervalSince1970: $0 / 1_000) }
        }
    }

    /// Entries from a `list` response, whichever key the server puts them under.
    static func entries(fromList data: Data) throws -> [Entry] {
        struct Page: Decodable {
            let entries: [Entry]?
            let files: [Entry]?
            let items: [Entry]?
        }
        let page = try JSONDecoder().decode(Page.self, from: data)
        return (page.entries ?? page.files ?? page.items ?? []).sorted { $0.fileId < $1.fileId }
    }

    private func post(_ path: String, address: LaneAddress, enumKey: String, body: [String: Any], label: String) async throws -> Data {
        guard LaneAddress.isAllowedEndpoint(address.endpoint) else {
            throw LaneAddress.Failure.hostNotAllowed(address.endpoint.host() ?? "")
        }
        var request = URLRequest(url: address.endpoint.appendingPathComponent("api/vault/append/\(path)/\(address.vault)"), timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(enumKey, forHTTPHeaderField: "x-sgraph-vault-enum-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (data, response) = try await http.data(for: request, label: label)
        guard (200..<300).contains(response.statusCode) else { throw Failure.refused(response.statusCode, "") }
        return data
    }

    /// Every pending file of this lane (the token's), metadata only, following `truncated` pages.
    func list(_ address: LaneAddress, enumKey: String) async throws -> [Entry] {
        var out: [Entry] = []
        var after: String?
        for _ in 0..<50 {
            var body: [String: Any] = ["include_content": false]
            if let after { body["after_file_id"] = after }
            let data = try await post("list", address: address, enumKey: enumKey, body: body, label: "lanes.list")
            let entries = try Self.entries(fromList: data)
            out += entries
            let truncated = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["truncated"] as? Bool ?? false
            guard truncated, let last = entries.last?.fileId else { break }
            after = last
        }
        return out.filter { $0.inbox == nil || $0.inbox == address.token }
    }

    /// The stored content of each file (base64 of the `.enc` text), by file id.
    func fetch(_ address: LaneAddress, enumKey: String, fileIds: [String]) async throws -> [String: String] {
        let data = try await post("fetch", address: address, enumKey: enumKey,
                                  body: ["inbox": address.token, "file_ids": fileIds], label: "lanes.fetch")
        return Self.contents(fromFetch: data)
    }

    static func contents(fromFetch data: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        let files = object["files"] ?? object["entries"]
        if let list = files as? [[String: Any]] {
            for file in list {
                if let id = (file["file_id"] ?? file["id"]) as? String, let content = file["content"] as? String { out[id] = content }
            }
        } else if let map = files as? [String: String] {
            out = map
        }
        return out
    }

    func markProcessed(_ address: LaneAddress, enumKey: String, fileIds: [String]) async throws {
        _ = try await post("mark-processed", address: address, enumKey: enumKey,
                           body: ["inbox": address.token, "file_ids": fileIds], label: "lanes.markProcessed")
    }

    static func ms(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }
}

/// This device's lane identity: an RSA-4096 key pair made in the Keychain (this device only). Its public half
/// goes into the descriptor I hand to senders; the private half decrypts my inbox and never leaves the device.
public enum LaneIdentity {
    static let tag = Data("news.promptugal.reader.lanes.identity".utf8)

    static func privateKey() -> SecKey? {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: tag,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                    kSecReturnRef as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item else { return nil }
        return (item as! SecKey)
    }

    public static var exists: Bool { privateKey() != nil }

    @discardableResult
    static func create() throws -> SecKey {
        if let key = privateKey() { return key }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 4096,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: true,
                                            kSecAttrApplicationTag as String: tag,
                                            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly],
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw LaneCrypto.Failure.keyImport(error.map { CFErrorCopyDescription($0.takeRetainedValue()) as String } ?? "keygen")
        }
        return key
    }

    static func delete() {
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: tag] as CFDictionary)
    }

    /// SPKI PEM of my public key, and its sgit fingerprint.
    static func publicPEM(of privateKey: SecKey) throws -> (pem: String, fingerprint: String) {
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let pkcs1 = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw LaneCrypto.Failure.keyImport("public key")
        }
        let spki = LaneCrypto.spki(fromPKCS1: pkcs1)
        return (LaneCrypto.pem(spki: spki), LaneCrypto.fingerprint(spki: spki))
    }

    /// A random append token (64 hex), for a sender I hand my descriptor to.
    static func newToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
