import CryptoKit
import Foundation

// Ported from VoiceDebrief `Engine/DeveloperLane.swift` (Apache 2.0, github.com/VoiceDebrief/VoiceDebrief__App__iOS):
// the header line + bytes message, the 2 MB parts, and the picture-with-a-line messages. Kinds here start with
// `sgit/` so that VoiceDebrief's `tools/conductor/conductor.py drain` files them under the item's id by name.

/// What goes over a lane, before sealing: each message is one line of JSON (the header), a newline, then bytes.
/// One item (a note to the conductor, a draft, a message to an agent) is several messages sharing an `item` id:
/// `meta.json` first (what it is, who it is for, the town, the text, the files), then each file in parts.
public enum TalkWire {
    /// Raw bytes per message. Sealing and encoding twice makes a payload about 1.8 times this; the lane refuses
    /// a payload over 5 MB.
    public static let partSize = 2_000_000
    /// The largest file the app sends (a video is compressed first). 40 parts.
    public static let maxFileBytes = 80_000_000
    public static let schema = "promptugal-talk/v1"

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case meta = "sgit/talk/meta/v1"
        case text = "sgit/talk/text/v1"
        case image = "sgit/talk/image/v1"
        case video = "sgit/talk/video/v1"
        case audio = "sgit/talk/audio/v1"
        case transcript = "sgit/talk/transcript/v1"
        /// A payload another package made (PTPlaces' `promptugal/comment/v1` JSON), carried as `payload.json`.
        case payload = "sgit/talk/payload/v1"
    }

    /// The first line of every message. Same field names as VoiceDebrief's header (conductor.py reads `kind`,
    /// `note`, `part`, `of`, `name`), so either receiver can file it.
    public struct Header: Codable, Equatable, Sendable {
        public var kind: String
        /// The item id: the receiver's folder for every message of this item.
        public var note: String
        public var part: Int
        public var of: Int
        public var name: String
        /// The whole file's size and SHA-256 (hex), so the receiver can check the joined parts.
        public var size: Int
        public var sha256: String
        public var app: String
        public var sentAt: String
        /// The signer: `sha256:` and 16 hex of SHA-256 over its P-256 public key (SPKI DER), the sgit fingerprint form.
        public var by: String? = nil
        /// The signer's P-256 public key, SPKI DER, base64.
        public var key: String? = nil
        /// ECDSA P-256 over SHA-256 of `signedText(body:)`, raw r||s (64 bytes, IEEE P1363), base64.
        public var sig: String? = nil

        /// What is signed: kind, note, part, of, name, size, sha256, sentAt and the SHA-256 (hex) of this message's
        /// own bytes, joined by "\n". Binds the header to its body, so no part can be moved to another item.
        public func signedText(body: Data) -> Data {
            Data([kind, note, String(part), String(of), name, String(size), sha256, sentAt, TalkWire.sha256Hex(body)]
                .joined(separator: "\n").utf8)
        }

        public var isSigned: Bool { by != nil && key != nil && sig != nil }
    }

    /// Signs every message of an item with a P-256 key (the person key, from PTPlaces' sign-in).
    public struct Signer: Sendable {
        public let key: P256.Signing.PrivateKey
        public init(key: P256.Signing.PrivateKey) { self.key = key }
        public var publicKeyBase64: String { key.publicKey.derRepresentation.base64EncodedString() }
        public var fingerprint: String { TalkWire.fingerprint(of: key.publicKey) }

        func sign(_ header: inout Header, body: Data) throws {
            header.by = fingerprint
            header.key = publicKeyBase64
            header.sig = try key.signature(for: header.signedText(body: body)).rawRepresentation.base64EncodedString()
        }
    }

    public static func fingerprint(of key: P256.Signing.PublicKey) -> String {
        "sha256:" + sha256Hex(key.derRepresentation).prefix(16)
    }

    public enum Verdict: Equatable, Sendable {
        /// Signed, and the signature holds for this header and body; the receiver still checks `by` is registered.
        case signed(by: String)
        case unsigned
        case invalid
    }

    /// The receiving side's check of one message.
    public static func verify(header: Header, body: Data) -> Verdict {
        guard header.by != nil || header.key != nil || header.sig != nil else { return .unsigned }
        guard let by = header.by, let keyB64 = header.key, let sigB64 = header.sig,
              let keyData = Data(base64Encoded: keyB64), let sigData = Data(base64Encoded: sigB64),
              let key = try? P256.Signing.PublicKey(derRepresentation: keyData),
              fingerprint(of: key) == by,
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: sigData),
              key.isValidSignature(signature, for: header.signedText(body: body)) else { return .invalid }
        return .signed(by: by)
    }

    /// Why an item is sent, which decides the receiver's handling.
    public enum Purpose: String, Codable, Sendable {
        /// A comment for the conductor, usually with a screenshot of what it is about.
        case conductor
        /// A contribution: becomes a draft for a town, which a person approves before it is published.
        case draft
        /// A message to a town's agent.
        case agent
        /// A comment, thumbs or other payload from PTPlaces, sent through `TalkTransport`.
        case comment
    }

    /// One file of an item.
    public struct Attachment: Equatable, Sendable {
        public var kind: Kind
        public var name: String
        public var data: Data
        public init(kind: Kind, name: String, data: Data) {
            self.kind = kind
            self.name = TalkWire.safeName(name)
            self.data = data
        }
    }

    /// `meta.json`: everything a receiver needs to act on the item without opening the files.
    public struct Meta: Codable, Equatable, Sendable {
        public struct File: Codable, Equatable, Sendable {
            public var name: String
            public var kind: String
            public var size: Int
            public var sha256: String
            public var parts: Int
        }
        public var schema: String
        public var item: String
        public var purpose: Purpose
        /// "conductor", or an agent's address (`place.loule@PrompTugal.dinis`).
        public var to: String
        public var town: String?
        public var townName: String?
        public var title: String?
        public var text: String
        public var files: [File]
        /// Where the transcript came from, when there is one ("on-device speech recognition").
        public var transcriptSource: String?
        /// For a draft: a person approves it before anything is published.
        public var needsApproval: Bool
        public var app: String
        public var sentAt: String
        /// The signer's fingerprint, when the item is signed (each message carries the signature itself).
        public var by: String? = nil
    }

    // MARK: Building

    /// A file's bytes cut into pieces of at most `size`. An empty file has no pieces.
    public static func parts(of data: Data, size: Int = partSize) -> [Data] {
        guard size > 0 else { return [] }
        var out: [Data] = []
        var start = data.startIndex
        while start < data.endIndex {
            let end = data.index(start, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
            out.append(data.subdata(in: start..<end))
            start = end
        }
        return out
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// One message before sealing: the header as one line of JSON (sorted keys), a newline, then the bytes.
    public static func message(header: Header, body: Data) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var out = try encoder.encode(header)
        out.append(0x0A)
        out.append(body)
        return out
    }

    /// The header and bytes of one message (the receiver's side; JSON never holds a raw newline).
    public static func split(_ message: Data) throws -> (header: Header, body: Data) {
        guard let newline = message.firstIndex(of: 0x0A) else { throw Failure.noHeader }
        let header = try JSONDecoder().decode(Header.self, from: message.subdata(in: message.startIndex..<newline))
        return (header, message.subdata(in: message.index(after: newline)..<message.endIndex))
    }

    public enum Failure: Error, Equatable, LocalizedError {
        case noHeader, empty, tooLarge(String, Int)
        public var errorDescription: String? {
            switch self {
            case .noHeader: "That message has no header line."
            case .empty: "There is nothing to send: write a line or add a picture."
            case .tooLarge(let name, let bytes):
                "\(name) is too large to send (\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)); \(ByteCountFormatter.string(fromByteCount: Int64(TalkWire.maxFileBytes), countStyle: .file)) at most)."
            }
        }
    }

    /// Every message of one item: `meta.json`, then the text (if any) as `message.txt`, then each file in parts.
    public static func messages(item: String, purpose: Purpose, to: String, town: String? = nil, townName: String? = nil,
                                title: String? = nil, text: String, attachments: [Attachment] = [],
                                transcriptSource: String? = nil, app: String, at date: Date = .now,
                                partSize: Int = partSize, signer: Signer? = nil) throws -> [Data] {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let files = attachments.filter { !$0.data.isEmpty }
        guard !line.isEmpty || !files.isEmpty else { throw Failure.empty }
        if let big = files.first(where: { $0.data.count > maxFileBytes }) { throw Failure.tooLarge(big.name, big.data.count) }

        let sentAt = ISO8601DateFormatter().string(from: date)
        var all = files
        if !line.isEmpty { all.insert(Attachment(kind: .text, name: "message.txt", data: Data(line.utf8)), at: 0) }

        let meta = Meta(schema: schema, item: item, purpose: purpose, to: to, town: town, townName: townName, title: title,
                        text: line,
                        files: all.map { .init(name: $0.name, kind: $0.kind.rawValue, size: $0.data.count, sha256: sha256Hex($0.data),
                                               parts: max(1, parts(of: $0.data, size: partSize).count)) },
                        transcriptSource: transcriptSource, needsApproval: purpose == .draft, app: app, sentAt: sentAt,
                        by: signer?.fingerprint)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let metaJSON = try encoder.encode(meta)

        func signed(_ header: Header, _ body: Data) throws -> Data {
            var header = header
            try signer?.sign(&header, body: body)
            return try message(header: header, body: body)
        }
        var out = [try signed(Header(kind: Kind.meta.rawValue, note: item, part: 1, of: 1, name: "meta.json",
                                     size: metaJSON.count, sha256: sha256Hex(metaJSON), app: app, sentAt: sentAt), metaJSON)]
        for file in all {
            let pieces = parts(of: file.data, size: partSize)
            let digest = sha256Hex(file.data)
            for (index, piece) in pieces.enumerated() {
                out.append(try signed(Header(kind: file.kind.rawValue, note: item, part: index + 1, of: pieces.count,
                                             name: file.name, size: file.data.count, sha256: digest, app: app, sentAt: sentAt), piece))
            }
        }
        return out
    }

    // MARK: Receiving (tests, and any Swift receiver)

    /// Joins the messages of one item back into files by name, checking each file's parts and SHA-256.
    public static func reassemble(_ messages: [Data]) throws -> (meta: Meta?, files: [String: Data]) {
        var pieces: [String: [Int: Data]] = [:]
        var headers: [String: Header] = [:]
        var meta: Meta?
        for message in messages {
            let (header, body) = try split(message)
            if header.kind == Kind.meta.rawValue { meta = try JSONDecoder().decode(Meta.self, from: body) }
            pieces[header.name, default: [:]][header.part] = body
            headers[header.name] = header
        }
        var files: [String: Data] = [:]
        for (name, parts) in pieces {
            guard let header = headers[name], parts.count == header.of else { continue }
            let whole = parts.keys.sorted().reduce(into: Data()) { $0.append(parts[$1]!) }
            if whole.count == header.size && sha256Hex(whole) == header.sha256 { files[name] = whole }
        }
        return (meta, files)
    }

    // MARK: Names

    /// An item id: `<purpose>-<town or conductor>-<UTC yyyyMMdd-HHmmss>-<4 hex>`. Safe as a folder name.
    public static func itemId(purpose: Purpose, town: String?, at date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = String(UUID().uuidString.lowercased().prefix(4))
        return safeName("\(purpose.rawValue)-\(town ?? "conductor")-\(formatter.string(from: date))-\(suffix)")
    }

    /// Letters, digits, `.`, `-`, `_` only, never starting with a dot; at most 80 characters.
    public static func safeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        var scalars = String.UnicodeScalarView()
        for scalar in name.unicodeScalars {
            scalars.append(scalar.isASCII && allowed.contains(scalar) ? scalar : ("-" as Unicode.Scalar))
        }
        var out = String(scalars)
        while out.hasPrefix(".") { out.removeFirst() }
        if out.isEmpty { out = "file" }
        return String(out.prefix(80))
    }
}
