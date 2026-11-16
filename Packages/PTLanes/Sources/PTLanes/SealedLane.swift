import Foundation
import Security

/// The public face of an append lane given as an `sgi1.` link, for packages outside PTLanes (PTTalk): parse the
/// link, seal bytes to its recipient with the sgit hybrid envelope, and build the blind write request. Everything
/// in a lane link is public by design (a vault id, a write-only token, a public key); nothing here holds a secret.
public struct SealedLane: Sendable, Hashable {
    let address: LaneAddress

    public var vault: String { address.vault }
    public var fingerprint: String { address.fingerprint }
    /// The token, shortened for a screen: never needed in full outside the request.
    public var tokenHint: String { String(address.token.prefix(6)) + "…" }
    public var endpointHost: String { address.endpoint.host() ?? "" }

    /// The lane in an `sgi1.<vault>.<token>.<SPKI base64url>` link, alone or inside other text (a URL, a message).
    /// Nil when there is none or its key is not RSA.
    public static func parse(_ text: String) -> SealedLane? {
        LaneAddress.parseInboxLink(text).map(SealedLane.init(address:))
    }

    /// The `.enc` text (base64 of the envelope JSON) encoded once more, as the lane's `payload` field wants it.
    public func seal(_ plaintext: Data) throws -> String {
        let key = try LaneCrypto.publicKey(pem: address.publicKeyPEM)
        return LaneCrypto.lanePayload(encText: try LaneCrypto.encrypt(plaintext, to: key))
    }

    /// `POST /api/vault/append/write/<vault>` with `{append_token, payload}`. Only dev.send.sgraph.ai is allowed.
    public func writeRequest(payload: String, timeout: TimeInterval = 120) throws -> URLRequest {
        var request = try LaneClient.writeRequest(to: address, payload: payload)
        request.timeoutInterval = timeout
        return request
    }

    /// Opens a lane payload with the recipient's private key (the receiving end; tests use it for round trips).
    public static func open(payload: String, with privateKey: SecKey) throws -> Data {
        try LaneCrypto.decrypt(LaneCrypto.encText(fromLaneContent: payload), with: privateKey)
    }

    /// An `sgi1.` link for a vault, token and RSA public key (SPKI DER): the form conductor.py prints.
    public static func link(vault: String, token: String, spki: Data) -> String {
        let key = spki.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "sgi1.\(vault).\(token).\(key)"
    }

    /// SPKI DER of an RSA public key, for `link(vault:token:spki:)`.
    public static func spki(of publicKey: SecKey) -> Data? {
        guard let pkcs1 = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else { return nil }
        return LaneCrypto.spki(fromPKCS1: pkcs1)
    }
}
