# Status · Team features

> One schedule on the website's format, the bridge, team data models, reminders, the day planner, the native top-up, Add to Calendar and two App Intents are written; the app build is green with them. Next: wiring into the web view and the shell.

Branch: `night/team` (rebased on `night/platform`) · Last update: 03:10 UTC (container clock)

## Done

- **One schedule** (`PrompTugal/Schedule/`): `ScheduleStore` on `nr.schedule.v1`, saved on the device (`Application Support/PrompTugal/schedule.json`). Every old Saved session (`saved.json`) is imported, keeps its offline copy, and saved.json is left in place. Tests: wire format, merge rule with negative controls, Lisbon time, migration (`PrompTugalTests/ScheduleTests.swift`, 25 tests).
- **Bridge** (`PrompTugal/Bridge/`): `AppBridge` (handler `pt` in its own `WKContentWorld`, main frame only, https, allow-list `promptugal.news`, `web-summit.sgit.ai`), `window.ptApp = { version, ops, call }`, phase-1 ops `schedule.get`, `schedule.set`, `identity.get`, `notify.plan`, `meter.topup`. Two-way schedule sync with promptugal.news through `localStorage['nr.schedule.v1']` and the page's own `nr:schedule` event; no website change. `BridgeLog` and `BridgeLogView` for Debug. `SiteDataStores`: one `WKWebsiteDataStore` per site.
- **Reminders** (`PrompTugal/Notifications/`): before each pick and stand-up, default 10 minutes (0, 5, 10, 15, 30), Lisbon time, at most 60 pending (iOS allows 64), rescheduled on every change.
- **Team data** (`PrompTugal/Team/`): models and offline cache for `me.json`, command centre `data.json`, stand-ups, wakes, reports, pulse and log. "Who are you?" identity.
- **Planner** (`DayPlanner`, `PlannerStore`, `PlannerView`): a proposed day from the agenda, my picks and stand-ups, with clashes (overlap, or too little time to walk), gaps and walking time. Sessions the team picked for me rank first, then sessions teammates have (from their command centres). Accept → picks.
- **Meter and native top-up** (`PrompTugal/Store/`): `MeterStore` shows the website's balance; `CreditStore` sells the two consumables with StoreKit 2 and credits the page's meter through the bridge, once per transaction. The Stripe top-up is hidden in the app and replaced by "Top up in the app".

## What I learned from the websites (and where it differs from contracts §3)

- **Pick id is the bare slug** (`ai-doom-or-boom`), not `events/<slug>`: schedule.js captures `events/([^/]+)/index.html`.
- **`at` is an ISO string** (`new Date().toISOString()`), not Unix milliseconds. The app reads both and writes the ISO form.
- **The website's merge is a plain union** that keeps its own copy and never removes. The app keeps that union and adds: a removal later than the pick wins (remembered 30 days), and a pick the page held at the last sync and has since dropped counts as removed on the page. If the page has no schedule at all (new, or cleared by WebKit), nothing is removed.
- **Meter**: `localStorage['web-summit.newsroom.meter.v1']`, sg-meter v1.5 state v3: `{ balance (pence), spent, reads, declined, log[], topups[{ref, at, credit, source}], sessions[ref] }`. App credit uses the core's own `credit(amount, 'link', 'appstore-<transaction id>')`, which refuses a reference twice.
- **Team site JSON**: `me.json` and `people/<id>/app/data.json` only. Wakes, reports, pulse, log and the meetings list have **no JSON**; each has a markdown twin (`/wakes/index.md` etc.) that the app parses. Stand-up folder names do not always match the time (`2026-11-05-1300` was at 12:00); the list's label is used.
- `/api/v1/place.json` does not exist; it is `/api/v1/places.json` (83 places, no coordinates), so walking times are estimates: 5 minutes between rooms at the venue, 25 to anywhere else.

## Entry views and models for the design session

| Feature | Entry view | Destination to replace |
| --- | --- | --- |
| Schedule | `MyDayView()` | `team.schedule` |
| Planner | `PlannerView()` | new, Today section, "Plan my day" |
| Team identity and home | `TeamHomeView()` (shows `WhoAreYouView` until chosen) | optional |
| Reading credit | `ReadingCreditView()` | `team.store` |
| Reminders | `ReminderSettingsView()` | Settings |
| Bridge panel | `BridgeLogView()` | Debug → Bridge |

Each needs the stores in the environment: put `.teamFeatures()` on the root view once (it injects every store, starts StoreKit and reminders, and presents the native top-up when a page asks).

Models (all `Sendable`, decoded leniently): `TeamMe`, `TeamPerson` (`badge` = only you + decide + overdue), `CommandCentre` (`Issue`, `Decision`, `Agent`, `Activity`, `Session`, `Workstream`, `Member`), `TeamStandup`, `AgentWakes`, `TeamReport`, `PulseEntry`, `SessionLogEntry`; `TeamStore` holds them (`me`, `centres`, `standups`, `wakes`, `reports`, `pulse`, `log`, `status`). Schedule: `ScheduleStore`, `SchedulePick`, `ScheduleDocument`. URLs: `TeamEndpoints` (named so to not clash with design's `TeamSite`; design can drop its copy and use these models when ready).

- **CI:** the app build with all of the above is green (run 14, one concurrency warning, fixed). Unit tests are running.
- **Add to Calendar** (`CalendarExport`, a button in My day): write-only EventKit access, only when asked.
- **App Intents** in the app target: "Save a session to my day" (`SaveSessionIntent`, with a `SessionEntity` search over the agenda) and "What's next in my day" (`WhatsNextIntent`).
- **Widget feed:** the schedule's picks go to platform's `NowNextPublisher` as `saved` on every change and agenda load.
- **Tests** (`PrompTugalTests/TeamFeaturesTests.swift`): markdown twins, lenient JSON, the reminder plan, the planner. The injected JavaScript is syntax-checked with node before each push.

## In progress

- Unit test results on iPhone and iPad.

## Next

1. Green CI.
2. Hook the bridge into the web views (needs the lines below in platform's `WebsiteView.swift`).
3. Feed the agenda to the schedule and the widget from the schedule.
4. Default shortcuts (item 7): platform already dropped riskmandate.ai and sgit.ai; its test pins newsroom.sgit.ai as a default, which my brief says to drop. Left to platform and the conductor. Also: an install that already has `Documents/Websites.json` (copied from the old defaults) keeps showing the old sites; `WebsiteDirectory.load` should drop riskmandate.ai and sgit.ai entries whose URL is unchanged from the old default.
5. Backlog: EventKit "add to calendar", App Intents ("What's next", "Save this session").

## Blocked

Nothing.

## Needs from others

- **Platform** (`App/`), three small hooks, or let me make them:
  1. `WebsiteBrowser.init`: after `let configuration = WKWebViewConfiguration()`, replace `configuration.websiteDataStore = .default()` with `TeamFeatures.shared.bridge.configure(configuration, for: homeURL)`, and after creating the web view `TeamFeatures.shared.bridge.attach(webView)`.
  2. `webView(_:didFinish:)` (add it): `TeamFeatures.shared.bridge.pageDidFinish(webView)`. In `decidePolicyFor`, before allowing: `if let url = action.request.url, TeamFeatures.shared.bridge.handlesNavigation(to: url) { decisionHandler(.cancel); return }`. Design's `WebPage` needs the same three lines.
  3. After each agenda refresh in `ReaderStore`: `TeamFeatures.shared.agendaDidLoad(events)`; and route `toggleSaved`/`isSaved` to `TeamFeatures.shared.schedule.toggle(event)` / `.isPicked(event)`, `saved` to `schedule.picks.compactMap(\.event)`. `NowNextPublisher.publish(saved:)` can take the same.
  4. Info.plist: `WKAppBoundDomains` = promptugal.news, web-summit.sgit.ai (stops WebKit purging the schedule after 7 days). Time Sensitive Notifications capability (reminders ask for `.timeSensitive`).
- **Design:** `.teamFeatures()` on `AppShell()`, and the destinations above. `CalendarExport` needs `NSCalendarsWriteOnlyAccessUsageDescription` (platform, Info).
- **Vault session:** when a team vault opens, call `TeamFeatures.shared.identity.verify(by: vaultID, person:)`; picks from the vault's `agenda/picks` go to `TeamFeatures.shared.schedule.merge(document)`, and `schedule.document` is what to write back.

## Apple setup for the native top-up

1. App Store Connect: two consumables, `news.promptugal.reader.credit.5` (£5 of credit) and `news.promptugal.reader.credit.20` (£20), with a price tier, display name and review screenshot each.
2. The Paid Apps agreement signed, with banking and tax.
3. The In-App Purchase capability on the app id.
4. Local testing works now with platform's `PrompTugal/Store/PrompTugal.storekit` on the scheme.
5. Review note: credit is for the reading meter on promptugal.news; the web Stripe link is hidden in the app (rule 3.1.1).

## Trade-offs

- **Data stores:** promptugal.news stays on the default store, because every earlier build kept its schedule, meter and vault session there. web-summit.sgit.ai moves to its own store, so its earlier `ws.me` and any `ws-keyring` keys stay behind: the app writes `ws.me` from the native identity, and each person re-opens their `#key=` link once.
- **Bridge in its own world:** page scripts cannot see a handler in another content world, so `window.ptApp.call()` relays through a DOM event to the app's bridge-world script. The origin check is native, on the real frame.
