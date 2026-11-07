# Contracts for the overnight push

> The interfaces every session codes against, so six sessions can work in parallel without waiting on each other. Change one only through the conductor, and note it here.

## 1. Project layout (platform owns)

- **iOS 18.0 minimum**, Swift 6 language mode if the CI Xcode supports it, otherwise Swift 5 with strict concurrency warnings.
- The Xcode project moves to **folder-synchronized groups** (Xcode 16+, `PBXFileSystemSynchronizedRootGroup`). That way, **adding a Swift file to a folder needs no `project.pbxproj` edit**, and only the platform session edits the project file.
- Until the platform session says the layout is ready (in its status page), other sessions put code in **new files in their own folders** and keep going. The platform session folds those folders into the project.
- `Packages/SGitVault` is a **local Swift package** (`swift-tools-version: 6.0`, platforms iOS 18 and macOS 15) with its own tests, run with `swift test` on macOS CI. The app depends on it.
- Test targets: `PrompTugalTests` (unit, XCTest or Swift Testing) and `SGitVaultTests` (in the package).

## 2. CI (platform owns)

- `.github/workflows/ios.yml` runs on every push to `night/**` and `dev`, and on pull requests. Three jobs:
  - `swift test` for `Packages/SGitVault`;
  - `xcodebuild build` for the app (simulator, `CODE_SIGNING_ALLOWED=NO`);
  - `xcodebuild test` for the app’s unit tests on an iPhone simulator.
- Each failure must show the compiler error in the job summary, so a session can read it through the GitHub tools.

## 3. Schedule (team owns, everyone reads)

The wire format is the website’s, unchanged:

```json
{ "v": 1, "picks": [ { "id": "events/<slug>", "at": "2026-11-08T02:45:00.000Z" } ] }
```

- `id` is the event’s `page` path without `/index.html` (the website uses the event slug, so check its JavaScript and match it exactly). `at` is the time the pick was made, as an **ISO 8601 string** (the website writes `new Date().toISOString()` in `assets/schedule/schedule.js`). The app writes ISO 8601 and reads both ISO 8601 and Unix milliseconds.
- The website mirrors picks to the reader vault when it is open: `window.__vault` path `agenda/picks`, stored as **`apps/agenda/picks.json`** in the vault, merged as a union by `id`.
- Merge rule (the website’s): union by `id`. A removal wins only if it is later than the pick.
- The Swift API in `PrompTugal/Schedule/`:

```swift
@MainActor @Observable final class ScheduleStore {
    var picks: [SchedulePick]            // sorted by event start, Lisbon time
    func isPicked(_ id: String) -> Bool
    func toggle(_ id: String)
    func merge(_ incoming: ScheduleDocument)   // from the web view or the vault
    var document: ScheduleDocument { get }     // nr.schedule.v1
}
```

## 4. Bridge (team owns)

- Message handler name `pt`, in its own `WKContentWorld`, only for origins on the allow-list.
- The app injects `window.ptApp = { version, ops: [...] }` at document start.
- Phase-1 ops: `schedule.get`, `schedule.set`, `identity.get`, `notify.plan`, `meter.topup`.
- Until the website calls the bridge itself, the app syncs the schedule by **reading and writing `localStorage['nr.schedule.v1']` with `evaluateJavaScript` in the page’s world, and dispatching the `nr:schedule` event**. No website change is needed tonight.

## 5. Vault (vault owns, everyone reads)

```swift
public struct VaultAddress: Sendable { public let vaultId: String; public let server: URL }
public actor SGitVault {
    public init(address: VaultAddress, readKey: SymmetricKey, cache: URL, log: VaultTrafficLog)
    public func pull() async throws -> VaultCommit          // fetch the ref, walk new objects only
    public func files() async throws -> [VaultFile]         // path, size, blob id
    public func read(_ path: String) async throws -> Data
    public func history(limit: Int) async throws -> [VaultCommit]
}
@MainActor @Observable public final class VaultTrafficLog {  // feeds the debug panel
    public private(set) var events: [VaultTrafficEvent]     // newest first, capped at 2,000
}
public struct VaultTrafficEvent: Identifiable, Sendable {
    public let id: UUID; public let at: Date
    public let kind: Kind            // .request, .cacheHit, .decrypt, .verify, .keyDerivation, .error
    public let path: String          // e.g. "bare/refs/ref-pid-muw-…" — never a key
    public let bytes: Int; public let durationMs: Double; public let status: Int?
    public let detail: String        // e.g. "AES-256-GCM, read key, 547 B → 512 B"
}
```

- Server default: `https://dev.send.sgraph.ai`. Reads are `GET /api/vault/read/<vault_id>/<url-encoded path>` with no auth.
- The format spec is `briefs/2026-11-07__native-vs-web/evidence/vault_read_probe.py`.
- **Keys never appear in logs, the debug panel, analytics or git.**
- App glue in `PrompTugal/Vault/`: `VaultKeychain` (keys behind Face ID with `.biometryCurrentSet`, this device only), `VaultUnlock` (read-key import from a pasted `sgit_private_read_…:<vault_id>` or a QR code, then passkey PRF when the domain is ready), `VaultSession` (the open vaults, as an `@Observable` the UI uses).

## 6. Team data (team owns the models, design owns the screens)

Public JSON, read without keys and cached for offline use:

| Source | URL | Used for |
| --- | --- | --- |
| Team people and counts | `https://web-summit.sgit.ai/me.json` | badge, "only you", decide, overdue |
| Command centre | `https://web-summit.sgit.ai/people/<id>/app/data.json` | tasks, decisions, named-for-me, today |
| Meetings | `https://web-summit.sgit.ai/meetings/…` (check `llms.txt`) | stand-ups and briefings |
| Agents | `https://web-summit.sgit.ai/wakes/`, `/reports/`, `/pulse/`, `/log/` (find their JSON via `llms.txt`) | what the agents are doing |
| Newsroom | `https://promptugal.news/api/v1/newsroom/{desks,stories,dashboard,decisions,status}.json` | newsroom status |
| News | `/feed.xml`, `/api/v1/newsletter.json`, `/api/v1/story.json`, `/api/v1/search/docs.json` | the news in every form |
| Agenda | `/api/v1/live/agenda.json`, `/api/v1/place.json` | schedule and planning |

These are data sources only. Product copy says PrompTugal.

## 7. Shell (design owns)

- `PrompTugal/Shell/AppShell.swift` is the root view. On iPad it is a `NavigationSplitView` sidebar. On iPhone it is tabs plus a "More" list.
- Each feature exposes **one entry view** and registers it in `Shell/Destinations.swift` (design merges these registrations):

```swift
struct Destination: Identifiable { let id: String; let title: String; let symbol: String
    let section: Section; let kind: Kind /* .native, .web(URL), .hybrid */; let view: () -> AnyView }
```

- Every screen gets a small "native / web / hybrid" badge in debug mode, so we learn the balance.

## 8. Debug mode (design owns the UI, everyone feeds it)

- Settings → Debug (or a triple tap on the version) turns on debug mode.
- Panels: **Vault traffic** (`VaultTrafficLog`), **Network** (every `URLSession` request the app makes, through one shared `HTTPClient` with a log, owned by platform in `PrompTugal/App/HTTPClient.swift`), **Bridge** (every bridge message), **Storage** (files, sizes, cache ages), **Keys** (which keys exist and where, never values), **Build** (app version, build, git commit, site release).

## 9. Secrets

- OpenRouter key: entered by the user, stored in the Keychain (`.biometryCurrentSet` optional), optionally saved to the user’s vault under `apps/ai/openrouter.json` once vault writes exist. Sent only to `openrouter.ai`.
- No key of any kind in git, logs, fixtures, screenshots or status pages.

## Changes

- **03:15 UTC, §3 Schedule:** a pick’s `at` is an ISO 8601 string, not Unix milliseconds (checked against the website’s `assets/schedule/schedule.js`). The app writes ISO and reads both. Added the vault mirror path `apps/agenda/picks.json`. Requested by the conductor.
