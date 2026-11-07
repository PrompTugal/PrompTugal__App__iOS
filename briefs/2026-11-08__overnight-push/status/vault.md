# Status · Swift vault

> The Swift sgit reader and writer work and are tested on macOS CI over throwaway vaults written by sgit 0.27; what Swift writes, sgit reads back on Linux. App code for Face ID, the Secure Enclave and passkey unlock is in PrompTugal/Vault and type-checks; it is not in the app target yet.

Branch `night/vault`. Updated about 03:10 Lisbon time.

## Done

- **`Packages/SGitVault`**, a local Swift package (tools 6.0, iOS 18, macOS 15), Apple SDK only. It reads a vault the way sgit does: branch index → named branch → ref → commit → trees → blobs.
  - Every object's id is checked against sha256 of its ciphertext (12 and 32 hex) before it is decrypted or cached.
  - Both envelopes: AES-256-GCM, and `\0sgz1` deflate (Apple's raw deflate, with the zlib header and Adler-32 checked by hand).
  - Commit signatures (ECDSA P-256) are checked against sgit's canonical signing bytes, with the author's public key from `bare/keys/`.
  - On-disk object cache: ciphertext only, kept forever. Refs and the branch index are never cached.
  - Pull is incremental: unchanged subtrees are not fetched or decrypted again.
  - Key parsing: `sgit_private_read_…:<id>`, `sgit_public_read_…`, bare `<64 hex>:<id>`, and vault keys `sgit_private_vault_<passphrase>:<id>` (PBKDF2, 600,000 rounds, for the read and write keys).
  - `VaultTrafficLog` records each request, cache hit, decryption, verification, key derivation and error, with sizes and timings. A test checks that no key, write key or passphrase appears in it.
  - `inspect()` returns one snapshot for the debug panel: branches, head, history with messages, tree with sizes, cache stats.
- **Passkey door**, ported from promptugal.news `assets/vault/door.js`: PRF bytes (or a recovery code) → door vault → `master-key.json` → master vault → `reader.json` (and `.vault/access-token.json` when present).
- **Fixtures**: throwaway vaults made by sgit-ai 0.27.0 itself, pushing to its in-memory server. `plain` (format 1, two named branches), `deflate` (format 2, 32-hex ids, a deflated blob) and `account` (door, master, reader). A Python reference reader checks them on Linux CI.
- **Tests (macOS CI, green)**: file ids, PBKDF2 keys, all key forms, decrypt, tree walk, unicode names, deflate, multi-branch index, history, signatures, cache, incremental pull, door vectors, account unlock. Negative controls: wrong key, another passkey, flipped byte in a blob, a commit and a ref, a re-hashed forged object, a damaged cache file, a pack vault, invalid key text, changed signed bytes.
- **CI**: `.github/workflows/ios-vault.yml` runs `swift test` on macOS 15 for pushes to `night/vault`, plus the Python reference reader on Linux.

- **Writes**: `VaultCommitBuilder` makes sgit's blobs, trees, signed commits and refs. Rebuilding a commit's tree from its own files gives sgit's tree id byte for byte (tested on all four fixture branches). `SGitVault.commit(...)` pushes to a named branch through `POST /api/vault/batch/<id>`: objects first, then the ref with compare-and-swap, or a new branch entry in the index with compare-and-swap. A lost race is `VaultError.pushConflict` and overwrites nothing (tested).
- **sgit reads what Swift wrote**: CI exports the vaults the Swift tests wrote; a Linux job loads them into sgit-ai 0.27's in-memory server, clones, switches to the Swift branch, verifies every signature and compares every file.
- **`PrompTugal/Vault/`** (type-checked in CI against the package for the iOS 18 simulator, Swift 5 and 6):
  - `VaultConfig`: server, relying party `promptugal.news`, PRF input, flag `vault.passkeyPRF` (off), background task id.
  - `VaultKeychain`: keys as Keychain items with `.biometryCurrentSet`, this device only (falls back to user presence, then device-unlocked where there is no biometry, and records which). One `LAContext` reused for 60 seconds. `inventory()` lists keys without secrets or a prompt.
  - `VaultKeyWrap`: a Secure Enclave P-256 key wraps each stored key (ECDH + HKDF + AES-GCM), so the Keychain bytes are useless off this device.
  - `VaultUnlock` / `PasskeyPRF`: paste or QR text (also `#key=` links); passkey assertion with the PRF extension behind the flag; recovery code.
  - `VaultSession` (`@Observable`): open vaults, pull on foreground, background refresh hook, lock, inspector, cache stats, key inventory, and `commit(...)` to this device's branch `device-<8 chars>`.
  - `VaultDeviceSigner`: this device's commit key in the Secure Enclave (Face ID to sign), software key on the simulator.

## In progress

- Waiting for CI on the writer and the device signer.

## Next

- A debug-panel data adapter if design wants one (tell me the shape).
- Large blobs (over 4 MB encrypted) need presigned uploads; not done.

## Passkey facts, read from the website (7 Nov 2026)

- Relying party id: `promptugal.news` (the page uses `location.hostname`; source `https://promptugal.news/assets/vault/door.js`, `prfBytes`).
- PRF input (`prf.eval.first`): SHA-256 of `web-summit.newsroom.sgit.ai/door/v1` = `ab9b47d5…f39f5ade`. The site constant is `web-summit.newsroom.sgit.ai`, not the host name.
- The door test vectors come from my Python port of `door.js`, not from running the site's JavaScript (running downloaded code was blocked here). A check against the real site needs one run of `door.js` in a browser with the vectors' inputs.

## Blocked

- **No live write test.** Pushing to dev.send.sgraph.ai needs an access token (`sgit push`: "no access token configured"). Writes are tested against folders and sgit's in-memory server only. Live reads were checked only for the 404 shape (`{"detail":"Vault file not found"}`); I have no throwaway vault on the server to read, and I did not touch i9mbeqwb.

## Needs from others

- **Platform**: add `Packages/SGitVault` as a local package dependency of the app target, and fold `PrompTugal/Vault/` into the app. My interim `ios-vault.yml` can be deleted once your `ios.yml` is on `dev` (it runs the same `swift test`).
- **Platform**: entitlement `webcredentials:promptugal.news` (associated domains) for the passkey, `NSFaceIDUsageDescription` in Info, and `news.promptugal.reader.vault-refresh` in `BGTaskSchedulerPermittedIdentifiers` (call `VaultSession.shared.backgroundRefresh()` from it). On scene phase changes call `VaultSession.shared.sceneBecameActive()` / `sceneMovedToBackground()`.
- **Conductor / anyone with a token**: a vault access token (for a throwaway vault only) would let me test one live push.
- **Website (editor / promptugal.news owners)**: add the app to `https://promptugal.news/.well-known/apple-app-site-association` under `webcredentials.apps` (`<TeamID>.<bundle id>`). Without it iOS refuses the passkey request from the app. The PRF constant above must never change.
- **Design**: the Debug panel can read `VaultTrafficLog.events` and `.totals`, `SGitVault.inspect()` (a `VaultInspection`), and the key inventory from `VaultSession` (coming next).
