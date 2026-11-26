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

### What the site translates (`https://promptugal.news/api/v1/i18n/`, read 26 Nov)

- **19 cultures** have files: ar, de-CH, de-DE, es-AR, es-ES, es-MX, fr-CA, fr-FR, hi-IN, hr-HR, it-IT, ja-JP, ko-KR, nl-NL, pl-PL, pt-BR, pt-PT, ro-RO, zh-Hans. en-GB is the source; en-US needs nothing. These are the same ids as the app's `AppCulture.all`, minus the two English ones.
- **What is translated is the place pages only.** `api/v1/i18n/<culture>/index.json` lists 35 pages per culture (Portugal and the 17 district capitals, the Algarve and its towns). Each has the translated page (`/pt-PT/algarve/faro/`) and its English original. The JSON API stays English (the site's own spec, `board/spec-translations.md` item 8).
- **Articles, the home page and the rest of the site are English only.** There is no translated article and no translated `api/v1/*` record.
- **The site's own words** (menus, labels, about 21 keys such as "Now", "News", "Back to English") are in `assets/i18n/site.json` for 21 cultures, with `machine: true` on the machine-made ones. The app has its own catalogues, so this file is only a reference.
- **The translation memory** is public and meant for the app (spec item 8: "readable at `data/i18n/tm/` for the iOS app, the same ids, so the app translates its own text from the same memory"):
  - Shards: `https://promptugal.news/data/i18n/tm/<culture>/<2 hex>.json` (256 per culture).
  - Each entry is `{ "<key>": { "t": translation, "by": "translator@PrompTugal.dinis", "model": "claude-sonnet-5-5", "at": "2026-11-16", "src": first 60 chars of the English, "ok": false|true } }`.
  - **The key** is the first 16 hex of SHA-256 over the normalised English. Normalised means Unicode NFC, CR/CRLF → LF, runs of space/tab/NBSP → one space, spaces around newlines removed, 3+ newlines → 2, trimmed (`board/team/translator/tools/tm.mjs`, `norm`).
  - Names in `data/i18n/glossary.json` (`never`) are kept untranslated.
- **How complete:**
  - The by-place prose (each `ai_news[].title` and `.summary`, `mandate`, `gravity`, `voice.*`) is complete. Checked live with `briefs/2026-11-26__next-version/tools/tm_lookup.py`: Faro pt-PT 61 of 61 strings, Monchique pt-PT 15 of 15, Algarve ja-JP 43 of 43.
  - The rest of the place pages (headings, tables, page copy) is not done: the pt-PT queue lists 2,990 of 3,886 segments missing.
  - **Review:** 913 pt-PT entries, all by translator@ with claude-sonnet-5-5; 40 marked `ok: true`, 873 `ok: false` (not checked by a second reader).

### What the app does today (dev v0.4.127)

- `PTCore/Culture/AppCulture.swift`: the default is always en-GB. The app does not follow the device. `start()` pins `AppleLanguages` to the current choice on every launch, so even the system's own strings follow it. A Bundle swizzle makes every catalogue read the chosen `.lproj`.
- The only way to choose was the language button. Dev removed it on 26 Nov (`2a58431`, `5cbf730`, "no language button"), so today the app is English for everyone. Info.plist still declares 21 localisations.
- Catalogue coverage (keys with a pt-PT translation / all keys):

| Where | Keys | pt-PT | Other languages |
| --- | --- | --- | --- |
| App (`Apps/PrompTugal` Localizable, InfoPlist, Intents, Widgets, AppShortcuts) | 214 | all | 16 to 21 languages |
| PTCore | 37 | all | 20 |
| PTNews | 68 | all | 20 |
| PTAgenda | 152 | all | 20 |
| PTWeb | 22 | all | 19 |
| PTExplore | 60 | all | 36 keys in 18 languages; the 24 new Explore keys are en + pt-PT |
| PTAsk, PTVaultUI | 111, 42 | all | en, pt-PT, one more |
| **PTPlaces** (Home, places, town pages) | 193 `String(localized:)` with no `bundle:` | **6** (they read the app's catalogue, which has 6 of them) | none |
| **PTLocal** (Algarve layers, provenance labels) | 81 `Text("…")` literals, no catalogue | 0 | none |
| PTTalk, PTDeck | about 26 literals | 0 | none |

### Proposal

**A. Follow the device language (PTCore change, one file plus its test).**

1. A saved choice (`app.culture` in UserDefaults) still wins, in case a picker returns.
2. With no saved choice, take the device's preferred languages and pick the closest of `AppCulture.all` with `Bundle.preferredLocalizations(from: all.map(\.id), forPreferences: preferred)`. Fall back to en-GB.
3. Pin `AppleLanguages` only for an explicit choice. When following the device, remove the app-domain `AppleLanguages` key. Builds up to now wrote `["en-GB"]` there on every launch, and that override would otherwise keep the device language out forever.
4. Because of that old pin, `Locale.preferredLanguages` in the first launch after the update can still say en-GB. Read the device list from the global domain:

```swift
// PTCore/Culture/AppCulture.swift (sketch)
public static func start(defaults: UserDefaults = .standard, device: [String]? = nil) {
    if let saved = defaults.string(forKey: storageKey), all.contains(where: { $0.id == saved }) {
        currentID = saved
        defaults.set([saved], forKey: "AppleLanguages")          // an explicit choice, as today
    } else {
        defaults.removeObject(forKey: "AppleLanguages")           // undo the old builds' pin
        let preferred = device ?? deviceLanguages()
        currentID = Bundle.preferredLocalizations(from: all.map(\.id), forPreferences: preferred).first
            .flatMap { id in all.first { $0.id == id }?.id } ?? english
    }
    LocalizedBundle.install()
}

/// The device's languages, not this app's override: the global domain, else Locale.preferredLanguages.
static func deviceLanguages() -> [String] {
    (CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication,
                            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]) ?? Locale.preferredLanguages
}

public static var followsDevice: Bool { UserDefaults.standard.string(forKey: storageKey) == nil }
```

`select(_:)` is unchanged (it saves and pins), plus a `followDevice()` that removes both keys. The test `defaultIsEnglish` becomes three tests, using the injected `device:`:

- `["pt-PT"]` gives pt-PT.
- `["pt-AO", "en"]` gives pt-PT. Check what `preferredLocalizations` actually returns for pt-AO: it may pick pt-BR. If so, add an explicit mapping for pt-* other than pt-BR to pt-PT, since the app is about Portugal.
- `["sw"]` gives en-GB.

The CFPreferences read needs a device check. If it returns nothing in the sandbox, the cost is one launch of English after the update.

**B. What would be Portuguese now, and what stays English.**

- **Portuguese with A alone:** the tab bar and shell (app catalogue), News (PTNews), the newsroom board and status screens (PTWeb), Explore's chrome, My program (PTAgenda), PTAsk, the vault screens, widgets and intents. Dates and numbers follow the locale everywhere, already (`AppCulture.locale`).
- **Still English:** the Home tab and every place screen (PTPlaces, 193 keys not in any catalogue), the Algarve layers and their provenance lines (PTLocal, 81 literals), the talk screens (PTTalk), and **all content**: article titles, summaries and bodies; company, place and library records; video titles.
- **So A alone gives a mixed Home screen** (Portuguese tabs over an English Home). Ship A together with:
  - **B1, PTPlaces catalogue:** move PTPlaces's `String(localized:)` to `bundle: .module` with its own `Resources/Localizable.xcstrings` (193 keys; en + pt-PT first, the other cultures later). Same for PTLocal's literals: `Text(String(localized: "…", bundle: .module))`, because a bare `Text("…")` in a package looks in the app's catalogue.
  - **B2, place prose from the memory (optional, after B1):** for a non-English culture, PTPlaces looks up each by-place string in the memory: key = `sha256(norm(text))[:16]`, shard = first 2 hex, cached per shard on the device. Where an entry exists, show it with a visible line: "Translated by an AI agent (translator@PrompTugal.dinis), not reviewed. Show the English", linking to the English and to the site's `/pt-PT/...` page. Where an entry has `ok: true`, say "checked". A missing entry stays in English. This is the same rule as the site ("a segment still missing stays in English").
  - **Articles stay English** and say so in the culture's language: "Os artigos estão em inglês", the site's own wording.
- **Hard rules this keeps:**
  - Every translated line says it is machine translation and by whom, with the English one tap away.
  - Provenance lines (live, this device's copy, built-in) are translated chrome, never translated data.
  - Glossary names are never translated.
  - No translation is made on the device.

**Order:** B1 (PTPlaces and PTLocal catalogues, en + pt-PT) → A (PTCore) → B2 (memory) → the other 17 cultures in the catalogues. A on its own before B1 is not recommended.
