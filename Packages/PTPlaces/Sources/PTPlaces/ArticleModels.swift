import CryptoKit
import Foundation

// PrompTugal.news's own articles, read in the app (c.ios next version, item 1):
//   https://promptugal.news/api/v1/articles/<id>.json      the record: title, date, author, summary, sources...
//   https://promptugal.news/articles/<id>.md               the markdown twin the signature covers
//   https://promptugal.news/articles/<id>.md.sig           {signature (base64, P-256 r||s), fingerprint, form}
//   https://promptugal.news/board/keys.json                the agents' public keys (bundle.sign, PEM)
//   https://promptugal.news/api/v1/articles/provenance.json   how each article was made (P0 to P5)
// The signature is checked on the phone. The signed bytes are the site's form 2
// (newsroom/build/signed-form.cjs in PrompTugal__News__Website): the twin with the site version in its source line
// and its agent block written as VERSION, and the agent block's last "built by" line written as "built by: BUILDER".
// A key's fingerprint is "sha256:" and the first 16 hex digits of SHA-256 over its SubjectPublicKeyInfo (DER).

public struct ArticleRoute: Hashable, Sendable {
    public let id: String
    public init(_ id: String) { self.id = id }
}

enum ArticleLinks {
    static let site = URL(string: "https://promptugal.news/")!

    static func record(_ id: String) -> URL { site.appendingPathComponent("api/v1/articles/\(id).json") }
    static func twin(_ id: String) -> URL { site.appendingPathComponent("articles/\(id).md") }
    static func signature(_ id: String) -> URL { site.appendingPathComponent("articles/\(id).md.sig") }
    static func page(_ id: String) -> URL { site.appendingPathComponent("articles/\(id).html") }
    static let keys = URL(string: "https://promptugal.news/board/keys.json")!
    static let provenance = URL(string: "https://promptugal.news/api/v1/articles/provenance.json")!

    /// The article id in one of our article links ("https://promptugal.news/articles/<id>.html" or ".md"), else nil.
    static func id(from link: String) -> String? {
        guard let url = URL(string: link), let host = url.host()?.lowercased(),
              host == "promptugal.news" || host == "www.promptugal.news" else { return nil }
        let parts = url.path().split(separator: "/").map(String.init)
        guard parts.count == 2, parts[0] == "articles" else { return nil }
        let name = parts[1]
        for ext in [".html", ".md"] where name.hasSuffix(ext) {
            let id = String(name.dropLast(ext.count))
            let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "-"))
            return !id.isEmpty && id.unicodeScalars.allSatisfy(allowed.contains) ? id : nil
        }
        return nil
    }
}

// MARK: - The record

struct ArticleRecord: Decodable, Sendable, Equatable {
    var id: String
    var title: String
    var date: String
    var author: String
    var summary: String
    var licence: String
    /// "published", or "withdrawn" for an article taken down.
    var status: String
    var page: String
    var twin: String
    var signature: String
    var words: Int?
    var sources: [ArticleSource]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = try c.decode(String.self, forKey: AnyKey("id"))
        title = c.string("title") ?? id
        date = c.string("date") ?? ""
        author = c.string("author") ?? ""
        summary = c.string("summary") ?? ""
        licence = c.string("licence") ?? c.string("license") ?? ""
        status = c.string("status") ?? ""
        page = c.string("page") ?? ArticleLinks.page(id).absoluteString
        twin = c.string("twin") ?? ArticleLinks.twin(id).absoluteString
        signature = c.string("signature") ?? ArticleLinks.signature(id).absoluteString
        words = c.int("words")
        sources = c.lenientArray("sources")
    }
}

struct ArticleSource: Decodable, Sendable, Equatable, Hashable {
    var url: String
    var host: String
    var text: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let link = c.string("url") ?? ""
        guard let web = PlaceLinks.web(link) else {
            throw DecodingError.dataCorruptedError(forKey: AnyKey("url"), in: c, debugDescription: "no web link")
        }
        url = link
        host = c.string("host") ?? web.host() ?? ""
        text = c.string("text") ?? ""
    }
}

// MARK: - The signature and the keys

struct ArticleSignature: Decodable, Sendable, Equatable {
    var signature: String
    var fingerprint: String
    var form: String

    init(signature: String, fingerprint: String, form: String) {
        self.signature = signature; self.fingerprint = fingerprint; self.form = form
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        signature = c.string("signature") ?? ""
        fingerprint = c.string("fingerprint") ?? ""
        form = c.string("form") ?? ""
    }
}

struct SigningKeys: Decodable, Sendable, Equatable {
    var keys: [SigningKey]

    init(keys: [SigningKey]) { self.keys = keys }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        keys = c.lenientArray("keys")
    }
}

struct SigningKey: Decodable, Sendable, Equatable {
    var id: String
    var agent: String
    var status: String
    /// The public signing key, PEM (SubjectPublicKeyInfo).
    var signPEM: String

    init(id: String, agent: String, status: String = "active", signPEM: String) {
        self.id = id; self.agent = agent; self.status = status; self.signPEM = signPEM
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.string("id") ?? ""
        agent = c.string("agent") ?? c.string("label") ?? ""
        status = c.string("status") ?? ""
        let bundle = c.lenient(KeyBundle.self, "bundle")
        guard let pem = bundle?.sign, !pem.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: AnyKey("bundle"), in: c, debugDescription: "no signing key")
        }
        signPEM = pem
    }

    private struct KeyBundle: Decodable {
        var sign: String?
    }
}

/// What the phone found when it checked an article's signature. Never a tick it did not earn.
/// States and words from c.ios.explore's spec (briefs/2026-11-26__next-version/spec-languages-and-signatures.md, s. 2).
enum SignatureCheck: Equatable, Sendable {
    case checking
    /// The signature matches the text, with a published key; `agent` is the key's owner. `handedOver` when the key's
    /// status is not "active" (superseded: the key has since been handed over).
    case verified(agent: String, keyID: String, handedOver: Bool)
    /// Checked, and it does not match.
    case failed(String)
    /// Signed in an older form (no form, or form 1) that cannot be checked after a release; never "invalid".
    case olderForm
    /// No .sig is published for the article.
    case notSigned
    /// Not checked, with the reason.
    case notChecked(String)
}

enum ArticleSigning {
    static let form = "twin-without-version-or-builder/2"

    /// The bytes the signature covers (form 2), from the twin as served.
    static func signedForm(_ twin: String) -> String {
        var text = replaceFirst(#"^(\*Source: <[^>\n]+> · site )v\d+\.\d+\.\d+( ·)"#, in: twin, with: "$1VERSION$2")
        text = replaceFirst(#"^version: v\d+\.\d+\.\d+$"#, in: text, with: "version: VERSION")
        return replaceLast(#"^built by: .*$"#, in: text, with: "built by: BUILDER")
    }

    /// "sha256:" and the first 16 hex digits of SHA-256 over the key's DER, as the site writes it.
    static func fingerprint(pem: String) -> String? {
        guard let der = derFromPEM(pem) else { return nil }
        let hex = SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
        return "sha256:" + hex.prefix(16)
    }

    static func derFromPEM(_ pem: String) -> Data? {
        let body = pem.split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        return Data(base64Encoded: String(body))
    }

    /// Checks the signature over the twin against the published key with the signature's fingerprint. The
    /// fingerprint is worked out here from each key, never taken from the key list's own label.
    static func check(twin: String, signature: ArticleSignature, keys: [SigningKey]) -> SignatureCheck {
        guard signature.form == form else { return .olderForm }
        // The site refuses a twin with more than one "built by" line; so does the phone.
        let builders = (try? NSRegularExpression(pattern: "^built by: .*$", options: [.anchorsMatchLines]))?
            .numberOfMatches(in: twin, range: NSRange(location: 0, length: (twin as NSString).length)) ?? 0
        guard builders <= 1 else {
            return .notChecked(String(localized: "the text has more than one \"built by\" line"))
        }
        guard let raw = Data(base64Encoded: signature.signature), raw.count == 64,
              let ecdsa = try? P256.Signing.ECDSASignature(rawRepresentation: raw) else {
            return .notChecked(String(localized: "the signature file could not be read"))
        }
        guard let key = keys.first(where: { fingerprint(pem: $0.signPEM) == signature.fingerprint }) else {
            return .notChecked(String(localized: "no published key has the fingerprint \(signature.fingerprint)"))
        }
        guard let publicKey = try? P256.Signing.PublicKey(pemRepresentation: key.signPEM) else {
            return .notChecked(String(localized: "the signing key is not a P-256 key"))
        }
        let message = Data(signedForm(twin).utf8)
        guard publicKey.isValidSignature(ecdsa, for: message) else {
            return .failed(String(localized: "the signature does not match this text"))
        }
        let agent = key.agent.isEmpty ? key.id : key.agent
        switch key.status {
        case "active", "": return .verified(agent: agent, keyID: key.id, handedOver: false)
        case "superseded": return .verified(agent: agent, keyID: key.id, handedOver: true)
        default: return .notChecked(String(localized: "the key is marked \(key.status) in the key list"))
        }
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static func replaceFirst(_ pattern: String, in text: String, with template: String) -> String {
        guard let re = regex(pattern) else { return text }
        let ns = text as NSString
        guard let match = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return text }
        let replacement = re.replacementString(for: match, in: text, offset: 0, template: template)
        return ns.replacingCharacters(in: match.range, with: replacement)
    }

    private static func replaceLast(_ pattern: String, in text: String, with literal: String) -> String {
        guard let re = regex(pattern) else { return text }
        let ns = text as NSString
        guard let match = re.matches(in: text, range: NSRange(location: 0, length: ns.length)).last else { return text }
        return ns.replacingCharacters(in: match.range, with: literal)
    }
}

// MARK: - How it was made

struct ArticleProvenanceFile: Decodable, Sendable, Equatable {
    var ladder: [String: String]
    var articles: [ArticleProvenance]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        ladder = c.lenient([String: String].self, "ladder") ?? [:]
        articles = c.lenientArray("articles")
    }

    /// The entry for an article id (its url ends in "articles/<id>.html").
    func entry(for id: String) -> ArticleProvenance? {
        articles.first { ArticleLinks.id(from: $0.url.hasPrefix("http") ? $0.url : "https://promptugal.news/" + $0.url) == id }
    }
}

struct ArticleProvenance: Decodable, Sendable, Equatable {
    var url: String
    var level: String
    var levelName: String
    var type: String
    var origin: String
    var research: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        url = c.string("url") ?? ""
        let words = c.lenient(Words.self, "words")
        level = c.string("level") ?? words?.level ?? ""
        levelName = words?.levelName ?? ""
        type = words?.type ?? c.string("type") ?? ""
        origin = words?.origin ?? c.string("origin") ?? ""
        research = words?.research ?? c.string("research") ?? ""
    }

    var isEmpty: Bool { level.isEmpty && type.isEmpty && origin.isEmpty && research.isEmpty }

    private struct Words: Decodable {
        var type: String?
        var origin: String?
        var research: String?
        var level: String?
        var levelName: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            type = c.string("type"); origin = c.string("origin"); research = c.string("research")
            level = c.string("level"); levelName = c.string("level_name")
        }
    }
}
