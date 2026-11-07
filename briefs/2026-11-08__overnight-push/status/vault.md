# Status · Swift vault

> Done for the night: a native Swift sgit vault client is on dev and green on iPhone and iPad. It reads and writes vaults, and sgit reads back what it writes. Face ID, Secure Enclave keys, passkey door, picks mirror and collab's append lanes run on it. Blocked: a live push (no access token) and passkey sign-in (the website's association file).

Branch `night/vault`. Wrap-up written about 07:40 Lisbon time. Last vault code: 3874921, merged into dev. Every job of ios.yml run 139 is green: app build, `swift test`, iPhone and iPad unit tests.

## Done

**`Packages/SGitVault`**: a Swift package (tools 6.0, iOS 18, macOS 15), Apple SDK only.
- **Read path, as sgit does it**: branch index → named branch → ref → commit → trees → blobs. Each object's id is checked against sha256 of its ciphertext (12 and 32 hex) before it is decrypted or cached. Both envelopes: AES-256-GCM, and `\0sgz1` deflate (Apple's raw deflate, with the zlib header and Adler-32 checked by hand). Commit signatures are checked with ECDSA P-256 against sgit's canonical signing bytes.
- **Cache and sync**: ciphertext only, cached on disk forever. Refs and the index are never cached. Pull is incremental: unchanged subtrees are not fetched or decrypted again.
- **Keys**: `sgit_private_read_…`, `sgit_public_read_…`, bare `<64 hex>:<id>`, and vault keys `sgit_private_vault_…` (PBKDF2, 600,000 rounds, read and write keys).
- **Writer**: `VaultCommitBuilder` makes sgit's blobs, trees, signed commits and refs. Rebuilding a commit's tree from its own files gives sgit's tree id byte for byte. `SGitVault.commit(…)` pushes through the batch API with compare-and-swap on the ref (or on the index for a new branch); a lost race overwrites nothing.
- **Round trip**: CI exports the vaults Swift wrote, and sgit-ai 0.27 on Linux clones them, switches branch, verifies every signature and compares every file. It is green (ios-vault.yml run 12).
- **Passkey door**: a port of promptugal.news `door.js`: PRF bytes or a recovery code → door vault → `master-key.json` → master → `reader.json` (and the access token when the master holds one).
- **Picks and lanes**: `VaultPicks.union` (union by id, the vault's entry kept, the website's member order; a malformed copy is refused, never overwritten) and `VaultLanes.fileName` (time-sorted, path-safe).
- **Traffic log**: each request, cache hit, hash check, key step, AES-GCM, inflate and JSON parse is logged on the object's path, with sizes and times. That fills every step of design's decrypt-pipeline panel. A test checks that no key, write key or passphrase ever appears in it.
- **Tests**: 46 package tests over throwaway fixtures written by sgit-ai itself (format 1 and format 2, deflate, two named branches, a passkey account). They include negative controls: wrong key, another passkey, a flipped byte in a blob, a commit and a ref, a forged re-hashed object, a damaged cache file, a pack vault, invalid key text, changed signed bytes, a lost push race, and malformed picks.

**`PrompTugal/Vault`** (in the app, built in CI):
- `VaultHomeView`: native on iPhone and iPad. It is a three-column split view (vaults, files, file) that stacks on iPhone. Team-key import comes first (paste, QR scan, `#key=` links), then one Face ID prompt opens stored keys. Passkey (behind a flag) and recovery code are also there.
- `VaultKeychain` (`.biometryCurrentSet`, this device only, 60-second Face ID reuse) and `VaultKeyWrap` (a Secure Enclave key wraps each stored key).
- `VaultDeviceSigner`: this device's commit key, in the Secure Enclave.
- `VaultSession`: the open vaults. It pulls on foreground and drops the Face ID reuse window in the background. It also offers the key inventory, inspector, `loadPicks`/`savePicks` (team), and `files(in:)`/`append(_:to:)` (collab).
- `VaultBackground`: `BGAppRefreshTask` `news.promptugal.reader.vault-refresh`, wired by platform.

## How a teammate opens a team vault

1. Open **Vault** in the app (sidebar on iPad, More on iPhone).
2. Paste the team key (`sgit_private_vault_<passphrase>:<vault id>`, or a read key `sgit_private_read_<64 hex>:<vault id>`), or tap **Scan** for a QR code, then **Import**. A vault key takes about a second: PBKDF2, 600,000 rounds, twice.
3. The vault pulls and opens on its files.
4. Next time, the vault screen asks for Face ID once and opens every stored key. There is no passkey prompt and no typing.

Keys stay in the Keychain on this device, behind Face ID, wrapped by the Secure Enclave where there is one. They are never shown, logged or synced. Writing (picks, team notes) needs the vault key plus an access token; a read key gives read access only. Debug → Vault traffic shows every step; the key inventory lists which keys exist and where, never their values.

## Passkey facts, read from the website (7 Nov 2026)

- Relying party id: `promptugal.news` (`rpId: location.hostname` in `https://promptugal.news/assets/vault/door.js`).
- PRF input (`prf.eval.first`): SHA-256 of `web-summit.newsroom.sgit.ai/door/v1` = `ab9b47d5…f39f5ade`. The site constant is `web-summit.newsroom.sgit.ai`, not the host name. It must never change.

## Not done, or not proven

- **Live push.** Pushing to dev.send.sgraph.ai needs an access token, and I had none. Writes are proven against folders and sgit's own in-memory server, and by sgit reading them back, but never against the live server. Live reads were checked only for the 404 shape.
- **Passkey sign-in on a device.** It is behind the `vault.passkeyPRF` flag (off). It needs the website change below. The door test vectors come from my Python port of `door.js`. Running the site's JavaScript was blocked here, so one browser run of `door.js` with the vectors' inputs would cross-check them.
- **Large files** (over 4 MB encrypted) need sgit's presigned uploads. They are refused with a clear error.
- **Pack vaults** (`packs` feature) are refused with a clear error.

## Needs from others

- **Website (promptugal.news)**: list the app under `webcredentials.apps` in `https://promptugal.news/.well-known/apple-app-site-association` (`<TeamID>.news.promptugal.reader`). Then the passkey flag can be turned on.
- **Anyone with a token**: an access token for a throwaway vault, to prove one live push.
