import Foundation
import SGitVault

/// Constants the app shares with the website. Changing the passkey ones locks every existing account out.
enum VaultConfig {
    /// Vault server: reads are `GET /api/vault/read/<vault id>/<path>`, no auth.
    static let server = VaultAddress.defaultServer

    /// The passkey's relying party id. The website asks for the passkey with `rpId: location.hostname`
    /// on https://promptugal.news/account/vault.html (source: https://promptugal.news/assets/vault/door.js,
    /// `prfBytes`, read 7 Nov 2026). The app must be listed under `webcredentials` in
    /// https://promptugal.news/.well-known/apple-app-site-association, and the app needs the
    /// associated domain `webcredentials:promptugal.news`.
    static let relyingPartyId = "promptugal.news"

    /// The PRF input (WebAuthn `prf.eval.first`): SHA-256("web-summit.newsroom.sgit.ai/door/v1").
    /// Source: https://promptugal.news/assets/vault/door.js (`PRF_INPUT_TEXT`, `RP_FOR_DERIVATION`), read 7 Nov 2026.
    static var prfSalt: Data { VaultDoor.prfSalt }

    /// Passkey PRF unlock is behind a flag until the website lists the app in its association file.
    static var passkeyPRFEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vault.passkeyPRF") }
        set { UserDefaults.standard.set(newValue, forKey: "vault.passkeyPRF") }
    }

    /// Keychain service for vault keys.
    static let keychainService = "news.promptugal.reader.vault"

    /// How long one Face ID unlock is reused (contract: 60 seconds or less).
    static let faceIDReuseSeconds: TimeInterval = 60

    /// BGAppRefreshTask identifier. Platform adds it to BGTaskSchedulerPermittedIdentifiers.
    static let backgroundRefreshTask = "news.promptugal.reader.vault-refresh"

    /// Ciphertext object cache, kept forever (objects never change).
    static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SGitVault", directoryHint: .isDirectory)
    }
}
