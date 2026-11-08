# Team session: PTWeb and PTAgenda

> PTWeb and PTAgenda are on dev (17a160c, merged as 7863ae2, run 307 green). Follow-up in progress: reminder links use AppLinks.scheme, and the StoreKit test no longer waits 60 s. CI run on macos-26 queued; READY comes after it is green.

**Branch:** `split/team` (merged origin/dev b845004, phase 1 + vault) · **Updated:** 8 Nov, 01:10 UTC (waiting for PTCore)

## Account B notes (8 Nov, about 01:50 UTC)

- Merged origin/dev (docs only). Run 293 on 6cccf88 stays queued: six runs are ahead of it, and a push now would send it to the back, so I made no Swift change yet.
- Read by eye, no compiler: PTWeb (all of Bridge/, WebPage, BridgeServices, public inits, PTCore symbols it uses) and the PTAgenda seams, ReminderPlan, AgendaBridgeServices, ReaderStore head. All types are public or private as needed; PTCore has every symbol used (Lisbon, HTTPLog, KindBadge, Palette). Nothing to fix before the first compile.
- One behaviour bug to fix with the `AppLinks.scheme` change: `ReminderDelegate` (ReminderScheduler.swift) only accepts `promptugal` links, so a Team (`ptteam`) reminder tap is dropped. It will check `AppLinks.scheme`.
- `AppLinks` is not on dev yet (platform ce3602e, run 292 queued).

- **02:20 UTC:** Run 293 failed (cancelled by the conductor after the Debug build, iPhone and iPad tests, PTWeb and PTAsk failed). The log has one real error, twice: `BridgeScripts.swift` used `ScheduleDocument.storageKey` and `.changeEvent`, and PTWeb cannot see PTAgenda. PTWeb now owns both strings (`BridgeScripts.scheduleKey`, `scheduleChangeEvent`) and `ScheduleDocument` reads them. PTAsk failed through PTWeb, so the same fix should clear it. `ReminderDelegate` now accepts `promptugal` and `ptteam` links. Pushed as 115ba30; run 296 (app=all) queued. PTAgenda itself has not compiled yet.

- **03:20 UTC:** 17a160c merged to dev as 7863ae2. Follow-up on top of dev eb99508: `ReminderPlan`, `ReminderItem` and `ReminderScheduler` take their scheme from `AppLinks.scheme` (read when scheduling, so launch order does not matter), `ReminderDelegate` accepts only the app's own scheme, and `TeamFeatures.urlScheme` is gone. `AppReviewTests`: StoreKit product load bounded to 15 s, then the known issue is recorded. Not yet compiled.

## Handoff

**Handed off at 01:35 UTC, 8 Nov, to the session on account B.**

- **Head:** `6cccf88` on `split/team` (phase 3 moves for PTWeb and PTAgenda, on top of origin/dev 94b63c7).
- **Last CI run:** ios.yml run 293 (`workflow_dispatch`, app=all) on 6cccf88. It was still queued when I stopped. Result not seen. Read it first: `actions_list` for ios.yml, branch split/team.
- **Done:**
  - PTWeb: `Bridge/`, `WebPage`, `WebsiteView`, `WebsiteShortcuts`, `Websites.json` (package resource, `Bundle.module`). Seams: `WebBridgeHub` (bridge, `offlineReader`, `noteCurrentPage`) and `BridgeServices`, `BridgeMeterSource` in `Bridge/BridgeServices.swift`.
  - PTAgenda: `Schedule/` (not `ScheduleIntents.swift`), `Notifications/`, `AgendaView`, `ReaderStore` (in `News/`). Seams in `AgendaSources.swift`: `AgendaTeamSource`, `AgendaIdentitySource`, `VaultPicksAccess`, `AgendaHub`, `TeamStandup`. `AgendaBridgeServices` is the adapter for the bridge.
  - Team app glue: `Team/TeamAgendaConformances.swift` (conformances and `VaultSessionPicks`), `Team/TeamFeatures.swift` (`registerHubs()`).
  - Tests moved: ScheduleTests and ReaderStoreTests to PTAgenda; WebsitesJSONTests and the bridge-gate / checkout tests (new `BridgeGateTests.swift`) to PTWeb.
  - Both `Package.swift` files use `swiftLanguageModes: [.v5]`, matching the app (SWIFT_VERSION 5.0). PTWeb has `resources: [.process("Resources")]`.
- **Half-done / unknown:**
  - Nothing has been compiled. Expect errors: I added `public` with a script (`publicize.py`, not in the repo) and generated public inits for structs without one. Likely misses: a missing public init, an `@escaping`, a private type in a public signature, an unimported symbol, a package test target that does not compile.
  - Check also that the Xcode project still builds: the app target uses synchronized folders, so moved files drop out by themselves, but `Websites.json` and `Shared/` are worth a look.
- **Exact next steps:**
  1. Read run 293 (`get_job_logs` with `failed_only`). Fix, push, dispatch ios.yml again (`app=all`; pushes to split/** do not trigger it).
  2. Switch the reminder URL scheme to `AppLinks.scheme` once PTCore has it on dev (platform, commit ce3602e on split/platform): merge origin/dev, then in `Packages/PTAgenda/Sources/PTAgenda/Notifications/ReminderPlan.swift` replace the default `"promptugal"` (`ReminderItem.scheme`, `ReminderPlan.items(scheme:)`) and in `ReminderScheduler.init(urlScheme:)` use `AppLinks.scheme`. Then `TeamFeatures.urlScheme` can go.
  3. When green, run one full run (`quick=false`), then send_message "@parent" with branch, commit and run number: READY.
  4. `Shared/NowNext.swift` stays until the widget target links PTAgenda (phase 4, platform). `ScheduleIntents.swift` stays in `PrompTugal/Schedule/` until phase 4 (goes to the PrompTugal app).
- **Open questions:**
  - Is `swiftLanguageModes: [.v5]` right for all packages? The other packages on dev do not set it.
  - `WebBridgeHub.noteCurrentPage` is wired to `CollabHooks.noteCurrentPage` in `TeamFeatures.registerHubs()`. The public app needs its own wiring for Ask's "current page".
  - The conductor asked for PTWeb alone first, so design's PTNews could merge it. It is in the same commit as PTAgenda. If PTAgenda keeps failing, split PTWeb out by reverting PTAgenda files in a separate branch.

## State

- **Done:** read both briefs, mapped every type in the moving folders.
- **In progress:** this plan.
- **Next:** wait for "PTCore is on dev", then merge `origin/dev` and move.
- **Blocked:** nothing yet. Three questions below.
- **Last CI run:** none (no code changed).

## What moves

| Package | Files | Lines |
| --- | --- | --- |
| PTWeb | `Bridge/` (CheckoutPolicy, AppBridge, BridgeScripts, SiteDataStores, BridgeLog, BridgeLogView), `Shell/WebPage.swift`, `App/Web/` (WebsiteView, WebsiteShortcuts), `App/Resources/Websites.json` | 736 + 244 + 440 |
| PTAgenda | `Schedule/` (14 files), `Notifications/` (3 files), `Shared/NowNext.swift` | 1783 + 348 + about 80 |

`NowNextPublisher.swift` stays in `App/` (platform). `PrompTugalWidgets/NowNextWidget.swift` also uses `NowNext.swift`, so the widget target must link PTAgenda (platform, phase 4).

## Edges that point up or sideways, and how each is broken

### PTWeb (may use only PTCore)

| Where | Uses | Fix |
| --- | --- | --- |
| `WebPage`, `WebsiteView` | `TeamFeatures.shared.bridge` (configure, attach, handlesNavigation, pageDidFinish) | `AppBridge` moves into PTWeb. Add `WebBridgeHub` in PTWeb: `@MainActor public static var bridge: AppBridge?`. The app sets it once at launch. The views call `WebBridgeHub.bridge?...`. No schedule or meter type is needed there. |
| `AppBridge` | `ScheduleStore` (document, merge, markSynced, `.scheduleDidChange`) | New `public protocol BridgeScheduleSource` in PTWeb. It works on JSON (`[String: Any]` / `Data`), so `ScheduleDocument` stays in PTAgenda. PTAgenda gets a small adapter that wraps `ScheduleStore`. See question 1. |
| `AppBridge` | `MeterStore` (update, snapshot, `.meterHasPendingCredit`) | New `public protocol BridgeMeterSource` (update(from:), balanceText, pending-credit notification name). `MeterStore` stays in the Team app and conforms. |
| `AppBridge` | `TeamIdentityStore` (current, verified, `.teamIdentityDidChange`) | New `public protocol BridgeIdentitySource` (id, name, verified). Team app conforms. |
| `AppBridge` | `ReminderScheduler` (currentAuthorization, reschedule) | New `public protocol BridgeRemindersSource`. PTAgenda's `ReminderScheduler` conforms (the app or PTAgenda adds the conformance). |
| `AppBridge` | `ReadingCredit.isAvailable` (Store/, stays in the Team app) | A `Bool` / closure `offersAppTopUp` in the init. The Team app passes `ReadingCredit.isAvailable`, the PrompTugal app passes `false`. |
| `WebPage` | `HTTPClient.redact` | PTCore (platform, phase 2). Just `import PTCore`. |
| `BridgeLog*`, `Lisbon` | PTCore | `import PTCore`. |

These sources can be one protocol (`BridgeServices`) if you prefer. I will use one protocol with five groups, so `AppBridge.init` takes one `services:` argument instead of five.

### PTAgenda (may use PTCore and PTWeb)

| Where | Uses | Fix |
| --- | --- | --- |
| `Event` (in `App/Content.swift`) | used by ScheduleStore, DayPlanner, ScheduleIntents, NowNext. Needs `FeedClient.site` and `Lisbon`. | Must be in PTCore, or PTAgenda cannot compile. See question 2. |
| `ReminderScheduler`, `ReminderSettingsView`, `PlannerStore`, `MyDayView`, `NextHoursCard`, `PlannerView` | `TeamStore` (standups, upcomingStandups, me, centres, refresh, refreshCentre) and `TeamIdentityStore` (current) | Team stays in the Team app. In PTAgenda: `public protocol AgendaTeamSource` (standups, upcomingStandups(after:), refresh(person:)) and `public protocol AgendaIdentitySource` (current person id). Move the value type `TeamStandup` (about 30 lines, only Foundation and `Lisbon`) into PTAgenda. Its `url` uses `TeamEndpoints.base`, so that URL is passed in or computed by the Team app. The planner's team-coordination part (`centres`, `TeamPerson.order`, `CommandCentre`) is reached through one closure `coordination` and one closure `loadTeam` on `PlannerStore`. Views read the sources from the environment as before. `@Environment(TeamStore.self)` becomes an environment key for the protocol. |
| `ScheduleVaultLink`, `ScheduleVaultSync` | `VaultSession.shared` (reader, canPush, readText, loadPicks, savePicks). PTAgenda does not depend on PTVaultUI. | `public protocol VaultPicksAccess` in PTAgenda (hasVault, canSave, loadPicks, savePicks, an observation hook). The app implements it over `VaultSession.shared`. `ScheduleVaultLink` takes it in `init`. It also takes a `BridgeLog`, which is in PTWeb, so that is fine. |
| `ScheduleIntents` | `TeamFeatures.shared.planner / .schedule` | `AgendaHub` in PTAgenda: `@MainActor public static var planner / schedule`, set by the app. See question 3 about App Intents in a package. |
| `MyDayView` | `AppBridge` (bridge in the environment) | Fine. PTAgenda depends on PTWeb. |
| `Notifications/ReminderPlan` and the `promptugal://open/team.schedule` link | route string only | No type. Stays as a string. |

### Stays in the Team app (team owns)

`TeamFeatures` stays in `Team/`. It builds the stores, sets `WebBridgeHub.bridge` and `AgendaHub`, and conforms the stores to the new protocols. Today it also creates `ScheduleStore`, `PlannerStore`, `ReminderScheduler`, `AppBridge`: those become `public` with public inits.

## Resources

- `Websites.json` moves to `Packages/PTWeb/Sources/PTWeb/Resources/Websites.json`, declared in `Package.swift` with `resources: [.process("Resources")]`. `WebsiteShortcuts` changes `Bundle.main` to `Bundle.module`.
- The injected JS is inline Swift strings in `BridgeScripts.swift` (no `.js` files). Nothing to bundle.
- `WebsitesJSONTests` reads `Bundle.main`. It moves to `Packages/PTWeb/Tests` and uses `Bundle.module` through `@testable import PTWeb`.
- Platform: remove `Websites.json` from the app's Resources build phase when its folder moves (phase 4, or when PTWeb lands).

## Tests

| Test file | Where |
| --- | --- |
| `ScheduleTests`, `NowNextTests` | `Packages/PTAgenda/Tests` (to confirm they use no TeamFeatures / app host) |
| `WebsitesJSONTests` | `Packages/PTWeb/Tests` |
| `AppReviewTests` (CheckoutPolicy parts) | split: CheckoutPolicy cases to PTWeb, the rest stays |
| `TeamFeaturesTests` | stays in the Team app (it builds `TeamFeatures`) |

## Conductor's answers (8 Nov, 00:48 Lisbon)

1. JSON-level bridge. `ScheduleDocument`, `ScheduleMerge`, `ScheduleID` stay in PTAgenda.
2. Platform moves `Event` and `FeedClient.site` into PTCore in phase 2.
3. `ScheduleIntents` stays in the app target; in phase 4 it goes to the PrompTugal app. The Team app gets no intents tonight.
4. The public app gets a no-team `AgendaTeamSource` that returns nothing.

5. `News/AgendaView.swift` (204 lines) moves into PTAgenda. It reads `ScheduleStore` from the environment and uses `.webTwin` and `FeedClient` (PTCore / PTWeb). Design reviews it.
6. `App/ReaderStore.swift` (168 lines) moves into PTAgenda. Its `TeamFeatures.shared.schedule` and `TeamFeatures.shared.agendaDidLoad` become an injected schedule and an `onAgendaLoaded` closure. PTAgenda must not import PTNews; each app adds `extension ReaderStore: NewsSource {}`.
7. Reminder links take their URL scheme from the app (`ptteam://` for Team, `promptugal://` for the public app). `ReminderPlan` gets a `scheme` parameter instead of the hard-coded `promptugal://` (line 28).

Waiting for phase 2 (PTCore on dev).

## Questions for the conductor (answered above)

1. **Schedule types across PTWeb and PTAgenda.** The bridge reads and merges `ScheduleDocument`. I plan a JSON-level protocol so PTWeb does not know the type. The cheaper alternative is to put `ScheduleDocument`, `ScheduleMerge` and `ScheduleID` (pure Foundation value types) in PTCore. Which do you want? Default: JSON-level protocol, no PTCore change.
2. **`Event` and `FeedClient.site`** are in `App/Content.swift`. PTNews, PTAgenda and PTAsk all need `Event`. Is platform moving the `Event` struct (and `FeedClient.site`) to PTCore in phase 2? If not, I need it there.
3. **App Intents in a package.** `ScheduleIntents.swift` (SessionEntity, SessionQuery, intents) is an App Intents type. Intents in a Swift package need an `AppIntentsPackage` conformance and the app target to include it. Safer: keep `ScheduleIntents.swift` in the app target and move only the stores. I propose it goes to `Apps/PrompTugal` and `Apps/Team` (shared source, or platform decides). OK?

Also: `Store/` and `Team/` stay as they are, but `Team/` must not be moved by anyone until `TeamFeatures` is updated by me in the same phase. I will edit `Team/TeamFeatures.swift`, `Team/TeamStore.swift` conformances and `Store/` only for `public`/conformance lines.

## Needs from others

- design or platform: `Shell/AppShell.swift:97` accepts only `url.scheme == "promptugal"`. When the Team app switches to `ptteam` (phase 4) it must compare with `AppLinks.scheme`, or reminder taps and deep links stop opening.

- platform: `Event`, `FeedClient.site`, `Lisbon`, `HTTPClient` public in PTCore (question 2). PTWeb and PTAgenda `Package.swift` with `resources:` for PTWeb.
- design: review `WebPage.swift` and `WebsiteView.swift` after the move (only `public`, `import`, and `WebBridgeHub` changes).
