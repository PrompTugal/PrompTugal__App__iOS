# Status · vault · App Review readiness

> In progress. All seven items are coded and pushed on night/vault. CI run 206 (package: signatures, error text, caps) is running; the app half is in the next run. Not yet ready to merge.

Branch `night/vault`, merged with `origin/dev` (8c7fad1 and later). Line numbers in the findings are from d4f4292.

## Done (pushed; CI noted per item)

1. **S1 Signatures enforced, signers pinned.**
   - An invalid signature is refused in every mode (`SGitVault.commit`).
   - `VaultSession.makeReader` and `openAccount` now build readers with `requireSignatures: true` and a `VaultTrust`. The head commit must then carry a verified signature from a trusted key.
   - Trusted keys per vault (`PrompTugal/Vault/VaultTrustStore.swift`):
     - this device's signer;
     - signers the person approves (the Vault screen shows "Trust this signer" with the key id);
     - keys listed in `.vault/trusted-keys.json` by the newest earlier commit signed by a pinned key. One level only: a listed key cannot list others.
   - A key is never trusted because its public half sits in `bare/keys/` of the same vault.
   - **First use.** When a vault is opened on a device for the first time, the keys that signed its history at that moment are pinned. The person chose to import that key, and sgit's real team vaults have one signing key per clone and no trust file today, so refusing them all would lock the team out. After that, a new signer is refused until it is approved or listed.
   - **Legacy history.** Only the head is required to be signed by a trusted key. Older commits are still read, so a vault with unsigned legacy history opens; an *invalid* signature anywhere is still refused. sgit 0.27's fixtures are all signed and read strictly (tested).
   - Tests (`SignaturePolicyTests`):
     - a tampered signature is refused (strict and permissive);
     - an unknown signer is refused even though its key is in the vault, and accepted after the person pins it;
     - a good signature from a pinned key is accepted;
     - the trust file works one level only;
     - with no pins and no first use, the vault is refused;
     - the sgit fixtures pin exactly their signers.
2. **S3 No Keychain item without access control.**
   - `.deviceUnlocked` is gone from the save path. If neither Face ID (`.biometryCurrentSet`) nor the passcode (`.userPresence`) is available, saving is refused with "Set a passcode on this device…".
   - The check runs before the old key is deleted.
   - The Vault screen shows the real protection of the stored keys (`VaultKeychain.protectionSummary()`), including a warning for keys stored before this change.
3. **S5 "My vault" never falls back to `vaults.first`.**
   - "My vault" is, in order: the person's explicit choice ("Make this my vault"), the passkey account's reader vault, a key imported with "This is my own vault", then the master.
   - Pasted or teammate keys get the role `teammate` and never qualify. Keys stored earlier with the role `imported` don't either.
   - Collab's `AIKeyStore.loadFromVault` reads through `session.readFile(path)` → `session.reader`, so it now only ever reads "my vault". Collab needs no change.
   - Tests: `MyVaultTests` in `PrompTugalTests/VaultAppTests.swift`.
4. **S6** The key field is a `SecureField` (`.privacySensitive`, password content type).
5. **Q7 Readable errors.**
   - `VaultError` is a `LocalizedError` with short sentences and no ids, paths or keys.
   - `KeychainError` and the passkey errors too.
   - `VaultSession.userMessage(for:)` is used everywhere `String(describing: error)` was shown. The full detail goes to the vault traffic log only.
   - Tests: the package's `testUserFacingErrorsCarryNoIdsOrPaths`, and the app's `VaultErrorTextTests`.
6. **S7**
   - Inflate streams through Compression and stops at 64 MB.
   - HTTP reads stop at 16 MB (`HTTPVaultTransport.maxResponseBytes`).
   - `parts.last!` is guarded.
   - An empty passphrase no longer force-unwraps a nil pointer.
   - `walkTree` refuses trees deeper than 64 folders.
   - After a paste-import, the app offers to clear the clipboard.
   - Tests: inflate cap and truncation, depth cap with a control, empty-passphrase PBKDF2 against Python.
7. **Demo vault for the reviewer: `scripts/vault/make_review_demo_vault.py`.**
   - It makes a new throwaway vault with a README and three public sessions as picks, and no team data.
   - The key is printed once to the terminal, and the script refuses to write inside the repo. Pushing needs `--token`.
   - Steps for App Review notes are in the script's header. Give the reviewer the **read** key only.

## In progress

- CI: run 206 for the package commit 93de6d4; the next run covers the app half. I will mark this page green with the run numbers.

## Blocked / needs from others

- **Dinis**: an access token for the throwaway review vault (to push it), and the decision on how the reviewer gets the read key (App Review notes).
- **Design**: S6's app-switcher cover is design's. The key field itself is now secure.
