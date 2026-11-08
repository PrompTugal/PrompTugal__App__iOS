# Collab status: PTAsk and PTLanes

> CollabSeams.swift is on dev (d597b8f). PTLanes is merged with vault's VaultCollabAccess on split/collab; run 314 failed on three PTLanes errors (SecretStore copy, public body, TeamNotes default argument), fixed in 44217b1, quick run 320 is queued. PTLanes and PTAsk are next, in that order. Collab moves AI/ into PTAsk and Lanes/ into PTLanes. Coordination/ stays in the Team app. Phase 0 (mapping and plan) is done. Waiting for team, design and vault packages on dev. No code moved yet.

**Branch:** `split/collab` (from `origin/dev` 45284d0) · **Last CI run:** run 314 (72c152c) red and cancelled; quick run 320 (ff66065, macos-26) queued · **Updated:** 04:08 UTC (collab.B)

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
