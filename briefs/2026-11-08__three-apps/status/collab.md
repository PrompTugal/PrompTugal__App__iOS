# Collab status: PTAsk and PTLanes

> CollabSeams, PTLanes and VaultCollabAccess are on dev. PTAsk is moved on split/collab (AskContextProvider, PublicAskProvider in PTAsk, TeamAskProvider in Coordination/): quick run 329 green on f3b0a1c, full run queued. Needs from others: the Team entry point must call TeamLanesWiring.install() once at launch; the public app must set AgendaHub.schedule.

**Branch:** `split/collab` (from `origin/dev` 45284d0) · **Last CI run:** PTAsk move: quick run 329 (f3b0a1c) green; full run on f3b0a1c queued (macos-26) · **Updated:** 10:30 UTC (collab.B; PTSync design added at the end)

## Rulings from the conductor (7 Nov, 23:47 UTC)
1. `CollabSeams.swift` goes in PTCore, one file, owned by collab: protocols, value types and the formatter only. `CollabVaultAccess` there uses plain types. `VaultCollabAccess` lives in PTVaultUI (agreed with vault through the conductor). Add the file only after platform's phase 2 is on dev.
2. `AskContextProvider`, `PublicAskProvider`, `TeamAskProvider` approved. Consent and context switches behave as today in the Team app.
3. The 4 team AITests may move to the Team test target.
4. Order: PTLanes once PTVaultUI is on dev; PTAsk last, after PTAgenda, PTNews and PTVaultUI. The conductor pings at each step.

## Design's map (7 Nov, 23:48 UTC)
Two `TeamFeatures.shared` uses must be covered: `AIContext.swift:320` (`teamData`, now `TeamAskProvider.part(for:)`) and `AskView.swift:196` (`AskMentions` schedule, now `isPicked` / `togglePick` on the provider). Added to the protocol above.

## Correction (7 Nov, 23:48 UTC)
PublicAskProvider uses `ScheduleStore` for `myPickIds`, `isPicked` and `togglePick`, not the reader's old saved sessions. Both providers share the same pick list. They differ only in the team parts.

## Done
- Read the three-apps README, contracts and the overnight rules.
- Mapped what `AI/` (9 files) and `Lanes/` (9 files) use from outside. About 4,000 lines.
- Designed the provider split (below).

## In progress
- Merged origin/dev (PTVaultUI e5328ff) at 00:41 UTC.
- `CollabSeams.swift` written for PTCore (committed locally, not pushed: PTCore phase 2 is not on dev yet). It holds `CollabVaultAccess`, `CollabHooks` (vault nil by default, `me`, `currentPage`, `HookError`), `PageContext`, `CollabIdentity`, `CollabErrorText`, `collabJS`. Protocol text sent to the conductor for vault.
- PTLanes move prepared locally, not pushed: 9 files `git mv`'d, `import PTCore`, `public` only where outside code needs it (`LanesView`, `LaneEventRow`, `LaneEvent`, `LanesLog`, `LanesStore.shared/log/laneCount/hasEnumKey`, `LaneIdentity.exists`), `LanesEnvironment.linkedVaults` replaces `CoordinationStore` in team notes, `LanesTests` moved to the package. Team side: `TeamLanesWiring.install()` (Coordination/), called from `CoordinationStore.shared`.
- Risk: `LanesView` uses `DebugMode` (Debug/). If it is not in PTCore after phase 2, I need it moved or injected.

## Next
0. Push the prepared commits when the conductor says PTCore is on dev; read CI and fix. Original `Coordination/CollabHooks.swift` and `CollabErrorText.swift` lose the moved parts then (Team keeps agenda/myPickIds/dayPlan as a `CollabHooks` extension).
1. When PTCore, PTAgenda, PTNews, PTVaultUI are on dev: merge `origin/dev`, then step 1 to 5 below.

## Blocked / needs from others
- **Conductor / platform:** a ruling on where the shared "collab seams" live (see Q1). Recommendation: PTCore.
- **vault:** `VaultSession` public API in PTVaultUI, enough for `VaultCollabAccess` (readFile, update, importKey, savePicks, files, append, vaults, readerVaultId, isLocked).
- **team:** `ScheduleStore` and `PlannerStore` public in PTAgenda; `FeedClient` and `Event` public in PTNews/PTAgenda; `TeamFeatures` stays in the Team app.
- **design:** `Destinations.swift`, `DebugHomeView`, `SystemPanels` reference `AskView`, `LanesView`, `CollabDebugPanel`; they need `import PTAsk` / `import PTLanes` (Exports.swift gives that for free) and the types to be `public`. `WebPage.swift` calls `CollabHooks.noteCurrentPage`, so that call must stay reachable from PTWeb's owner (see Q1).

## 1. What AI/ and Lanes/ use from outside

| Used | By | Where it goes |
| --- | --- | --- |
| `HTTPClient`, `HTTPLog`, `Lisbon`, `Design` | AI, Lanes | PTCore (already allowed) |
| `Event`, `FeedClient`, `PickId`, `ScheduleStore` (AskMentions) | AI | PTNews / PTAgenda |
| `VaultSession` via `VaultCollabAccess` (`CollabVaultGlue.swift`) | AI key copy, Lanes, team notes | PTVaultUI (glue), protocol lower (Q1) |
| `CollabHooks` (vault, agenda, myPickIds, me, dayPlan, currentPage) | AI, Lanes | split: see below |
| `CollabErrorText`, `CollabIdentity`, `PageContext`, `ISO8601DateFormatter.collabJS`, `HookError` | AI, Lanes | Q1 |
| `TeamFeatures.shared` (`.team`, `.schedule`, `.planner`) | AIContext, AskView, CollabHooks defaults | **Team app only.** Replaced by a provider |
| `TeamPerson`, `CommandCentre` (Team models) | `AIContextAssembler.teamPart/agentsPart` | Team app, with the provider |
| `CoordinationStore.shared` | AIContext (teammates), AITools (`where_is_everyone`), Lanes `TeamNotes` | **Team app only.** Provider / injected closure |
| `CollabTeamGlue.planText` (`DayPlanner.Plan`) | `CollabHooks.dayPlan` default | Team app (provider) |

Used by the app from outside: `Destinations.swift` (AskView, LanesView, TeamPlansView), `DebugHomeView` and `SystemPanels` (CollabDebugPanel), `WebPage.swift` (`noteCurrentPage`). Tests: `AITests`, `LanesTests`, `CoordinationTests`, plus `DesignReviewTests` (references).

## 2. Provider split

Principle: PTAsk and PTLanes never name `TeamFeatures`, `CoordinationStore`, `TeamPerson` or `CommandCentre`. Each app supplies a provider at launch.

**PTAsk**
```swift
@MainActor public protocol AskContextProvider: AnyObject {
    /// The kinds this app offers. Public app: [.agenda, .picks, .page]. Team app: all seven.
    var supportedKinds: Set<AIContextKind> { get }
    var personName: String? { get }                       // used in the system prompt; nil in the public app
    func agenda() async -> [Event]
    func myPickIds() -> [String]
    func isPicked(_ event: Event) -> Bool                 // AskMentions (AskView.swift:196) used TeamFeatures.shared.schedule
    func togglePick(_ event: Event)                       // both providers use ScheduleStore (PTAgenda), one pick list synced with promptugal.news
    func part(for kind: AIContextKind, now: Date) async -> AIContextPart?   // .team .agents .teammates .plan; public app returns nil
    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)?  // team_status, my_agents, where_is_everyone
    var extraStarters: [AIStarter] { get }                // "My agents" only in Team
}
public enum AskEnvironment { @MainActor public static var provider: any AskContextProvider = PublicAskProvider() }
```
- `PublicAskProvider` (in PTAsk): agenda from the reader cache then `FeedClient`, picks through `ScheduleStore` (PTAgenda, the one synced schedule), no team, no person name. It is the default, so the public app works with no wiring.
- `AIContextKind` enum is unchanged (move, don't rewrite). The consent sheet, toggles, tool list and gatherer filter by `supportedKinds`. A kind the app does not support is not shown, not gathered, and its tools are not offered.
- `AITools.definitions(for:)` keeps the 6 definitions; `team_status`, `my_agents`, `where_is_everyone` are dropped when their kind is unsupported (same filter that exists today).
- Consent flow, `AIKeyStore`, OpenRouter client and the Keychain code move untouched. Consent tests stay as they are.
- The "copy key to vault" action keeps using `CollabHooks.vault` (PTVaultUI is in both apps).

**Team app** (stays in `Coordination/`, later `Apps/Team/`)
- `TeamAskProvider: AskContextProvider` reads `TeamFeatures.shared` (schedule, planner, team), `CoordinationStore.shared` and `CollabTeamGlue`. It carries the code that now sits in `AIContextGatherer.teamPart/agentsPart/teamData` and the `.teammates` / `.plan` branches.
- `AIContextAssembler.teamPart/agentsPart` (pure text builders over `TeamPerson` / `CommandCentre`) move to the Team app with the provider. The 4 tests that call them (AITests lines ~181–211) move to the Team test target. All other AITests stay with PTAsk.
- Installed once at launch: `AskEnvironment.provider = TeamAskProvider()`. The Team app keeps every current feature.

**PTLanes**
- Depends only on PTCore and PTVaultUI. It uses the vault (`CollabHooks.vault`), `me`, `currentPage` and `CollabErrorText`, which are not team-specific (Q1).
- The one team link is `TeamNotesStore.load(coordination: CoordinationStore)`, which reads `linkedVaults`. Replace the argument with `linkedVaults: @MainActor () -> [String: String]` set by the Team app (`LanesEnvironment.linkedVaults`). Default: empty.
- PTLanes is only in the Team app, so it needs no public-app variant.

**Debug:** `CollabDebugPanel` mixes `AIKeyStore` and `LanesStore`, so it cannot live in either package. It stays in the Team app (with `CollabDebugPanel.keyRows` used by `SystemPanels`). Both stores need `public` on the members it reads.

## 3. Open questions for the conductor
- **Q1. Where do the shared seams live?** `AI/` and `Lanes/` both need `CollabHooks` (vault, me, currentPage), `CollabVaultAccess`, `HookError`, `CollabIdentity`, `PageContext`, `CollabErrorText` and the `collabJS` date formatter. PTAsk cannot depend on PTLanes and the reverse, so they go below both. All are pure Foundation. **Recommendation:** one new file `CollabSeams.swift` in PTCore (collab adds it, platform's files untouched), with `VaultCollabAccess` (needs `VaultSession`) in PTVaultUI, and `CollabHooks.vault` defaulting to nil in PTCore, set by PTVaultUI's owner (or the app) at launch. `PickId` goes with `ScheduleStore` in PTAgenda (team). `WebPage.swift` (PTWeb) calls `noteCurrentPage`, which is then in PTCore, so no upward edge.
- **Q2.** OK to add that one file to PTCore, or should platform do it?

## 4. Steps when the dependencies are on dev
1. Merge `origin/dev`. Add `CollabSeams.swift` (Q1) and `VaultCollabAccess`.
2. `git mv` `Lanes/*` (minus nothing; all 9 files) to `Packages/PTLanes/Sources/PTLanes/`, `public`, `import PTCore`/`PTVaultUI`. Inject `linkedVaults`. Move `LanesTests.swift` to `Packages/PTLanes/Tests/`. Push, read CI.
3. Add `AskContextProvider`, `PublicAskProvider`; `git mv` `AI/*` (minus `CollabDebugPanel.swift`) to `Packages/PTAsk/Sources/PTAsk/`. Add `TeamAskProvider` in `Coordination/`. Move `AITests` (except the 4 team-part tests) to `Packages/PTAsk/Tests/`. Push, read CI.
4. Check consent, own-vault and lanes tests are all still present and green. Report to `@parent` with branch, commit and run number.


## Handoff (8 Nov, about 01:45 UTC, to conductor.B / account B)

Collab session stopped on the conductor's handoff. No scheduled tasks of mine remain and I dispatch no more CI.

### Heads and last runs
| Branch | Head | Last run |
| --- | --- | --- |
| `split/collab-seams` | 11acc2e (from dev 116a350 era, only adds `Packages/PTCore/Sources/PTCore/CollabSeams.swift`) | ios.yml run 291 (id 42433846852), dispatched 01:20 UTC, **still queued at 01:42 UTC, no result** |
| `split/collab` | a32e67a (last merge of origin/dev, 00:45 UTC; contains the prepared PTLanes move and the Coordination edits) | none. It cannot compile until `CollabSeams.swift` is on dev. Red is expected. |

### Agreed order
1. `CollabSeams.swift` (branch `split/collab-seams`): read run 291 and merge commit 11acc2e if green.
2. Vault's `VaultCollabAccess` and `VaultCollabAccess.install()` in PTVaultUI (vault holds it locally until step 1 is on dev).
3. PTLanes (`split/collab`): merge origin/dev, then `TeamLanesWiring.install()` should call `VaultCollabAccess.install()` instead of setting `CollabHooks.vault` itself. Add `swiftLanguageModes: [.v5]` to `Packages/PTLanes/Package.swift` (team's moved packages use it). Dispatch ios.yml on `split/collab`, fix until green.
4. PTAsk last, after PTAgenda, PTNews and PTVaultUI are on dev.

### What `split/collab` already holds (prepared, uncompiled)
- 9 `Lanes/` files `git mv`'d to `Packages/PTLanes/Sources/PTLanes/`, `import PTCore` added, `public` only where outside code needs it (`LanesView`+init, `LaneEventRow`+init, `LaneEvent`, `LanesLog`, `LanesStore.shared/log/laneCount/hasEnumKey`, `LaneIdentity.exists`).
- `LanesEnvironment.linkedVaults` (new, PTLanes) replaces `CoordinationStore` in `TeamNotesStore.load`.
- `LanesTests.swift` moved to `Packages/PTLanes/Tests/PTLanesTests/` (`@testable import PTLanes`, `import PTCore`). The placeholder test and file were removed.
- Team side: `Coordination/CollabHooks.swift` keeps only team hooks (`myPickIds`, `agenda`, `dayPlan` as an extension of PTCore's `CollabHooks`), plus `ReaderFiles` and `PickId`. `Coordination/CollabErrorText.swift` removed (now in PTCore). New `Coordination/TeamLanesWiring.swift`, called from `CoordinationStore.shared`'s initialiser as a stopgap until the Team app entry point (phase 4) calls `TeamLanesWiring.install()` once at launch.
- `AI/CollabDebugPanel.swift` uses `lanes.laneCount`. It stays in the Team app.
- `LanesView` uses `DebugMode` (now in PTCore).
- Note: `CollabSeams.swift` also sits on `split/collab` (commit d369089), so after `split/collab-seams` is on dev, merging origin/dev into `split/collab` will show it as the same file. Expect an add/add conflict if the content differs; take dev's.

### The exact `CollabVaultAccess` protocol (PTCore, public, plain types)
```swift
/// The vault, as collaboration features need it. Plain types only.
@MainActor
public protocol CollabVaultAccess: AnyObject {
    /// A vault is open on this device.
    var isOpen: Bool { get }
    /// My own vault (the account's reader vault), never a vault imported from someone else's key. Nil when
    /// none is open. Everything "mine" (my key copy, my plan, my notes) reads and writes only this vault (S5).
    var ownVaultId: String? { get }
    /// My own vault was opened with a vault key (not a read key), so it can be written.
    var canWrite: Bool { get }
    /// A file of my own vault, or nil when there is no such file. Throws when my own vault is not open.
    func read(_ path: String) async throws -> Data?
    /// Write one file to my own vault (read-modify-write on the branch the website reads).
    func write(_ path: String, _ data: Data, _ message: String) async throws
    /// Open a teammate's vault with the read key they shared (`sgit_private_read_…:<vault_id>` or a `#key=` link).
    /// Stored behind Face ID like any key. Returns the vault id.
    func openShared(readKey: String, label: String) async throws -> String
    /// A file of another open vault.
    func read(_ path: String, vaultId: String) async throws -> Data?
    /// My picks merged into the vault's copy (`apps/agenda/picks.json`, nr.schedule.v1). Returns the merged document.
    func savePicks(_ document: Data) async throws -> Data
    /// Commit one note file to my newsroom notes lane: the vault of my own whose read key the newsroom holds
    /// (newsroom.sgit.ai "the feedback loop"; its vault key is in my master vault's `lane.json`).
    func writeNewsroomNote(_ path: String, _ data: Data) async throws
    /// Paths of the files under `folder` in a vault (mine when `vaultId` is nil).
    func files(in folder: String, vaultId: String?) async throws -> [String]
    /// A new file in `folder` of my vault, never overwriting (vault session's `append`). Returns its path.
    func append(_ data: Data, to folder: String, message: String) async throws -> String
    /// A file of my master vault (e.g. `inbox.json`, the inbox record the website made), or nil.
```
`CollabHooks` (PTCore): `HookError` (noVault, noWritableVault, noNotesLane, noOwnVault), `vault` (nil by default; the app installs `VaultCollabAccess`), `me`, `currentPage`, `noteCurrentPage`, `clearCurrentPage`. Also in PTCore: `PageContext`, `CollabIdentity`, `CollabErrorText`, `ISO8601DateFormatter.collabJS`. Team says PTWeb's `WebBridgeHub` now carries `noteCurrentPage`.

### AskContextProvider design (PTAsk, approved by the conductor; not started)
```swift
@MainActor public protocol AskContextProvider: AnyObject {
    var supportedKinds: Set<AIContextKind> { get }   // public app: [.agenda, .picks, .page]; Team: all seven
    var personName: String? { get }                  // nil in the public app
    func agenda() async -> [Event]
    func myPickIds() -> [String]
    func isPicked(_ event: Event) -> Bool              // AskMentions (AskView.swift:196)
    func togglePick(_ event: Event)                    // both providers use ScheduleStore (PTAgenda)
    func part(for kind: AIContextKind, now: Date) async -> AIContextPart?  // .team .agents .teammates .plan; nil in public
    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)?  // team_status, my_agents, where_is_everyone
    var extraStarters: [AIStarter] { get }           // "My agents" only in Team
}
public enum AskEnvironment { @MainActor public static var provider: any AskContextProvider = PublicAskProvider() }
```
- `AIContextKind` enum is unchanged. The consent sheet, toggles, gatherer and `AITools.definitions(for:)` filter by `supportedKinds`. Consent behaves exactly as today in the Team app.
- `PublicAskProvider` (in PTAsk): agenda from the reader cache then `FeedClient`, picks through `ScheduleStore`, no team.
- `TeamAskProvider` (in `Coordination/`): carries `AIContextGatherer.teamPart/agentsPart/teamData` and the `.teammates` / `.plan` branches (uses `TeamFeatures.shared`, `CoordinationStore.shared`, `CollabTeamGlue`). `AIContextAssembler.teamPart/agentsPart` and the 4 AITests that call them (AITests lines ~181–211) move to the Team app. All other AITests, including consent and own-vault, move to `Packages/PTAsk/Tests/`.
- `AIKeyStore`'s vault copy keeps using `CollabHooks.vault`. `CollabDebugPanel` stays in the Team app. `AI/` goes to `Packages/PTAsk/Sources/PTAsk/` with `git mv`, `import PTCore/PTAgenda/PTNews/PTVaultUI`, `swiftLanguageModes: [.v5]`.

### Next steps
1. Read run 291. Report commit 11acc2e and the run number to the conductor.
2. After vault's file and `CollabSeams.swift` are on dev: PTLanes as above, then PTAsk.
3. `python3 scripts/apps/check_apps.py` before any push to dev (conductor only pushes to dev).

## PTSync design (proposal for the next round, no code yet)

Source: `briefs/2026-11-08__app-first-platform/README.md` ("Offline: download, verify, render locally") and WS-199 (the team site's manifest, same shape as promptugal.news `api/v1/manifest.json`: `{version, count, files:[{path, bytes, sha256, feature}]}`). Written 10:30 UTC for conductor.B. It waits on Dinis's answers.

### Where it sits
- `Packages/PTSync` depends on **PTCore only** (HTTPClient and its log, Lisbon time). Apple SDK only: CryptoKit (SHA-256), Network (`NWPathMonitor`), BackgroundTasks, FileManager. No upward edge.
- Readers do not import PTSync. PTCore gets one seam file, like `CollabSeams.swift`: `ContentSource` (`func data(at path: String) -> Data?`, `var generation: Int`) and `ContentSources.register(_:for:)`. `FeedClient`, `ReaderStore` and Ask's agenda read local data first through it, then fall back to the network as today. That keeps PTAgenda, PTNews and PTAsk free of a new edge. (Alternative: PTAgenda and PTNews depend on PTSync directly. Simpler, one more edge each. Conductor decides.)
- PTLanes depends on PTSync for the outbox types (PTLanes → PTCore, PTVaultUI, PTSync). `apps.json`: PTSync is listed by the app entry points (team, promptugal, riskmandate) and PTLanes; `check_apps.py` computes the closure, so platform edits `apps.json` and the projects.

### Package API (all `public`)
```swift
public struct SyncSource: Sendable { id: String; base: URL; manifestPath = "api/v1/manifest.json"; allowedHosts: Set<String> }
public struct Manifest: Decodable, Sendable { version: String; files: [ManifestEntry] }       // unknown fields ignored
public struct ManifestEntry: Decodable, Sendable { path: String; bytes: Int; sha256: String; feature: String? }
public enum SyncPack: String, Sendable { case core, full, media }
public struct PackRules: Sendable { func pack(for: ManifestEntry) -> SyncPack }              // by `feature` and path prefix; each app passes its own
public final class ContentStore: ContentSource, Sendable {                                   // one per source
    init(source: SyncSource, seed: URL?, directory: URL)                                     // first launch installs the seed as generation 0
    func data(at path: String) -> Data?; var manifest: Manifest?; var syncedAt: Date?; var generation: Int
    func snapshot() -> ContentSnapshot                                                       // a screen holds one snapshot, so a switch never mixes generations
}
public actor SyncEngine {
    init(store: ContentStore, rules: PackRules, http: HTTPClient = .shared)
    func sync(_ packs: Set<SyncPack>, wifiOnly: Set<SyncPack> = [.full, .media]) async throws -> SyncReport   // added, changed, removed, bytes, failures
    var status: AsyncStream<SyncStatus> { get }                                              // idle, fetching manifest, n of m files, switched, failed(reason)
}
public actor Outbox {                                                                        // writes queued offline
    init(directory: URL, sender: any OutboxSender, path: NetworkPath)
    func enqueue(_ item: OutboxItem) async                                                   // kind, payload Data, idempotencyKey; persisted
    func flush() async                                                                       // in order, backoff 2s ... 10 min, stops on no network
    var pending: [OutboxItem] { get }
}
public protocol OutboxSender: Sendable { func send(_ item: OutboxItem) async throws }       // Lanes, notes to the newsroom, picks supply their own
public enum SyncBackground { static func register(taskIdentifier: String, run: @escaping @Sendable () async -> Void); static func schedule() }  // id from the entry point, as VaultBackground
```

### How a sync works
1. GET the manifest (`If-None-Match` with the stored ETag; 304 means nothing to do). Diff against the current generation's manifest: unchanged (same sha256), changed, added, removed.
2. Select by pack: `core` always, `full` on Wi-Fi or by choice, `media` opt-in. `NWPathMonitor` (`isExpensive`, `isConstrained`) gates the big packs.
3. Stage in `gen-N.tmp/`: clone the unchanged files from the current generation (APFS clone, no copy cost), download the changed ones (6 at a time, `HTTPClient`, so Debug → Network shows them). Each file must match the manifest's `bytes` and `sha256`; a mismatch is fetched once more, then reported and left out of the switch.
4. If every wanted file verified: rename `gen-N.tmp` to `gen-N`, then replace the small `CURRENT` pointer file atomically (`replaceItemAt`). Keep two generations, delete the rest. A killed or half-done sync never shows.
5. Safety: HTTPS only, host must be in `allowedHosts`, paths with `..`, a leading `/` or a scheme are refused, a download larger than its manifest `bytes` is cut off, nothing is executed. Public data only; private data stays in vaults.
- **Build seed:** a CI step before `xcodebuild` downloads the manifest and the `core` pack (PrompTugal also `full`, about 20 MB) into `Apps/<App>/Seed/<source>/`, added as a folder resource. The seed carries its manifest, so the first sync downloads only what changed since the build. A Linux check verifies the seed's hashes. The apps work in airplane mode from the first launch.

### What each app calls
| App | Sources | Calls |
| --- | --- | --- |
| PrompTugal | promptugal.news | At launch: `ContentStore` + `SyncEngine`, register with `ContentSources`, `SyncBackground.register(task id)`. Pull-to-refresh: `sync([.core])`. Settings "Download everything": `sync([.core, .full])`, a media toggle. Shows "synced N min ago". |
| Team | promptugal.news and web-summit.sgit.ai (needs WS-199) | Same, two stores. `Outbox` is also wired for Lanes messages, newsroom notes, picks and check-ins. |
| RiskMandate | riskmandate.ai | Seed only until the site has a manifest; then the same calls. |

### Test plan
- **Package tests (`swift test`, no app host, `URLProtocol` stub):** manifest decoding (unknown fields, empty, huge); diff (added, changed, removed, unchanged); wrong sha256 refused, retried once, then reported; too-short and too-long downloads refused; path traversal and foreign hosts refused; a kill after N files leaves the current generation readable and unchanged; atomic switch; a snapshot held across a switch keeps the old data; pruning keeps two generations; pack and Wi-Fi gating with a fake path monitor; seed install, then diff against the seed's manifest fetches only changes; 304 fetches nothing.
- **Outbox tests:** persistence across a reload, order kept, backoff schedule, idempotency key makes a resend safe, flush stops when the network goes and resumes when it returns, the queue is capped.
- **CI:** package tests run in the package matrix; the seed hash check runs on Linux in `ios-changes.yml`; an optional, non-gating run reads the live manifest. On device (manual, in the build note): airplane-mode launch shows the agenda; sync over cellular fetches only `core`.

### Questions for the conductor and Dinis
1. Readers: the PTCore `ContentSource` seam (recommended) or direct PTSync dependencies?
2. Does `version` in the manifest change on every site build? (Needed so an unchanged build costs one 304.)
3. Are the 2,330 promptugal.news files all public and cacheable (no cookies)? Does it send an `ETag`?
4. Should removed files be deleted from the local store at the next switch (recommended) or kept for a day?
5. Seed size: is a 20 MB `full` seed in the PrompTugal IPA acceptable, or only `core` (1–2 MB) in the build and `full` downloaded on first Wi-Fi?

## PTSync wiring for the PrompTugal app (for apps; not on my branch)

Conductor ruling (10:55 UTC): Apps/PrompTugal is apps' to edit, so my branch carries PTSync (package, tests, PTCore seam, seed script) and none of the app wiring. This is the wiring I built and had green-checked locally with `check_apps.py`: apply it with `git apply` (save the block below to a file) or copy the pieces.
1. `apps.json`: `promptugal.packages` becomes `["PTAsk", "PTSync"]`.
2. `PrompTugal.xcodeproj`: PTSync local package reference, product dependency and framework build file (same five places as PTVaultUI).
3. `Info.plist`: add `news.promptugal.reader.sync` to BGTaskSchedulerPermittedIdentifiers.
4. `PrompTugalApp.swift`: `import PTSync`, `PublicSync.start()` in `init`, and in `onChange(of: scenePhase)`: `SyncBackground.schedule()` on background and a refresh on active.
5. New `Apps/PrompTugal/Shell/PublicSync.swift`: opens the `ContentStore` (looks for a bundled `Seed/promptugal.news` folder), registers it with PTCore's `ContentSources`, runs the `SyncEngine` with `PackRules.promptugalNews`, and registers the background task.

```diff
diff --git a/Apps/PrompTugal/Info.plist b/Apps/PrompTugal/Info.plist
index 8be4469..26ff6d0 100644
--- a/Apps/PrompTugal/Info.plist
+++ b/Apps/PrompTugal/Info.plist
@@ -10,6 +10,7 @@
 	<array>
 		<string>news.promptugal.reader.refresh</string>
 		<string>news.promptugal.reader.vault-refresh</string>
+		<string>news.promptugal.reader.sync</string>
 	</array>
 	<key>CFBundleURLTypes</key>
 	<array>
diff --git a/Apps/PrompTugal/PrompTugal.xcodeproj/project.pbxproj b/Apps/PrompTugal/PrompTugal.xcodeproj/project.pbxproj
index 69b7e47..47a8c07 100644
--- a/Apps/PrompTugal/PrompTugal.xcodeproj/project.pbxproj
+++ b/Apps/PrompTugal/PrompTugal.xcodeproj/project.pbxproj
@@ -15,6 +15,7 @@
 		5B2719121FAAE433CDC36721 /* PTNews in Frameworks */ = {isa = PBXBuildFile; productRef = 8CA679B880DAE215C2AF5ED5 /* PTNews */; };
 		FA561A52534BBBD0C4E9F720 /* PTAsk in Frameworks */ = {isa = PBXBuildFile; productRef = FC463707B728B9D5A483F362 /* PTAsk */; };
 		62C152B82B7782691901FDE6 /* PTVaultUI in Frameworks */ = {isa = PBXBuildFile; productRef = 00CAC9EBB3D202E3D0898BB2 /* PTVaultUI */; };
+		A5C9E1D07B2F4A6E8D31C0F1 /* PTSync in Frameworks */ = {isa = PBXBuildFile; productRef = B6D0F2E18C3A5B7F9E42D1A2 /* PTSync */; };
 		AD62C18680AF9EC5A07E5B5A /* PrompTugalWidgets.appex in Embed */ = {isa = PBXBuildFile; fileRef = 0485B70324B3CAF2A57E8008 /* PrompTugalWidgets.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
 		A3DB1CA94FAE24CD2F779D42 /* PTAgenda in Frameworks */ = {isa = PBXBuildFile; productRef = 32154EC416734B3A20FF1516 /* PTAgenda */; };
 		FA989053DC0B7A670553676E /* PrompTugalIntents.appex in Embed */ = {isa = PBXBuildFile; fileRef = 6C6F5DFA30844948E2F80344 /* PrompTugalIntents.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
@@ -159,6 +160,7 @@
 				5B2719121FAAE433CDC36721 /* PTNews in Frameworks */,
 				FA561A52534BBBD0C4E9F720 /* PTAsk in Frameworks */,
 				62C152B82B7782691901FDE6 /* PTVaultUI in Frameworks */,
+				A5C9E1D07B2F4A6E8D31C0F1 /* PTSync in Frameworks */,
 			);
 			runOnlyForDeploymentPostprocessing = 0;
 		};
@@ -266,6 +268,7 @@
 				8CA679B880DAE215C2AF5ED5 /* PTNews */,
 				FC463707B728B9D5A483F362 /* PTAsk */,
 				00CAC9EBB3D202E3D0898BB2 /* PTVaultUI */,
+				B6D0F2E18C3A5B7F9E42D1A2 /* PTSync */,
 			);
 			productName = PrompTugal;
 			productReference = 0D08D33B90E2593AC336F1CD;
@@ -409,6 +412,7 @@
 				689CF41318B6542F4B8EB9FE /* XCLocalSwiftPackageReference "../../Packages/PTNews" */,
 				020358F86EADE19098D947DA /* XCLocalSwiftPackageReference "../../Packages/PTAsk" */,
 				5B8B55ACA6103253EC13D5C9 /* XCLocalSwiftPackageReference "../../Packages/PTVaultUI" */,
+				C7E1A3F29D4B6C8A0F53E2B3 /* XCLocalSwiftPackageReference "../../Packages/PTSync" */,
 			);
 			preferredProjectObjectVersion = 77;
 			productRefGroup = 6184002F36CB9470245CDFFC /* Products */;
@@ -857,6 +861,10 @@
 			isa = XCLocalSwiftPackageReference;
 			relativePath = ../../Packages/PTVaultUI;
 		};
+		C7E1A3F29D4B6C8A0F53E2B3 /* XCLocalSwiftPackageReference "../../Packages/PTSync" */ = {
+			isa = XCLocalSwiftPackageReference;
+			relativePath = ../../Packages/PTSync;
+		};
 /* End XCLocalSwiftPackageReference section */
 
 /* Begin XCSwiftPackageProductDependency section */
@@ -895,6 +903,11 @@
 			package = 5B8B55ACA6103253EC13D5C9 /* XCLocalSwiftPackageReference "../../Packages/PTVaultUI" */;
 			productName = PTVaultUI;
 		};
+		B6D0F2E18C3A5B7F9E42D1A2 /* PTSync */ = {
+			isa = XCSwiftPackageProductDependency;
+			package = C7E1A3F29D4B6C8A0F53E2B3 /* XCLocalSwiftPackageReference "../../Packages/PTSync" */;
+			productName = PTSync;
+		};
 		32154EC416734B3A20FF1516 /* PTAgenda */ = {
 			isa = XCSwiftPackageProductDependency;
 			package = E0A0E149DD8F39A2BD3E95E5 /* XCLocalSwiftPackageReference "../../Packages/PTAgenda" */;
diff --git a/Apps/PrompTugal/PrompTugalApp.swift b/Apps/PrompTugal/PrompTugalApp.swift
index 6df6748..f64eca4 100644
--- a/Apps/PrompTugal/PrompTugalApp.swift
+++ b/Apps/PrompTugal/PrompTugalApp.swift
@@ -2,6 +2,7 @@ import SwiftUI
 import PTCore
 import PTAgenda
 import PTVaultUI
+import PTSync
 
 /// Entry point of the public PrompTugal app (news.promptugal.reader).
 /// Background task ids for this app: news.promptugal.reader.refresh and
@@ -25,6 +26,8 @@ struct PrompTugalApp: App {
         AgendaHub.publishNowNext = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }
         // Background tasks must be registered before the app finishes launching.
         VaultBackground.register(taskIdentifier: "news.promptugal.reader.vault-refresh")
+        // Synced files of promptugal.news (PTSync): the build's seed, then the site's manifest. Also a background task.
+        PublicSync.start()
     }
 
     var body: some Scene {
@@ -32,7 +35,11 @@ struct PrompTugalApp: App {
             PublicShell()
         }
         .onChange(of: scenePhase) { _, phase in
-            if phase == .background { VaultBackground.schedule() }
+            if phase == .background {
+                VaultBackground.schedule()
+                SyncBackground.schedule()
+            }
+            if phase == .active { Task { await PublicSync.refresh() } }
         }
     }
 }
diff --git a/Apps/PrompTugal/Shell/PublicSync.swift b/Apps/PrompTugal/Shell/PublicSync.swift
new file mode 100644
index 0000000..91de7d9
--- /dev/null
+++ b/Apps/PrompTugal/Shell/PublicSync.swift
@@ -0,0 +1,44 @@
+import Foundation
+import PTCore
+import PTSync
+
+/// The public app's synced files: promptugal.news' manifest, kept on this device and checked against its SHA-256 hashes.
+/// The core pack (agenda, days, stories, indexes, about 1.5 MB) comes first; the full pack (graph, search, entity pages)
+/// follows when the connection is not cellular or in Low Data Mode. Nothing here is a screen: readers take the files
+/// through PTCore's `ContentSources` (site id `promptugal.news`), and fall back to the network when it holds nothing.
+@MainActor
+enum PublicSync {
+    /// Also listed in Info.plist under BGTaskSchedulerPermittedIdentifiers.
+    static let taskIdentifier = "news.promptugal.reader.sync"
+
+    private(set) static var store: ContentStore?
+    private(set) static var engine: SyncEngine?
+    private static let network = SystemNetworkPath()
+
+    /// Called once from the app's `init`, before any view reads content. Opens the store off the main thread, registers it,
+    /// then runs a first sync.
+    static func start() {
+        SyncBackground.register(taskIdentifier: taskIdentifier) { await PublicSync.refresh() }
+        Task {
+            // A folder named "Seed" in the app bundle holds the build's seed: Seed/promptugal.news/manifest.json and files.
+            let seed = Bundle.main.url(forResource: "Seed", withExtension: nil)?
+                .appendingPathComponent(SyncSource.promptugalNews.id, isDirectory: true)
+            let opened = await ContentStore.open(source: .promptugalNews, seed: seed)
+            store = opened
+            ContentSources.register(opened, for: SyncSource.promptugalNews.id)
+            engine = SyncEngine(store: opened, rules: .promptugalNews, network: network)
+            _ = await refresh()
+        }
+    }
+
+    /// One sync. Core always; full when the connection allows (the engine leaves it out otherwise). True when nothing failed.
+    @discardableResult
+    static func refresh(packs: Set<SyncPack> = [.core, .full]) async -> Bool {
+        guard let engine else { return false }
+        do {
+            return try await engine.sync(packs).failures.isEmpty
+        } catch {
+            return false
+        }
+    }
+}
diff --git a/apps.json b/apps.json
index 64ea72d..4e36acf 100644
--- a/apps.json
+++ b/apps.json
@@ -15,7 +15,7 @@
              "paths": ["Apps/Team/"],
              "packages": ["PTLanes", "PTAsk"], "testflight": true},
     "promptugal": {"project": "Apps/PrompTugal/PrompTugal.xcodeproj", "scheme": "PrompTugal", "bundle": "news.promptugal.reader",
-                   "paths": ["Apps/PrompTugal/"], "packages": ["PTAsk"], "testflight": true},
+                   "paths": ["Apps/PrompTugal/"], "packages": ["PTAsk", "PTSync"], "testflight": true},
     "riskmandate": {"project": "Apps/RiskMandate/RiskMandate.xcodeproj", "scheme": "RiskMandate", "bundle": "ai.riskmandate.app",
                     "paths": ["Apps/RiskMandate/"], "packages": ["PTCore"], "testflight": true}
   },
```
