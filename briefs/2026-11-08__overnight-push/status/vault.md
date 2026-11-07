# Status · Swift vault

> The Swift sgit reader works and is tested on macOS CI: 29+ tests over throwaway vaults written by sgit 0.27, including tamper and wrong-key negatives. Next: the app's Keychain, Face ID and passkey unlock code.

Branch `night/vault`. Updated about 03:15 Lisbon time.

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

## In progress

- `PrompTugal/Vault/`: `VaultKeychain` (Face ID, `.biometryCurrentSet`, this device only), `VaultUnlock` (paste, QR text, passkey PRF behind a flag), `VaultSession`, Secure Enclave wrapping of the cached key, key inventory for the debug panel.

## Next

- Writes (stretch): commit builder in Swift, signed with a Secure Enclave key, checked by sgit on Linux.

## Passkey facts, read from the website (7 Nov 2026)

- Relying party id: `promptugal.news` (the page uses `location.hostname`; source `https://promptugal.news/assets/vault/door.js`, `prfBytes`).
- PRF input (`prf.eval.first`): SHA-256 of `web-summit.newsroom.sgit.ai/door/v1` = `ab9b47d5…f39f5ade`. The site constant is `web-summit.newsroom.sgit.ai`, not the host name.
- The door test vectors come from my Python port of `door.js`, not from running the site's JavaScript (running downloaded code was blocked here). A check against the real site needs one run of `door.js` in a browser with the vectors' inputs.

## Blocked

- Nothing.

## Needs from others

- **Platform**: add `Packages/SGitVault` as a local package dependency of the app target, and fold `PrompTugal/Vault/` into the app. My interim `ios-vault.yml` can be deleted once your `ios.yml` is on `dev` (it runs the same `swift test`).
- **Platform**: entitlement `webcredentials:promptugal.news` (associated domains) for the passkey, and `NSFaceIDUsageDescription` in Info.
- **Website (editor / promptugal.news owners)**: add the app to `https://promptugal.news/.well-known/apple-app-site-association` under `webcredentials.apps` (`<TeamID>.<bundle id>`). Without it iOS refuses the passkey request from the app. The PRF constant above must never change.
- **Design**: the Debug panel can read `VaultTrafficLog.events` and `.totals`, `SGitVault.inspect()` (a `VaultInspection`), and the key inventory from `VaultSession` (coming next).
