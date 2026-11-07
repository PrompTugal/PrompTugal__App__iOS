# 04 · Vaults on the phone

> Yes, sgit vaults can run on iPhone and iPad, and natively: every primitive sgit uses (PBKDF2, HMAC, HKDF and AES-256-GCM, and ECDSA P-256 commit signatures) is built into iOS. Commit signing can even run inside the Secure Enclave. A passkey can open the same vault on the phone that it opens on promptugal.news.

## What we proved

We wrote a reader from the format rather than from sgit’s code, so that it could serve as a specification. It is [evidence/vault_read_probe.py](evidence/vault_read_probe.py), 60 lines using only HMAC-SHA256, HKDF-SHA256 and AES-256-GCM. Against this app’s own vault (`i9mbeqwb`) it:

- derived the branch index and ref file IDs, which matched the files sgit wrote;
- decrypted the branch index, the ref, the head commit (message: "Use website branding and correct Web Summit shortcut in 0.3.1") and the tree (19 files);
- decrypted `README.md`, which was **byte-identical** to the sgit checkout;
- did the same reading straight from `https://dev.send.sgraph.ai/api/vault/read/i9mbeqwb/bare/…`, with a plain `GET` and **no auth header**. The server only ever holds ciphertext.

So a phone needs `URLSession` and CryptoKit to read a vault. It needs no Python, no server change and no web view.

## How sgit maps to Apple’s frameworks

| sgit does | Parameters | On iOS | Notes |
| --- | --- | --- | --- |
| Vault key → read key | PBKDF2-HMAC-SHA256, 600,000 rounds, salt `sg-vault-v1:<vault_id>` | CommonCrypto `CCKeyDerivationPBKDF` | Only needed with a passphrase vault key. A read key skips it. A few hundred ms on a recent iPhone (estimate, to measure). |
| Vault key → write key | Same, salt `sg-vault-v1:write:<vault_id>` | CommonCrypto | |
| File IDs | HMAC-SHA256(read key, domain), first 12 hex | CryptoKit `HMAC<SHA256>` | |
| Structure key | HKDF-SHA256, info `sg-vault-v1:structure-key` | CryptoKit `HKDF<SHA256>` | iOS 14 and later |
| Objects | AES-256-GCM, iv 12 + ciphertext + tag 16 | CryptoKit `AES.GCM` | Hardware-accelerated |
| Compressed blobs | `\x00sgz1` + iv + GCM(zlib) | `Compression` (zlib) | Apple’s zlib is raw deflate: skip the 2-byte header and the 4-byte checksum |
| Commit signatures | ECDSA P-256, SHA-256 | CryptoKit `P256.Signing`, or `SecureEnclave.P256.Signing` | The key can be generated inside the Secure Enclave and never leaves it |
| Reading | `GET /api/vault/read/<vault_id>/<path>` | `URLSession` | No auth. Immutable `obj-cas-imm-*` objects can be cached forever. The ref must never be cached. |
| Writing | `PUT /api/vault/write/…` with `x-sgraph-vault-write-key` and an access token | `URLSession` | Access tokens are not issued to readers yet. They are fine for the team. |

## Can we run vaults locally? Four ways

| Option | How | Size | Works offline | Verdict |
| --- | --- | --- | --- | --- |
| **A. Native Swift vault client** | Reimplement the read path (proven above), then commit and push in Swift with CryptoKit | small, about 1,500–2,500 lines of Swift (estimate) | yes, objects cached on disk | **Recommended.** Fast, testable, works in widgets and background refresh, no review risk. |
| B. Bundle sgit-ai in CPython | Python 3.13+ supports iOS officially (PEP 730). Bundle `Python.xcframework` plus sgit-ai | tens of MB. `cryptography` needs an iOS build of its Rust and C parts (not confirmed to exist off the shelf) | yes | Not worth it. Big, slow to start, and hard to run from widgets or background tasks. |
| C. Run the JavaScript vault library in a hidden web view | The website’s sg-vault 0.2.3 with Web Crypto | small | yes | A good **bridge for writes in phase 2**: the same code as the web, so the two can’t disagree. Not usable from widgets or background tasks. |
| D. Vault apps in the app | Serve a vault app (`index.html` + `.vault/app.json`) from a custom scheme (`WKURLSchemeHandler`), with `window.sg` implemented natively | medium | yes | **Phase 3.** This is "running a vault locally" in the full sense. Watch App Review guideline 4.7.2: vault apps get vault data only, never device features. |

**Recommendation.** Build **A** for reading and background sync now. Use **C** for writes until the Swift writer passes the same tests as sgit (read what sgit writes, and have sgit read what we write). Then move writes to A, and offer **D** once the team has vault apps worth carrying.

## Unlocking: passkey, Face ID, or both

The website already opens its vault with a passkey: the WebAuthn PRF output derives a "door" vault, which holds the master vault key, which holds the reader vault keys. A recovery code is shown once. iOS 18 gives native apps the same PRF output (`ASAuthorizationPublicKeyCredentialPRFAssertionInput`). The same passkey with the same salt gives the same 32 bytes in Safari and in the app.

| Way in | Needs | Syncs to my iPad | Use it for |
| --- | --- | --- | --- |
| **Passkey with PRF** | iOS 18. `webcredentials:` associated domain on the passkey’s relying-party domain. The website’s exact salt ("path") | yes, through iCloud Keychain | First unlock on each device, and the **same vault as the website** |
| **Face ID over a Keychain key** | iOS 13. An item with `.biometryCurrentSet`, this device only | no (Apple does not sync biometry-protected items) | Every later unlock on that device, in under a second |
| Secure Enclave key | iOS 13. A P-256 key that never leaves the chip | no | Signing my branch, and wrapping the cached master key |
| Recovery code | nothing | n/a | A lost passkey |
| Team key link (`#key=`) | a universal link | no | Importing a team member’s `ws-keyring` or `pt-keyring` key once, into the Keychain |

**Proposed flow**

1. **First open on a device:** "Unlock with passkey". PRF → door vault → master vault key. The app generates a Secure Enclave key, uses it to wrap the master vault key, and stores the wrapped key in the Keychain behind Face ID. The PRF output is thrown away, as Apple requires.
2. **Every open after that:** Face ID unwraps the master key. No passkey prompt.
3. **Background sync:** reads need only read keys, so a widget or background task can refresh without Face ID if we choose. Writes always need an unlock.
4. **New device:** passkey again, because the passkey syncs and the Face ID item does not.
5. **Lost everything:** the recovery code, as on the web.

**Devices are branches.** sgit gives each writer its own branch with its own signing key. With a Secure Enclave key per device, each iPhone and iPad signs its own branch with a key that cannot be copied off it. Merging into the person’s main branch stays sgit’s normal job.

## What must be true first

- **Associated domain.** The passkey’s relying-party ID (the domain the website registers passkeys under) must list our app in `/.well-known/apple-app-site-association` (`webcredentials:<TeamID>.news.promptugal.reader`). That is a change to the website’s repo.
- **The salt is a contract.** The website’s PRF salt ("path") becomes a public constant shared by the web and the app. If either side changes it, existing vaults stop opening. It belongs in a shared spec with a test.
- **iOS 18 minimum, or a fallback.** PRF needs iOS 18. Either raise the minimum (iOS 17 users can update for free), or keep 17 and offer only "import recovery code" there.
- **Access tokens for writes.** Readers cannot write vaults until tokens are issued. The team can, today.
- **Format tests.** Keep a set of vaults written by sgit 0.27, and have the Swift client read every one in CI. Add any new sgit format (v2 32-hex object IDs, packs) as a fixture before the app claims support.
