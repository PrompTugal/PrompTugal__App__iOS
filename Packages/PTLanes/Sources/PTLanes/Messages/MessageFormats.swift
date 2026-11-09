import Foundation

// Team messaging v1 (WS-203): the formats, byte for byte as the team site's reference
// (SGit-AI__Website__Web-Summit: people/indi/messaging/FORMATS.md, admin/tools/messages.mjs).

/// Messaging-FS/1: one chat message.
public struct ChatMessage: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let formatID = "messaging-fs/1"
    public static let kinds: Set<String> = ["text", "image", "audio", "markdown", "link", "location", "miniapp"]

    public var format: String = ChatMessage.formatID
    public var id: String
    public var thread: String
    public var from: String
    public var to: [String]
    public var at: String
    public var kind: String
    public var text: String
    public var attachments: [Attachment]
    public var reply_to: String?

    public struct Attachment: Codable, Equatable, Hashable, Sendable {
        public var path: String
        public var sha256: String
        public var type: String
        public var bytes: Int
    }

    public init(id: String = UUID().uuidString.lowercased(), thread: String, from: String, to: [String],
                at: String = MessageTime.now(), kind: String = "text", text: String, attachments: [Attachment] = [], replyTo: String? = nil) {
        self.id = id; self.thread = thread; self.from = from; self.to = to; self.at = at
        self.kind = kind; self.text = text; self.attachments = attachments; self.reply_to = replyTo
    }
}

/// Email-FS/1: one email, its RFC 5322 text and a small card.
public struct EmailMessage: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let formatID = "email-fs/1"

    public var format: String = EmailMessage.formatID
    public var id: String
    public var thread: String
    public var from: String
    public var to: [String]
    public var at: String
    public var kind: String = "email"
    public var card: Card
    public var eml: String
    public var reply_to: String?

    public struct Card: Codable, Equatable, Hashable, Sendable {
        public var from: String
        public var to: [String]
        public var subject: String
        public var date: String
        public var thread: String
        public var sha256: String
    }

    /// Builds the .eml exactly as messages.mjs does (CRLF line ends) and its card.
    public init(id: String = UUID().uuidString.lowercased(), thread: String, from: String, to: [String], subject: String,
                text: String, at: String = MessageTime.now(), replyTo: String? = nil) {
        self.id = id; self.thread = thread; self.from = from; self.to = to; self.at = at; self.reply_to = replyTo
        let domain = "team.web-summit.sgit.ai"
        var lines = ["From: \(from)", "To: \(to.joined(separator: ", "))", "Subject: \(subject)",
                     "Date: \(MessageTime.rfc1123(at))", "Message-ID: <\(id)@\(domain)>"]
        if let replyTo { lines.append("In-Reply-To: <\(replyTo)@\(domain)>") }
        lines += ["MIME-Version: 1.0", "Content-Type: text/plain; charset=utf-8", "", text]
        eml = lines.joined(separator: "\r\n")
        card = Card(from: from, to: to, subject: subject, date: at, thread: thread, sha256: MessageCrypto.sha256Hex(Data(eml.utf8)))
    }

    /// The body: everything after the first blank line.
    public var body: String {
        guard let r = eml.range(of: "\r\n\r\n") else { return eml }
        return String(eml[r.upperBound...])
    }
}

/// Either kind, decoded by its `format`.
public enum TeamMessage: Equatable, Hashable, Sendable, Identifiable {
    case chat(ChatMessage)
    case email(EmailMessage)

    public var id: String { switch self { case .chat(let m): m.id; case .email(let m): m.id } }
    public var thread: String { switch self { case .chat(let m): m.thread; case .email(let m): m.thread } }
    public var from: String { switch self { case .chat(let m): m.from; case .email(let m): m.from } }
    public var to: [String] { switch self { case .chat(let m): m.to; case .email(let m): m.to } }
    public var at: String { switch self { case .chat(let m): m.at; case .email(let m): m.at } }
    /// One line for a list or a notification.
    public var preview: String {
        switch self {
        case .chat(let m): m.text.split(separator: "\n").first.map(String.init) ?? ""
        case .email(let m): "New email: \(m.card.subject)"
        }
    }

    enum Failure: Error, Equatable { case unknownFormat(String), badKind(String) }

    public static func decode(_ data: Data) throws -> TeamMessage {
        struct Head: Decodable { var format: String }
        let head = try JSONDecoder().decode(Head.self, from: data)
        switch head.format {
        case ChatMessage.formatID:
            let m = try JSONDecoder().decode(ChatMessage.self, from: data)
            guard ChatMessage.kinds.contains(m.kind) else { throw Failure.badKind(m.kind) }
            return .chat(m)
        case EmailMessage.formatID:
            return .email(try JSONDecoder().decode(EmailMessage.self, from: data))
        default:
            throw Failure.unknownFormat(head.format)
        }
    }

    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        switch self {
        case .chat(let m): return try enc.encode(m)
        case .email(let m): return try enc.encode(m)
        }
    }
}

/// Thread ids, as messages.mjs makes them.
public enum MessageThread {
    public static func direct(_ names: [String]) -> String { "dm:" + names.sorted().joined(separator: "+") }
    public static func group(_ name: String) -> String { "group:" + name }
}

public enum MessageTime {
    /// ISO 8601 in UTC without fractional seconds: 2026-11-09T13:01:20Z.
    public static func now(_ date: Date = .now) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    public static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// The Date header, as JavaScript's toUTCString: "Mon, 09 Nov 2026 13:01:20 GMT".
    static func rfc1123(_ iso: String) -> String {
        guard let d = date(iso) else { return iso }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return f.string(from: d)
    }
}
