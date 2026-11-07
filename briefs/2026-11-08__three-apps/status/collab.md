# Collab status: PTAsk and PTLanes

> Collab moves AI/ into PTAsk and Lanes/ into PTLanes. Coordination/ stays in the Team app. Phase 0 (mapping and plan) is done. Waiting for team, design and vault packages on dev. No code moved yet.

**Branch:** `split/collab` (from `origin/dev` 45284d0) · **Last CI run:** none yet (no code changed)

## Rulings from the conductor (7 Nov, 23:47 UTC)
1. `CollabSeams.swift` goes in PTCore, one file, owned by collab: protocols, value types and the formatter only. `CollabVaultAccess` there uses plain types. `VaultCollabAccess` lives in PTVaultUI (agreed with vault through the conductor). Add the file only after platform's phase 2 is on dev.
2. `AskContextProvider`, `PublicAskProvider`, `TeamAskProvider` approved. Consent and context switches behave as today in the Team app.
3. The 4 team AITests may move to the Team test target.
4. Order: PTLanes once PTVaultUI is on dev; PTAsk last, after PTAgenda, PTNews and PTVaultUI. The conductor pings at each step.

## Design's map (7 Nov, 23:48 UTC)
Two `TeamFeatures.shared` uses must be covered: `AIContext.swift:320` (`teamData`, now `TeamAskProvider.part(for:)`) and `AskView.swift:196` (`AskMentions` schedule, now `isPicked` / `togglePick` on the provider). Added to the protocol above.

## Done
- Read the three-apps README, contracts and the overnight rules.
- Mapped what `AI/` (9 files) and `Lanes/` (9 files) use from outside. About 4,000 lines.
- Designed the provider split (below).

## In progress
- Nothing. Waiting for the conductor.

## Next
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
    func togglePick(_ event: Event)                       // PublicAskProvider uses the reader's saved sessions; TeamAskProvider uses ScheduleStore
    func part(for kind: AIContextKind, now: Date) async -> AIContextPart?   // .team .agents .teammates .plan; public app returns nil
    func runTool(_ name: String, args: [String: String], now: Date) async -> (text: String, summary: String)?  // team_status, my_agents, where_is_everyone
    var extraStarters: [AIStarter] { get }                // "My agents" only in Team
}
public enum AskEnvironment { @MainActor public static var provider: any AskContextProvider = PublicAskProvider() }
```
- `PublicAskProvider` (in PTAsk): agenda from the reader cache then `FeedClient`, picks from the reader's saved sessions, no team, no person name. It is the default, so the public app works with no wiring.
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
