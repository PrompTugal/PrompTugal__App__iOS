# Status · Team features

> One schedule on the website's format, synced with the web view and the vault; reminders; team data; the day planner; the native top-up. All on dev and wired into the app; dev is green with every test on iPhone and iPad (run 104).

Branch: `night/team` (merges `origin/dev`, never rebased) · Last update: 05:20 UTC

## Done

- **One schedule** (`Schedule/`): `ScheduleStore` on `nr.schedule.v1`, kept on the device (`Application Support/PrompTugal/schedule.json`). Every old Saved session (`saved.json`) is imported with its offline copy; saved.json stays as a backup.
- **Bridge** (`Bridge/`): `AppBridge`. Handler `pt` in its own `WKContentWorld`, main frame only, https only, allow-list `promptugal.news` and `web-summit.sgit.ai`. `window.ptApp = { version, ops, call }`. Ops `schedule.get`, `schedule.set`, `identity.get`, `notify.plan`, `meter.topup`. Two-way schedule sync with promptugal.news through `localStorage['nr.schedule.v1']` and the page's own `nr:schedule` event, with no website change. `BridgeLog` and `BridgeLogView` for Debug. `SiteDataStores` gives each site its own `WKWebsiteDataStore`.
- **Vault** (`ScheduleVaultLink`): when a reader vault opens, picks are read from `apps/agenda/picks.json` (`loadPicks`) and merged; no Face ID. Saving (`savePicks`) is a button in My day, because it asks for Face ID and needs the vault key and an access token.
- **Reminders** (`Notifications/`): before each pick and each stand-up, default 10 minutes (choices 0, 5, 10, 15, 30), Lisbon time, at most 60 pending (iOS allows 64).
- **Team data** (`Team/`): models and offline cache for `me.json`, the command centre `data.json`, stand-ups, wakes, reports, pulse and log. "Who are you?" identity, and the app icon badge (only you + decide + overdue).
- **Planner**: a proposed day from the agenda, my picks and the stand-ups, with clashes (overlap, or too little time to walk) and gaps. Sessions the team picked for me rank first, then sessions teammates have. Accept → picks. "Where is everyone" lists teammates' sessions per day.
- **iPhone and iPad**: every screen is a list on iPhone. On iPad, My day and the planner add the day as a time line beside the list.
- **Meter and native top-up** (`Store/`): `MeterStore` shows the website's balance; `CreditStore` sells the two consumables with StoreKit 2 and credits the page's meter through the bridge, once per transaction. The Stripe top-up is hidden in the app and replaced by "Top up in the app".
- **Backlog done**: Add to Calendar (write-only EventKit, only when asked); App Intents "Save a session to my day" and "What's next in my day"; the schedule feeds platform's widget (`NowNextPublisher`).
- **Tests** (`PrompTugalTests/ScheduleTests.swift`, `TeamFeaturesTests.swift`): wire format and an exact round trip of a website-shaped document, merge rule with negative controls, Lisbon time, migration, vault sync, markdown and JSON parsing, reminder plan, planner. The injected JavaScript is syntax-checked with node before each push.

## CI

- **Green on dev**: run 104 (dev 27881b0, which contains all of night/team up to 500b5ad): app build, SGitVault tests, and the unit tests on iPhone and on iPad all pass.
- Fixed tonight: one test expression the type checker timed out on (396968c); the schedule's JSON key order, which was not stable across devices and broke two exact-text tests on dev (500b5ad, now written by hand as the website's `JSON.stringify` writes it). Before that fix, 63 of 65 tests passed.
- Platform's wiring is on dev: the bridge on `WebsiteBrowser` and design's `WebPage`, `ReaderStore` → schedule, the widget, and the team refresh in the background. `.teamFeatures()` is applied once (the modifier now ignores a second copy).

## What I learned from the websites

- **Pick id is the bare slug** (`ai-doom-or-boom`), not `events/<slug>`.
- **`at` is an ISO string** (`toISOString()`). The app writes exactly that and reads numbers too.
- **The website's merge is union only**, and so is the vault's `savePicks`. The app adds, on this device: a removal later than the pick wins (remembered 30 days), and a pick the page dropped since the last sync counts as removed. A removal does not reach other devices or the website; that is in the conductor's list for Dinis.
- **Meter**: `localStorage['web-summit.newsroom.meter.v1']`, sg-meter state v3, amounts in pence. App credit uses the site's own `credit(amount, 'link', 'appstore-<transaction id>')`, which refuses a reference twice.
- **Team site**: only `me.json` and `people/<id>/app/data.json` are JSON. Wakes, reports, pulse, log and the meetings list are read from their markdown twins (`index.md`). Stand-up folder names do not always match the time (`2026-11-05-1300` was at 12:00), so the list's label is used.
- **Places**: `/api/v1/places.json` (83, no coordinates). Walking times are estimates: 5 minutes between rooms at the venue, 25 to anywhere else.

## Entry views (for the shell)

| Feature | Entry view | Destination |
| --- | --- | --- |
| Schedule | `MyDayView()` | replaces `team.schedule` |
| Planner | `PlannerView()` | new, Today: "Plan my day" |
| Where is everyone | `WhereIsEveryoneView()` | new, Team |
| Team home and identity | `TeamHomeView()` | optional |
| Reading credit | `ReadingCreditView()` | replaces `team.store` |
| Reminders | `ReminderSettingsView()` | Settings |
| Bridge panel | `BridgeLogView()` | Debug → Bridge |

All need `.teamFeatures()` once on the root view: it injects every store, starts StoreKit, reminders and the vault link, and presents the native top-up when a page asks.

Models (all `Sendable`, decoded leniently): `TeamMe`, `TeamPerson`, `CommandCentre` (`Issue`, `Decision`, `Agent`, `Activity`, `Session`, `Workstream`, `Member`), `TeamStandup`, `AgentWakes`, `TeamReport`, `PulseEntry`, `SessionLogEntry`, held by `TeamStore`. Schedule: `ScheduleStore`, `SchedulePick`, `ScheduleDocument`. URLs: `TeamEndpoints`.

## Next

1. Register the entry views that design has not yet (Plan my day, Where is everyone, Reminders in Settings, Bridge in Debug).
2. Live Activity data for the next item (platform owns the target).

## Blocked

Nothing in my folders.

## Needs from others

- **Platform** (done on dev, kept here for the record):
  1. `WebsiteBrowser.init`: replace `configuration.websiteDataStore = .default()` with `TeamFeatures.shared.bridge.configure(configuration, for: homeURL)`, and after creating the web view call `TeamFeatures.shared.bridge.attach(webView)`.
  2. Add `webView(_:didFinish:)` calling `TeamFeatures.shared.bridge.pageDidFinish(webView)`. In `decidePolicyFor`, before allowing: `if let url = action.request.url, TeamFeatures.shared.bridge.handlesNavigation(to: url) { decisionHandler(.cancel); return }`. Design's `WebPage` needs the same three lines.
  3. After each agenda refresh in `ReaderStore`: `TeamFeatures.shared.agendaDidLoad(events)`. Route `toggleSaved`, `isSaved` and `saved` to `TeamFeatures.shared.schedule` (`toggle(event)`, `isPicked(event)`, `picks.compactMap(\.event)`).
  4. Info: `NSCalendarsWriteOnlyAccessUsageDescription`; Time Sensitive Notifications capability; register a `BGAppRefreshTask` that calls `TeamFeatures.shared.refreshTeam()`.
- **Design**: the destinations above that are still placeholders.

## Apple setup for the native top-up

1. App Store Connect: two consumables, `news.promptugal.reader.credit.5` (£5 of credit) and `news.promptugal.reader.credit.20` (£20), each with a price, a display name and a review screenshot.
2. The Paid Apps agreement signed, with banking and tax details.
3. The In-App Purchase capability on the app id.
4. Local testing already works with `PrompTugal/Store/PrompTugal.storekit` on the scheme.
5. Review note: the credit is for the reading meter on promptugal.news; the website's Stripe link is hidden in the app (rule 3.1.1).

## Trade-offs

- **Data stores:** promptugal.news stays on the default store, where earlier builds kept its schedule, meter and vault session. web-summit.sgit.ai moves to its own store, so its earlier `ws.me` choice and `ws-keyring` keys stay behind. The app writes `ws.me` from the native identity; each person opens their `#key=` link once more.
- **Bridge in its own world:** page scripts cannot see a handler in another content world, so `window.ptApp.call()` relays through a DOM event (and a DOM attribute) to the app's bridge-world script. The origin check is native, on the real frame.
