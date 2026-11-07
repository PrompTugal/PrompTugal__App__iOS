# Status · Team · App Review readiness

> All eight items on the team list are coded and pushed (night/team 9471fa9), with tests; waiting for the unit-test run on night/team. Three small follow-ups are with platform and design. Two product questions for Dinis: the currency of reading credit, and the refund policy.

Branch: `night/team` (merges `origin/dev`, never rebased) · Last update: 14:45 UTC

## Done (code and tests pushed; CI below)

1. **Q1, crash on hostile pick times.**
   - `WirePick.init(from:)` drops a pick whose `at` is outside 1 January 2000 to 1 January 2100 UTC, not finite, missing or unreadable.
   - `ScheduleTime.format` clamps to years 1–9999 before any `Int64(...)`.
   - A bad date saved by an older build is dropped when `ScheduleStore` loads, so the app cannot crash at every launch.
   - The team JSON reader no longer traps on `Int(1e300)` (`TeamNumbers.int`).
   - Tests: `1e300`, `-1e300`, `-1`, `0`, beyond 2100, `"NaN"`, `"Infinity"`, `"1e300"`, `"tomorrow"`, the 2000 and 2100 boundaries, `format` of NaN, ±∞ and ±`greatestFiniteMagnitude`, and a poisoned `schedule.json`.
2. **Q3, credit lost on a failed save.**
   - `MeterStore.save()` throws.
   - `addCredit` rolls back and throws when it cannot save.
   - `CreditStore` finishes a transaction only after the credit is saved. Otherwise it leaves it unfinished, so StoreKit offers it again at the next launch.
   - StoreKitTest tests use `Store/PrompTugal.storekit` (`SKTestSession(contentsOf:)`): products load with the store's price; a saved credit finishes the transaction; a failed save leaves it in `Transaction.unfinished`.
   - **Refund and revocation policy** (in `CreditStore.handle`):
     - Reading credit unlocks nothing, so a refund is not taken back from the website's meter.
     - A transaction that arrives already revoked is finished without credit.
     - An unverified transaction is left to StoreKit.
     - Apple handles the money. The app keeps only the transaction id as the meter's reference.
3. **R5, purchases.**
   - The price shown is `Product.displayPrice` (unchanged).
   - The StoreKit file now matches what the app credits: `credit.5` is "£5 of reading credit" at 4.99, and `credit.20` is "£20 of reading credit" at 19.99. A test checks that every pack's description names the amount the app credits.
   - **Reading credit is hidden in Release** behind one flag, `ReadingCredit.isAvailable`. It covers the top-up sheet, the bridge's `meter.topup` (refused), the "Top up in the app" button on the page (not injected; the page says top-ups are not available in the app), and the shell entry (design, below).
   - Debug builds keep everything.
4. **Q6, reminder taps.**
   - `ReminderScheduler.installNotificationDelegate()` is ready for `PrompTugalApp.init` (platform, below).
   - A tap is held by `ReminderInbox` until the app is up, then opened as `promptugal://open/team.schedule?session=<slug>` (or `?url=<briefing>`) through the system, so it reaches `AppShell.route`.
5. **Guideline 3.1.1, checkouts.**
   - `Bridge/CheckoutPolicy.swift` is the one list: every `*.stripe.com` and `*.stripe.network` host, PayPal, Checkout.com, Lemon Squeezy, Gumroad, Paddle, Buy Me a Coffee, Ko-fi, Patreon, Square, Google Pay web, Shopify checkout, and the website's `/account/top-up.html`. Hosts match by suffix.
   - `AppBridge.handlesNavigation(to:)` uses it, and both the website browser and design's `WebPage` call it.
6. **S7, bridge.**
   - `notify.plan` never shows the system prompt. If permission was never asked, the app shows its own "Turn on reminders?" alert, and the prompt follows only a tap on it.
   - The ask-once rule fires only for a pick made in the app or for choosing who I am, never for a change from a page or the vault.
   - `schedule.get` is limited to promptugal.news.
   - A credit counts as done only when the bridge's own content world, which page scripts cannot patch, reads the transaction id in the page's meter. The page's "already" answer alone no longer counts.
7. **Q8, one copy.**
   - `TeamStore` goes through `HTTPClient.shared`, with one label per file (`team.me`, `team.meetings`, `team.data.<id>` …), so its requests appear in Debug → Network.
   - `Lisbon.day(_:)` (`Schedule/LisbonDay.swift`) replaces `DayPlanner.lisbonDay`; there is no other copy left in my folders.
   - Proposed to design and collab: team models in `Team/TeamModels.swift`, base URL `TeamEndpoints.base`, day `Lisbon.day`.
8. **Q10, tests** (`PrompTugalTests/AppReviewTests.swift`, `ScheduleTests.swift`):
   - The bridge gate: wrong host, look-alike hosts, iframe, http, ports 80 and 8443, unknown op, per-op hosts, with allowed controls. The origin decision is now a pure `AppBridge.gate(...)` that the handler calls first.
   - The checkout hosts.
   - `MeterStore`.
   - StoreKit, and the StoreKit file.
   - `ReminderScheduler` (lead time, toggles, saved settings) and reminder links.
   - `PlannerStore` (proposals, accept, teammates, cache).
   - TeamStore labels, and `Lisbon.day`.
   - **Live check** (`Tools/bridge-e2e`, Chromium, 14:36 UTC):
     - Every injected script passes, including the new credit confirmation (true for a real credit, false for an unknown reference).
     - Release mode offers no app purchase, and Stripe stays hidden.

## CI

- Run 217: a compile error (`AppBridge.Gate` has no `message`), fixed in c6a7719. Run 218 built.
- Run 227 (hand-started, unit tests): 154 tests, 4 issues. One was a reminder-tap race, fixed with `ReminderInbox.hold`. The other three are StoreKit.
- Run 235 (3a59e95): 151 tests pass on iPhone and iPad. The 3 StoreKit tests fail because `SKTestSession(contentsOf:)` loads the file without an error but returns no products on the CI simulator.
- 92446ca: the StoreKit tests record "no products" as a known issue and stop. When products load, every check runs. The rule they cover (no save, no finish) is also tested in the meter tests. Hand-started run queued.

## In progress

- Reading the CI result and fixing anything red.

## Needs from others

- **Platform** (Q6): add `ReminderScheduler.installNotificationDelegate()` to `PrompTugalApp.init`, next to the background task registrations. Optional: replace its private `lisbonDay` with `Lisbon.day`.
- **Platform** (Q3, tests): set `PrompTugal/Store/PrompTugal.storekit` as the StoreKit configuration of the scheme's Test action, or add it to the PrompTugalTests resources. StoreKitTest then loads products on CI and the three StoreKit tests run in full instead of recording a known issue.
- **Design**:
  - (R5) show `team.store` only when `ReadingCredit.isAvailable`.
  - (3.1.1) keep `handlesNavigation(to:)` on every navigation in `WebPage`, including `target=_blank`.
  - (Q6) `AppShell.route` can read the `session` query to open the session itself.
  - (Q8) use `TeamEndpoints.base`, and say whether `Wire.*` moves onto `TeamModels` now or next.
- **Collab** (Q8): `AIContext.lisbonDay` → `Lisbon.day`; the base URL → `TeamEndpoints.base`; the team data → `TeamStore` / `TeamModels`.

## Questions for Dinis (not decided here)

1. **Reading credit** (already on the decisions list): a tip, or credit that does something native? Until then it is hidden in Release.
2. **Currency and price.** The website's meter counts in pounds; the StoreKit file's storefront is Portugal (euros). Today £5 of credit costs 4.99 in the storefront's currency. Which currency and which price points?
3. **Refunds.** The policy above does not take a refunded top-up back from the meter. Confirm, or ask for refunds to be reversed.

## Blocked

Nothing.
