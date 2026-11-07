import AuthenticationServices
import CryptoKit
import Foundation
import SGitVault
#if canImport(UIKit)
import UIKit
#endif

/// The ways into a vault on this device.
///
/// 1. **Paste or scan a key** (always works): `sgit_private_read_<64 hex>:<vault id>`, `sgit_public_read_…`,
///    `<64 hex>:<vault id>`, or a vault key `sgit_private_vault_<passphrase>:<vault id>`. A QR code holds the same text.
/// 2. **Passkey with PRF** (behind `VaultConfig.passkeyPRFEnabled`): the same passkey and the same PRF input as
///    promptugal.news give the same 32 bytes, which open the door vault, then the master, then the reader vault.
///    The PRF bytes are used once and dropped.
/// 3. **Recovery code**: the website's 26-character code, used in place of the PRF bytes.
enum VaultUnlock {
    /// Text from the clipboard or a QR code, cleaned: whitespace dropped, a `#key=` link fragment unwrapped.
    static func keyText(fromScanned raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "#key=") {
            text = String(text[range.upperBound...])
            text = text.removingPercentEncoding ?? text
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Does this look like a vault key? Cheap; for enabling a button.
    static func looksLikeKey(_ raw: String) -> Bool {
        let text = keyText(fromScanned: raw)
        return VaultKey.classify(text) != nil && text.contains(":")
    }
}

/// Passkey assertion with the PRF extension (iOS 18).
@MainActor
final class PasskeyPRF: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum PRFError: Error, CustomStringConvertible, LocalizedError {
        case disabled, noPRF, cancelled, failed(String)
        var description: String {
            switch self {
            case .disabled: "Passkey unlock is turned off (VaultConfig.passkeyPRFEnabled)."
            case .noPRF: "The passkey signed but returned no PRF bytes. Use a recovery code or paste a key."
            case .cancelled: "The passkey request was cancelled."
            case .failed(let why): "The passkey request failed: \(why)"
            }
        }
        var errorDescription: String? {
            switch self {
            case .failed: "The passkey request failed. Try again, or paste your key."
            default: description
            }
        }
    }

    private var continuation: CheckedContinuation<Data, Error>?
    private var controller: ASAuthorizationController?

    /// Ask for the passkey and return the 32 PRF bytes. The caller must drop them after deriving the door.
    func prfBytes() async throws -> Data {
        guard VaultConfig.passkeyPRFEnabled else { throw PRFError.disabled }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: VaultConfig.relyingPartyId)
        var challenge = Data(count: 32)
        _ = challenge.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.userVerificationPreference = .required
        request.prf = .inputValues(.saltInput1(VaultConfig.prfSalt))
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        let bytes = credential?.prf.map { $0.first.withUnsafeBytes { Data($0) } }
        MainActor.assumeIsolated {
            if let bytes { finish(.success(bytes)) } else { finish(.failure(PRFError.noPRF)) }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let mapped: Error
        if let auth = error as? ASAuthorizationError, auth.code == .canceled {
            mapped = PRFError.cancelled
        } else {
            mapped = PRFError.failed(error.localizedDescription)
        }
        MainActor.assumeIsolated { finish(.failure(mapped)) }
    }

    private func finish(_ result: Result<Data, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if canImport(UIKit)
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
            #else
            return ASPresentationAnchor()
            #endif
        }
    }
}
