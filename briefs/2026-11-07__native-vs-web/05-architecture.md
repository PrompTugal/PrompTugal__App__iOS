# 05 · Architecture

> Five layers: the websites in isolated web views, one typed bridge, a native core that owns identity, schedule, alerts and capture, a vault client that owns all private data, and system surfaces (widgets, Live Activities, Siri) fed from a shared App Group store.

## The layers

```
┌───────────────────────────── iPhone / iPad ─────────────────────────────┐
│  System surfaces   Widgets · Live Activity · Siri/Shortcuts · Spotlight │
│                    Notifications · Share extension · Control Center     │
│                         ▲ reads the App Group store only                │
│  Native core       Identity · Schedule · Alerts · Capture · Reader      │
│                         ▲                         ▲                     │
│  Bridge            pt.* messages (WKScriptMessageHandlerWithReply)      │
│                         ▲                         │                     │
│  Web views         promptugal.news · web-summit.sgit.ai · newsroom …    │
│                    one WKWebsiteDataStore per site, App-Bound Domains   │
│                                                   ▼                     │
│  Vault client      Swift: read, cache, sync, commit, push               │
│                    keys: Keychain + Secure Enclave, unlocked by passkey │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   ▼
          dev.send.sgraph.ai (ciphertext only)   ·   promptugal.news /api/v1 (public)
```

## The bridge

One message handler, `pt`, registered in its own `WKContentWorld` and only on App-Bound Domains. The page calls `await window.webkit.messageHandlers.pt.postMessage({op, …})` and gets a reply. The website detects the app with one injected flag (`window.ptApp = {version, ops}`) and falls back to its browser behaviour when the flag is missing, so the same page works in Safari and in the app.

| op | Direction | What it does | Who can call it |
| --- | --- | --- | --- |
| `schedule.get` / `schedule.set` | page → app | Read or replace picks, in the `nr.schedule.v1` shape | promptugal.news, web-summit.sgit.ai |
| `schedule.changed` | app → page | Fires the page’s existing `nr:schedule` event | the same |
| `notify.plan` | page → app | Ask for reminders for given picks. The app asks permission once | the same |
| `vault.status` / `vault.load` / `vault.save` / `vault.list` | page → app | The native implementation of the page’s `window.__vault`. Keys stay native | promptugal.news (later, vault apps) |
| `key.sign` | page → app | Sign bytes with my team key after Face ID. Returns the signature, never the key | web-summit.sgit.ai |
| `identity.get` | page → app | Who am I (team id, display name). No secrets | team sites |
| `capture.open` | page → app | Open the native scanner, recorder or camera, and return the saved item’s id | all |
| `share` | page → app | Native share sheet for a page or entity | all |

**Rules.** Every op checks the calling frame’s origin against an allow-list. Every op that touches a secret needs a fresh Face ID (`LAContext`, reuse window of 60 seconds or less). No op returns key material. The list is versioned, and both sides ignore unknown ops.

## Stores

| Store | Holds | Where | Synced by |
| --- | --- | --- | --- |
| Feed cache | agenda, events, news, wires | Application Support (today’s `content.json`) | the native reader’s refresh |
| Shared App Group store | next items, badge counts, the last sync time | App Group container (SQLite or JSON) | written by the core, read by widgets and intents |
| Vault object cache | encrypted `obj-cas-imm-*` objects | Caches, kept forever (objects never change) | the vault client |
| Vault working state | decrypted picks, stars, notes, contacts | memory, plus a protected file (`NSFileProtectionComplete`) | the vault client, on unlock |
| Keys | wrapped master key, team keys, device signing key | Keychain (`.biometryCurrentSet`, this device only), Secure Enclave | never synced. Recovery through the passkey |
| Web storage | each site’s own `localStorage`, IndexedDB and service worker | one `WKWebsiteDataStore` per site | not a source of truth. Rebuilt from the vault through the bridge |

## Sync

- **Pull.** Fetch the ref. If the commit is new, walk only the trees and objects not already cached (`-imm-` objects never change). Do this on open, on pull-to-refresh, and in `BGAppRefreshTask` (about 30 seconds, at times iOS chooses, never after a force quit).
- **Push.** The local change becomes a commit on this device’s branch, signed in the Secure Enclave, then pushed. A failed push stays queued and retries on the next open or background run.
- **Merge.** Picks merge by id (the union, with the latest `at` deciding a removal), the same rule the website uses. Other paths follow sgit’s merge. A conflict is shown, never silently resolved.
- **Feeds.** The public feeds are separate and need no unlock.

## Security model

| Threat | Defence |
| --- | --- |
| A page script tries to read keys | Keys never enter a web view. The bridge returns results, not keys. The bridge lives in its own content world and checks the frame origin. |
| One site reads another site’s data | A separate `WKWebsiteDataStore` per site. Origin checks on every bridge call. |
| A stolen, unlocked phone | Secrets need a fresh Face ID. The master key is wrapped by a Secure Enclave key that stops working when Face ID enrolment changes. |
| A lost phone | Nothing usable is on it without Face ID. The passkey and recovery code restore access on a new device. |
| The server is compromised | It has only ciphertext and opaque IDs. The client verifies object hashes (`obj-cas-imm-` = SHA-256 of the ciphertext) and commit signatures. |
| A bad website release | The app pins the bridge to known ops. The website cannot ask for anything new without an app update. |
| WebKit clears website storage | Web storage is a cache. The vault is the source of truth. |

## Targets

- **iOS 18 minimum** is recommended. It brings passkey PRF, broadcast Live Activities, Control Center controls and Spotlight `IndexedEntity`. Apple Intelligence features (Foundation Models, iOS 26, iPhone 15 Pro and later) stay optional.
- **Extensions:** a widget, a Live Activity, an App Intents extension and a share extension. All of them read the App Group store only, never the vault directly.
- **No third-party packages**, as today. Everything above is in Apple’s SDK.
