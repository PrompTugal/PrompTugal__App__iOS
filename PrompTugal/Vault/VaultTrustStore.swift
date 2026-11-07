import Foundation
import SGitVault

/// The signer keys this device trusts, per vault (S1). Key ids are public, not secrets.
///
/// - The first open of a vault pins the keys that signed its history at that moment
///   (trust on first use: the person chose to import that key).
/// - This device's own commit key is always trusted.
/// - A new signer after that is refused until the person approves it
///   (`VaultSession.trustSigner`) or a trusted key lists it in `.vault/trusted-keys.json`.
@MainActor
enum VaultTrustStore {
    private static func defaultsKey(_ vaultId: String) -> String { "vault.trust.\(vaultId)" }

    static func trust(for vaultId: String, defaults: UserDefaults = .standard) -> VaultTrust {
        var trust = VaultTrust()
        if let data = defaults.data(forKey: defaultsKey(vaultId)),
           let stored = try? JSONDecoder().decode(VaultTrust.self, from: data) {
            trust = stored
        }
        if let device = VaultDeviceSigner.inventory()?.keyId, !trust.pinnedKeyIds.isEmpty {
            trust.pinnedKeyIds.insert(device)
        }
        return trust
    }

    static func save(_ trust: VaultTrust?, for vaultId: String, defaults: UserDefaults = .standard) {
        guard let trust, !trust.pinnedKeyIds.isEmpty, let data = try? JSONEncoder().encode(trust) else { return }
        defaults.set(data, forKey: defaultsKey(vaultId))
    }

    static func forget(_ vaultId: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey(vaultId))
    }
}
