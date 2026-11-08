import Foundation
import PTCore

/// Where to send: a vault's append lane and the recipient's public key. Everything here is public by design
/// (sgit.ai `/.well-known/sgit-subscribe.json`): the token can only write.
struct LaneAddress: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(vault)/\(token.prefix(12))" }
    /// Shown in the app: "Newsroom tips", "Silvio".
    var name: String
    var vault: String
    var endpoint: URL
    /// The lane's append token, hex only (`^[0-9a-f]{16,128}$`).
    var token: String
    /// The recipient's RSA public key (SPKI PEM) and its published fingerprint.
    var publicKeyPEM: String
    var fingerprint: String
    /// What the recipient asks for on this lane (free text from the descriptor).
    var use: String?
    /// What the recipient's drainer accepts: nil or "eml" (one .eml), or "sgit-newsroom-inbox/v1" (a reader's
    /// newsroom inbox, from an `sgi1.` link: a device file with notes, newsroom.sgit.ai assets/vault-pane/inbox.js).
    var format: String?

    static let newsroomInboxFormat = "sgit-newsroom-inbox/v1"
    var isNewsroomInbox: Bool { format == Self.newsroomInboxFormat }

    static let defaultEndpoint = URL(string: "https://dev.send.sgraph.ai")!
    /// The only vault servers lanes may talk to (S7). dev.send.sgraph.ai is the one host with the append routes
    /// (sgit.ai /api/append-lanes, checked 26 September and 10 October 2026).
    static let allowedHosts: Set<String> = ["dev.send.sgraph.ai"]

    static func isAllowedEndpoint(_ url: URL) -> Bool {
        url.scheme == "https" && allowedHosts.contains(url.host()?.lowercased() ?? "") && url.port == nil
            && url.user == nil && url.password == nil
    }

    enum Failure: Error, Equatable, LocalizedError {
        case notJSON, missing(String), badToken, badVault, hostNotAllowed(String)
        var errorDescription: String? {
            switch self {
            case .notJSON: "That is not a lane description (JSON)."
            case .missing(let field): "The lane description has no \(field)."
            case .badToken: "The append token must be 16 to 128 lowercase hex characters."
            case .badVault: "The vault id is not valid."
            case .hostNotAllowed(let host): "Lanes can only use dev.send.sgraph.ai, not \(host.isEmpty ? "this address" : host)."
            }
        }
    }

    static func isValidToken(_ token: String) -> Bool {
        (16...128).contains(token.count) && token.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }

    static func isValidVaultId(_ id: String) -> Bool {
        (4...64).contains(id.count) && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    /// `sgi1.<vault>.<token>.<SPKI, base64url>`, alone or inside a link (`…/vault/send.html#sgi1.…`).
    static func parseInboxLink(_ text: String, name: String = "Newsroom inbox") -> LaneAddress? {
        guard let match = text.firstMatch(of: #/sgi1\.([a-z0-9]{4,24})\.([0-9a-f]{16,128})\.([A-Za-z0-9_-]{200,3000})/#) else { return nil }
        var base64 = String(match.3).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let spki = Data(base64Encoded: base64), (try? LaneCrypto.pkcs1(fromSPKI: spki)) != nil else { return nil }
        return LaneAddress(name: name, vault: String(match.1), endpoint: defaultEndpoint, token: String(match.2),
                           publicKeyPEM: LaneCrypto.pem(spki: spki), fingerprint: LaneCrypto.fingerprint(spki: spki),
                           use: "a reader's newsroom inbox: notes arrive as a device file", format: newsroomInboxFormat)
    }

    /// Reads an `sgit-subscribe/v1` file (`inbox.vault`, `inbox.endpoint`, `inbox.lane.append_token`,
    /// `recipient.encrypt`, `recipient.fingerprint`) or this app's own `promptugal-lane/v1`
    /// (`vault`, `endpoint`, `append_token`, `public_key`, `fingerprint`, `name`). Checks the fingerprint
    /// against the key, as the sgit.ai form does.
    static func parse(_ data: Data, name fallback: String = "Lane") throws -> LaneAddress {
        if let link = parseInboxLink(String(decoding: data, as: UTF8.self)) { return link }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.notJSON }
        let inbox = root["inbox"] as? [String: Any]
        let lane = inbox?["lane"] as? [String: Any]
        let recipient = root["recipient"] as? [String: Any]

        guard let vault = (inbox?["vault"] ?? root["vault"]) as? String else { throw Failure.missing("vault id") }
        guard let token = (lane?["append_token"] ?? root["append_token"]) as? String else { throw Failure.missing("append token") }
        guard let pem = (recipient?["encrypt"] ?? root["public_key"]) as? String else { throw Failure.missing("public key") }
        let endpoint = ((inbox?["endpoint"] ?? root["endpoint"]) as? String).flatMap(URL.init(string:)) ?? defaultEndpoint
        let published = (recipient?["fingerprint"] ?? inbox?["encrypt_to"] ?? root["fingerprint"]) as? String
        let name = (root["name"] as? String) ?? (recipient?["address"] as? String) ?? (lane?["name"] as? String) ?? fallback

        guard isValidToken(token) else { throw Failure.badToken }
        guard isValidVaultId(vault) else { throw Failure.badVault }
        let computed = LaneCrypto.fingerprint(spki: try LaneCrypto.der(fromPEM: pem))
        if let published, published != computed { throw LaneCrypto.Failure.fingerprintMismatch }
        guard isAllowedEndpoint(endpoint) else { throw Failure.hostNotAllowed(endpoint.host() ?? "") }
        return LaneAddress(name: name, vault: vault, endpoint: endpoint, token: token, publicKeyPEM: pem,
                           fingerprint: computed, use: lane?["use"] as? String ?? root["use"] as? String,
                           format: root["format"] as? String)
    }

    /// This app's descriptor, to hand to a sender.
    func descriptor() throws -> Data {
        var object: [String: Any] = ["schema": "promptugal-lane/v1", "name": name, "vault": vault,
                                     "endpoint": endpoint.absoluteString, "append_token": token,
                                     "public_key": publicKeyPEM, "fingerprint": fingerprint, "use": use ?? "notes from the PrompTugal app"]
        if let format { object["format"] = format }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
    }

    /// A newsroom inbox message carrying one note, as `problems()` in inbox.js accepts it.
    static func newsroomInboxMessage(note: [String: Any], to fingerprint: String, device: String,
                                     at date: Date = .now) throws -> Data {
        let file: [String: Any] = ["v": 1, "device": ["id": device, "label": "PrompTugal iOS"], "reads": [], "notes": [note]]
        let message: [String: Any] = ["kind": newsroomInboxFormat, "to": fingerprint,
                                      "sent_at": ISO8601DateFormatter.collabJS.string(from: date), "file": file]
        return try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    var writeURL: URL { endpoint.appendingPathComponent("api/vault/append/write/\(vault)") }
}

/// One message the app sends: an RFC 822-style text, as the sgit lanes' drainers read it (one single-part
/// `.eml`, UTF-8). Header values are single-line; anything else is in the body.
struct LaneMessage: Equatable, Sendable {
    var from: String
    var to: String
    var subject: String
    var kind: String
    var body: String
    var date: Date = .now
    var extraHeaders: [(String, String)] = []

    static func == (lhs: LaneMessage, rhs: LaneMessage) -> Bool {
        lhs.from == rhs.from && lhs.to == rhs.to && lhs.subject == rhs.subject && lhs.kind == rhs.kind
            && lhs.body == rhs.body && lhs.date == rhs.date
    }

    /// Strips line breaks so a field cannot add headers.
    static func header(_ value: String) -> String {
        value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    func eml() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        var lines = [
            "From: \(Self.header(from))",
            "To: \(Self.header(to))",
            "Subject: \(Self.header(subject))",
            "Date: \(formatter.string(from: date))",
            "Message-ID: <promptugal-app-\(UUID().uuidString.lowercased())@promptugal.news>",
            "X-EmailFS-Kind: \(Self.header(kind))",
            "X-SGit-Form: promptugal-app",
        ]
        for (name, value) in extraHeaders { lines.append("\(Self.header(name)): \(Self.header(value))") }
        lines.append("Content-Type: text/plain; charset=utf-8")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\r\n")
    }
}
