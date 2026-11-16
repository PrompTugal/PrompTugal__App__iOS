import CryptoKit
import Foundation
import PTLanes

/// The app's way to the conductor, for PTPlaces' comments through its `PlacesTalk` protocol, whose two methods this
/// matches exactly (`extension TalkTransport: PlacesTalk {}` is the whole adapter).
///
/// `TalkTransport.conductor` is the agreed comment lane (conductor@ and dev.places@, 16 November 03:41 UTC):
/// - send: reads `https://promptugal.news/board/inbox.json` at each send (nothing is built in; the token can be
///   reissued), takes `endpoint`, `vault_id`, `talk_lane.append_token` and `recipient.encrypt` (checked against
///   `recipient.fingerprint`), seals the comment JSON as it is (it carries its own person signature, which the
///   conductor's drain verifies) and appends it, with retries.
/// - replies: reads `https://promptugal.news/api/v1/talk/replies.json` and returns every reply envelope
///   (ws-ecies-1, sealed to one reader); the caller opens the ones sealed to it and drops the rest.
///
/// `TalkTransport(link:)` is the other mode: a lane link scanned or pasted on the device, where each item goes as
/// TalkWire messages (meta.json, then the payload in parts), every message signed with the key (ENVELOPE.md).
public struct TalkTransport: Sendable {
    public enum Failure: Error, Equatable, LocalizedError {
        case noLane
        case inbox(String)
        case replies(String)
        public var errorDescription: String? {
            switch self {
            case .noLane: "No lane to send to: the conductor's lane is not set on this device."
            case .inbox(let why): "The conductor's inbox could not be read (\(why))."
            case .replies(let why): "The replies could not be read (\(why))."
            }
        }
    }

    /// Fetches a URL's bytes (a seam for tests).
    public typealias Fetch = @Sendable (URL) async throws -> Data

    enum Mode: Sendable {
        /// The comment JSON, sealed as it is, one lane message.
        case raw
        /// TalkWire items: meta.json and the payload in parts, each message signed.
        case items
    }

    private let lane: @Sendable () async throws -> SealedLane
    private let mode: Mode
    private let writer: LaneWriter
    private let retry: Bool
    private let app: String
    private let fetch: Fetch
    private let repliesURL: URL?

    public static let inboxURL = URL(string: "https://promptugal.news/board/inbox.json")!
    public static let repliesURL = URL(string: "https://promptugal.news/api/v1/talk/replies.json")!

    public static let liveFetch: Fetch = { url in
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw URLError(.badServerResponse) }
        guard data.count <= 2 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        return data
    }

    /// The agreed comment lane: the conductor's `talk_lane` from inbox.json, and the published replies.
    public static var conductor: TalkTransport { comments() }

    /// The comment lane, with seams for tests.
    public static func comments(inbox: URL = inboxURL, replies: URL = repliesURL, fetch: @escaping Fetch = liveFetch,
                                transport: LaneTransport = URLSessionLaneTransport(), retry: Bool = true,
                                app: String = TalkApp.line) -> TalkTransport {
        TalkTransport(lane: { try ConductorInbox.parse(try await fetch(inbox)).talkLane() }, mode: .raw,
                      transport: transport, retry: retry, app: app, fetch: fetch, repliesURL: replies)
    }

    /// A lane link scanned or pasted on the device (`link` is read at each send). Items go as signed TalkWire messages.
    public init(link: @escaping @Sendable () async -> String?, transport: LaneTransport = URLSessionLaneTransport(),
                retry: Bool = true, app: String = TalkApp.line) {
        self.init(lane: {
            guard let lane = await link().flatMap(SealedLane.parse) else { throw Failure.noLane }
            return lane
        }, mode: .items, transport: transport, retry: retry, app: app, fetch: TalkTransport.liveFetch, repliesURL: nil)
    }

    init(lane: @escaping @Sendable () async throws -> SealedLane, mode: Mode, transport: LaneTransport, retry: Bool,
         app: String, fetch: @escaping Fetch, repliesURL: URL?) {
        self.lane = lane
        self.mode = mode
        self.writer = LaneWriter(transport: transport)
        self.retry = retry
        self.app = app
        self.fetch = fetch
        self.repliesURL = repliesURL
    }

    /// Whether there is a lane to send to now.
    public func isConnected() async -> Bool { (try? await lane()) != nil }

    /// Sends one payload (PTPlaces: the signed `promptugal/comment/v1` JSON). On the comment lane it is sealed as it
    /// is; on a pasted lane it goes as a TalkWire item signed with `key`. Throws after the last try.
    public func send(_ payload: Data, signedBy key: P256.Signing.PrivateKey) async throws {
        let lane = try await lane()
        let messages: [Data]
        switch mode {
        case .raw:
            messages = [payload]
        case .items:
            let place = Self.place(in: payload)
            let item = TalkWire.itemId(purpose: .comment, town: place)
            messages = try TalkWire.messages(item: item, purpose: .comment, to: "conductor", town: place, text: "",
                                             attachments: [.init(kind: .payload, name: "payload.json", data: payload)],
                                             app: app, signer: TalkWire.Signer(key: key))
        }
        try await send(messages, to: lane)
    }

    /// Every published reply envelope, each as JSON Data. Entries addressed (`to`) to someone other than `person` are
    /// left out when the field says so; entries without `to` are kept, and the caller opens what it can.
    public func replies(for person: String) async throws -> [Data] {
        guard let repliesURL else { return [] }
        let data: Data
        do { data = try await fetch(repliesURL) } catch { throw Failure.replies(error.localizedDescription) }
        return try Self.replies(in: data, for: person)
    }

    static func replies(in data: Data, for person: String) throws -> [Data] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["replies"] as? [Any] else { throw Failure.replies("not a replies file") }
        return list.prefix(1_000).compactMap { entry -> Data? in
            guard let object = entry as? [String: Any] else { return nil }
            if let to = object["to"] as? String, !to.isEmpty, to != person, !Self.sameKey(to, person) { return nil }
            return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        }
    }

    /// `to` may be a person id or a key fingerprint; the caller may hold either. Keep anything that could be theirs.
    static func sameKey(_ to: String, _ person: String) -> Bool {
        to.hasPrefix("sha256:") != person.hasPrefix("sha256:")
    }

    /// Writes prepared messages with the retry policy (five tries, resuming at the message that failed).
    func send(_ messages: [Data], to lane: SealedLane) async throws {
        var written = 0
        var attempt = 1
        while true {
            do {
                try await writer.write(messages, to: lane, from: written) { _, _ in }
                return
            } catch let stopped as LaneWriter.Stopped {
                written = stopped.written
                guard retry, let wait = TalkRetry.wait(before: attempt + 1) else { throw stopped.underlying }
                try await Task.sleep(for: .seconds(wait))
                attempt += 1
            }
        }
    }

    /// The `place` field of a JSON payload, if it has one, to file the item under the town.
    static func place(in payload: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let place = object["place"] as? String, !place.isEmpty else { return nil }
        return TalkWire.safeName(place)
    }
}

/// The conductor's published inbox (`board/inbox.json`): where readers' comments go.
struct ConductorInbox: Sendable, Equatable {
    var endpoint: URL
    var vault: String
    var talkToken: String
    var publicKeyPEM: String
    var fingerprint: String?

    static func parse(_ data: Data) throws -> ConductorInbox {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TalkTransport.Failure.inbox("not JSON")
        }
        let recipient = root["recipient"] as? [String: Any]
        let talk = root["talk_lane"] as? [String: Any]
        guard let vault = root["vault_id"] as? String else { throw TalkTransport.Failure.inbox("no vault_id") }
        guard let token = talk?["append_token"] as? String else { throw TalkTransport.Failure.inbox("no talk_lane.append_token") }
        guard let pem = recipient?["encrypt"] as? String else { throw TalkTransport.Failure.inbox("no recipient.encrypt") }
        let endpoint = (root["endpoint"] as? String).flatMap(URL.init(string:)) ?? URL(string: "https://dev.send.sgraph.ai")!
        return ConductorInbox(endpoint: endpoint, vault: vault, talkToken: token, publicKeyPEM: pem,
                              fingerprint: recipient?["fingerprint"] as? String)
    }

    /// The talk lane, checked: a valid vault and token, the key matching its published fingerprint, an allowed host.
    func talkLane() throws -> SealedLane {
        do {
            return try SealedLane.make(vault: vault, token: talkToken, publicKeyPEM: publicKeyPEM, fingerprint: fingerprint,
                                       endpoint: endpoint)
        } catch {
            throw TalkTransport.Failure.inbox(error.localizedDescription)
        }
    }
}
