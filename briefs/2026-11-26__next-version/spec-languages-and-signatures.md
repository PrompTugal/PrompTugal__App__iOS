# Spec: article signatures and languages (c.ios.explore, 26 Nov 2026)

> Research and spec only, no app code. Read from the live site and the public source on 26 Nov 2026, about 03:00 UTC. Section 2 (signatures) was written first, for the article reader (c.ios.places). Section 1 (languages) follows.

## 2. Signatures: how PrompTugal.news signs articles

### In one paragraph

Each article `articles/<slug>.html` has a markdown twin `articles/<slug>.md` and a signature file `articles/<slug>.md.sig`. The signature is **ECDSA on P-256 with SHA-256**. It is stored as 64 raw bytes (r then s, the WebCrypto / IEEE P1363 form) in base64. It covers the **UTF-8 bytes of the twin after two lines are normalised**: the site version is replaced by `VERSION`, and the agent block's `built by:` line by `built by: BUILDER`. The public keys are in **`https://promptugal.news/board/keys.json`**: find the entry whose `bundle.signing_fingerprint` equals the `.sig`'s `fingerprint` and use its `bundle.sign` (a PEM SPKI public key). The fingerprint is `sha256:` plus the first 16 hex characters of SHA-256 over that key's DER SPKI bytes.

### Sources (primary)

- The form: `newsroom/build/signed-form.cjs` in the site's public repository (github.com/PrompTugal/PrompTugal__News__Website).
- The signer: `newsroom/tools/sign-article.mjs`. It signs through `pki-agent.mjs` from pki.sgit.ai.
- The site's own check: `newsroom/build/validate.js`, check 8. It runs `crypto.verify('sha256', signedForm, { key: bundle.sign, dsaEncoding: 'ieee-p1363' }, base64(signature))`.
- `how-we-publish/index.md` on the site describes the same check in prose.

### The `.sig` file

Served as `application/pgp-signature`, but it is JSON:

```json
{
  "signature": "Q7EuQwuMe8cY+twGyH71XOani+lq+4vDhTj3wRh9elKQosNndm9oN60RQ9l5aplhEHWEnvg8+Wesz8b3CS5dWA==",
  "fingerprint": "sha256:9bdecdbf857ccf8b",
  "form": "twin-without-version-or-builder/2"
}
```

### The key (`board/keys.json`)

`{"about": ..., "keys": [ ... 259 entries ... ]}`. The entry matching the example above:

- `id`: `reviewer-vicky-promptugal-3`
- `agent`: `reviewer@PrompTugal.vicky`
- `status`: `active`
- `bundle.sign`: PEM, `-----BEGIN PUBLIC KEY-----` … (EC P-256, OID 1.2.840.10045.3.1.7)
- `bundle.signing_fingerprint`: `sha256:9bdecdbf857ccf8b`
- `bundle.encrypt` is an RSA key for sealing messages. It is not used for signatures.

`status` can be `active` or `superseded`, or something else. The site accepts `active`. It accepts `superseded` only for a `.sig` committed unchanged before the key was handed over. It checks that by git ancestry, which the app cannot do.

### Exactly which bytes are signed (form `twin-without-version-or-builder/2`)

Start from the twin exactly as served (UTF-8, LF line endings; the source line contains U+00B7 `·`). Then:

1. In the first line matching `^(\*Source: <[^>\n]+> · site )v\d+\.\d+\.\d+( ·)` (multiline), replace the version with `VERSION`. The line `*Source: <https://promptugal.news/articles/x.html> · site v0.1.2293 · generated from …` becomes `… · site VERSION · generated from …`.
2. Replace the first line matching `^version: v\d+\.\d+\.\d+$` (multiline) with `version: VERSION`.
3. Replace the **last** line matching `^built by: .*$` (multiline) with `built by: BUILDER`. The site refuses a twin with more than one such line, so the app should treat more than one as "cannot verify".
4. Sign or verify the UTF-8 bytes of the result. Nothing else is trimmed: no trailing newline handling and no Unicode normalisation.

The other forms:

- **`twin-without-version/1`**: first replace the last `built by:` line with the legacy text `built by: newsroom@web-summit.dinis (a Claude Code session), operator Dinis Cruz`, then apply steps 1 and 2.
- **No `form`**: the oldest signatures covered the twin as it was built, with its version. They break at every release. The site itself only warns about them ("sign it again"), so the app should say "signed in an older form that cannot be checked", never "invalid".

### Worked example, verified 26 Nov 2026

Script: `briefs/2026-11-26__next-version/tools/verify_article.py` (Python 3, `cryptography`; it reads the live site).

```
$ python3 -I verify_article.py five-coding-agents-reverts-security-waits ai-use-in-portugal-2026 agent-setup-guide
five-coding-agents-reverts-security-waits: VALID (form twin-without-version-or-builder/2) by reviewer-vicky-promptugal-3 (reviewer@PrompTugal.vicky, status active), 6573 bytes signed, sha256 397ddaad6c59bd6b
ai-use-in-portugal-2026: VALID (form twin-without-version-or-builder/2) by reviewer-vicky-promptugal-3 (reviewer@PrompTugal.vicky, status active), 6379 bytes signed, sha256 2085602b1a146f76
agent-setup-guide: VALID (form twin-without-version-or-builder/2) by writer-angelo-promptugal (writer@PrompTugal.angelo, status active), 28927 bytes signed, sha256 692a13f733ff342e
```

In `five-coding-agents-reverts-security-waits.md` (6,681 bytes served, 6,573 bytes signed), three lines change:

- line 5, `· site v0.1.2293 ·` → `· site VERSION ·`
- line 67, `version: v0.1.2293` → `version: VERSION`
- line 68, `built by: the PrompTugal.news agents, each a Claude Code session (https://promptugal.news/newsroom/), operator Dinis Cruz` → `built by: BUILDER`

### All 102 live articles (`api/v1/articles.json`, 26 Nov ~03:00 UTC)

| Result | Count | Signers |
| --- | --- | --- |
| Valid, form 2 | 90 | reviewer@PrompTugal.vicky 57, journalist@PrompTugal.dinis 21, cl-6.conductor@PrompTugal.dinis 6, writer@PrompTugal.angelo 4, place.algarve@PrompTugal.dinis 2 |
| Valid, form 1 | 1 | `the-first-night-of-promptugal-news`, conductor@PrompTugal.dinis (key superseded) |
| No form (older signature, cannot be checked after a release) | 11 | conductor@ (superseded) 4, place.loule@ 3, place.alcoutim@, place.monchique@, place.portimao@, place.vila-real-de-santo-antonio@ |
| Unknown key or no `.sig` | 0 | |

### For the app (Swift, CryptoKit, no new dependency)

```swift
import CryptoKit
// keys.json entry → key; .sig → signature
let key = try P256.Signing.PublicKey(pemRepresentation: entry.bundle.sign)
let fp = "sha256:" + SHA256.hash(data: key.derRepresentation).prefix(8).map { String(format: "%02x", $0) }.joined()
guard fp == sig.fingerprint else { /* key and fingerprint disagree: refuse */ }
let signature = try P256.Signing.ECDSASignature(rawRepresentation: Data(base64Encoded: sig.signature)!)  // 64 bytes r||s
let ok = key.isValidSignature(signature, for: Data(signedForm(twin, form: sig.form).utf8))              // SHA-256 inside
```

- `signedForm` is the three replacements above. Use `NSRegularExpression` with `.anchorsMatchLines` and replace only the first match for steps 1 and 2 and the last match for step 3. Read the twin as `Data` and decode it as UTF-8 without altering it. Do not go through `String(contentsOf:)` with a guessed encoding.
- **States to show** (plain words, each with a link to the `.md`, the `.sig` and `board/keys.json`):
  - "Signed by reviewer@PrompTugal.vicky, checked on this device" (valid, active key)
  - "Signed with a key since handed over (conductor@…)" (valid, superseded key)
  - "Signed in an older form that cannot be checked" (no form)
  - "The signature does not match this text" (invalid)
  - "Not signed" (no `.sig`, 404)
  - "Could not check: offline" (no keys or twin)
- **Trust limit, to say on screen or in "How this was made"**: the key list comes from the same site as the article. A valid signature proves the text was signed by the key listed under that agent's name on promptugal.news. It does not prove who holds the key. Entries say how each key was made ("the push of this entry is the authorisation"; some note "not linked to an operator's key or confirmed on pki.sgit.ai").
- **Caching**: `board/keys.json` is 575 KB. Fetch it once per session (or keep this device's copy with its date) and look keys up by fingerprint. The twin and `.sig` are small.
- Withdrawn articles have no `.sig` in the deploy (`data/site/withdrawn.json`); treat them as "withdrawn", not "not signed", if the article record says so.

## 1. Languages

(Written next; see below.)
