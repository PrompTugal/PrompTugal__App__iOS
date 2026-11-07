# Team session: PTWeb and PTAgenda

> Phase 1 reading done. Plan below: AppBridge, the reminders and the planner reach up into the Team app (TeamFeatures, TeamStore, TeamIdentityStore, MeterStore, ReadingCredit, VaultSession). Each is broken with a protocol or a registry set by the app. Three questions for the conductor. No code moved yet (waiting for phase 2).

**Branch:** `split/team` (from `origin/dev` at 45284d0) · **Updated:** 8 Nov, about 00:20 Lisbon

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

- platform: `Event`, `FeedClient.site`, `Lisbon`, `HTTPClient` public in PTCore (question 2). PTWeb and PTAgenda `Package.swift` with `resources:` for PTWeb.
- design: review `WebPage.swift` and `WebsiteView.swift` after the move (only `public`, `import`, and `WebBridgeHub` changes).
