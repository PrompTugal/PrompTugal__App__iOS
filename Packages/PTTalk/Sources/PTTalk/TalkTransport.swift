import CryptoKit
import Foundation
import PTLanes

/// The app's way to the conductor: a payload is signed with the given P-256 key, cut into parts, each part sealed to
/// the conductor's RSA key (sgit hybrid envelope, PTLanes) and appended to its lane, with retries. PTPlaces' comments
/// call it through its `PlacesTalk` protocol, whose two methods this matches exactly
/// (`extension TalkTransport: PlacesTalk {}` in PTPlaces, or the app, is the whole adapter).
///
/// The lane link is pasted (or scanned) on the device, in Talk → Lanes; nothing is built in. See ENVELOPE.md for
/// what the receiver gets and how it verifies the signature.
public struct TalkTransport: Sendable {
    public enum Failure: Error, Equatable, LocalizedError {
        case noLane
        case repliesNotAgreed
        public var errorDescription: String? {
            switch self {
            case .noLane: "No conductor lane on this device yet: paste its sgi1. link in More → Talk to the newsroom → Lanes."
            case .repliesNotAgreed: "Replies are not connected yet: the reply lane's format is still being agreed."
            }
        }
    }

    private let link: @Sendable () async -> String?
    private let writer: LaneWriter
    private let retry: Bool
    private let app: String

    /// `link` gives the conductor's `sgi1.` link when asked (read at each send, so a newly pasted lane is used).
    public init(link: @escaping @Sendable () async -> String?, transport: LaneTransport = URLSessionLaneTransport(),
                retry: Bool = true, app: String = TalkApp.line) {
        self.link = link
        self.writer = LaneWriter(transport: transport)
        self.retry = retry
        self.app = app
    }

    /// The conductor's lane as pasted on this device (TalkLanes).
    public static var conductor: TalkTransport {
        TalkTransport(link: { await MainActor.run { TalkLanes.shared.conductorLink } })
    }

    /// Whether a lane is set, for a UI that wants to say "not connected" before trying.
    public func isConnected() async -> Bool { await link().flatMap(SealedLane.parse) != nil }

    /// Signs and sends one payload (PTPlaces: the `promptugal/comment/v1` JSON) as an item of its own, purpose
    /// `comment`: `meta.json` then `payload.json` in parts, every message signed with `key`. Throws after the last try.
    public func send(_ payload: Data, signedBy key: P256.Signing.PrivateKey) async throws {
        guard let lane = await link().flatMap(SealedLane.parse) else { throw Failure.noLane }
        let item = TalkWire.itemId(purpose: .comment, town: Self.place(in: payload))
        let messages = try TalkWire.messages(item: item, purpose: .comment, to: "conductor", town: Self.place(in: payload),
                                             text: "", attachments: [.init(kind: .payload, name: "payload.json", data: payload)],
                                             app: app, signer: TalkWire.Signer(key: key))
        try await send(messages, to: lane)
    }

    /// The person's replies, each the JSON of a ws-ecies-1 envelope sealed to them.
    /// TODO(appdev.talk, ios.places, dev.places): read the person's reply lane once its address and format are agreed
    /// (ios.places@ is agreeing them with dev.places@ via conductor@). Until then this throws, so no screen pretends.
    public func replies(for person: String) async throws -> [Data] {
        throw Failure.repliesNotAgreed
    }

    /// Writes prepared messages with the retry policy (five tries, resuming at the part that failed).
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
