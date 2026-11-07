import Foundation
import SGitVault
import Testing
@testable import PrompTugal

// App Review readiness fixes in PrompTugal/Vault (vault session): S1 trust store, S3 keychain errors,
// S5 "my vault", Q7 user-facing errors. The signature policy itself is tested in the SGitVault package.

@Suite("My vault (S5)")
struct MyVaultTests {
    @Test func aTeammateVaultIsNeverMine() {
        #expect(VaultSession.myVaultId(among: [(id: "team1", role: "teammate")], chosen: nil, account: nil) == nil)
        #expect(VaultSession.myVaultId(among: [(id: "old1", role: "imported")], chosen: nil, account: nil) == nil)
    }

    @Test func myOwnVaultWinsOverATeammateOpenedFirst() {
        let vaults = [(id: "team1", role: "teammate"), (id: "mine1", role: "mine")]
        #expect(VaultSession.myVaultId(among: vaults, chosen: nil, account: nil) == "mine1")
    }

    @Test func orderOfPreference() {
        let vaults = [(id: "m", role: "master"), (id: "r", role: "reader"), (id: "t", role: "teammate")]
        #expect(VaultSession.myVaultId(among: vaults, chosen: nil, account: nil) == "r")
        #expect(VaultSession.myVaultId(among: vaults, chosen: nil, account: "r") == "r")
        #expect(VaultSession.myVaultId(among: [(id: "m", role: "master")], chosen: nil, account: nil) == "m")
        // The explicit choice wins, even for a vault opened as a teammate's.
        #expect(VaultSession.myVaultId(among: vaults, chosen: "t", account: "r") == "t")
        // A choice for a vault that is not open falls back to the rule, not to the first vault.
        #expect(VaultSession.myVaultId(among: vaults, chosen: "gone", account: nil) == "r")
    }
}

@Suite("User-facing vault errors (Q7)")
@MainActor
struct VaultErrorTextTests {
    @Test func vaultErrorsReadAsSentencesWithoutIds() {
        let session = VaultSession()
        let error = VaultError.untrustedSigner(commitId: "obj-cas-imm-0123456789ab", keyId: "key-rnd-imm-0011223344556677")
        let text = session.userMessage(for: error, context: "test")
        #expect(!text.contains("obj-cas-imm"))
        #expect(!text.contains("key-rnd-imm"))
        // The detail goes to the traffic log, not the screen.
        #expect(session.log.events.first?.detail.contains("key-rnd-imm-0011223344556677") == true)
    }

    @Test func foreignErrorsDoNotShowErrorDomainStrings() {
        let session = VaultSession()
        let text = session.userMessage(for: NSError(domain: "NSCocoaErrorDomain", code: 4864))
        #expect(!text.contains("Error Domain"))
        #expect(session.userMessage(for: URLError(.notConnectedToInternet)).contains("connection"))
    }

    @Test func keychainRefusesWithAClearMessage() {
        let text = VaultKeychain.KeychainError.noProtection.errorDescription ?? ""
        #expect(text.contains("passcode"))
    }
}

@Suite("Trusted signers (S1)")
@MainActor
struct VaultTrustStoreTests {
    @Test func pinsRoundTripPerVault() throws {
        let defaults = try #require(UserDefaults(suiteName: "vault-trust-tests-\(UUID().uuidString)"))
        #expect(VaultTrustStore.trust(for: "v1", defaults: defaults).pinnedKeyIds.isEmpty)   // first use
        VaultTrustStore.save(VaultTrust(pinnedKeyIds: ["key-rnd-imm-aa"]), for: "v1", defaults: defaults)
        #expect(VaultTrustStore.trust(for: "v1", defaults: defaults).pinnedKeyIds.contains("key-rnd-imm-aa"))
        #expect(VaultTrustStore.trust(for: "v2", defaults: defaults).pinnedKeyIds.isEmpty)
        // Nothing pinned is never saved (it would turn first use off without trusting anyone).
        VaultTrustStore.save(VaultTrust(), for: "v3", defaults: defaults)
        #expect(defaults.data(forKey: "vault.trust.v3") == nil)
        VaultTrustStore.forget("v1", defaults: defaults)
        #expect(VaultTrustStore.trust(for: "v1", defaults: defaults).pinnedKeyIds.isEmpty)
    }
}
