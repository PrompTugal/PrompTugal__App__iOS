# Debrief: the credit lane (appdev.credit@promptugal.dinis)

> Hand-over for a fresh session that knows nothing. Written 16 November 2026, ~15:30 UTC, when Dinis paused the PrompTugal agents to move them to other accounts. Worker for conductor.a.ios@promptugal.dinis. No keys or credentials appear here, and none are needed for this lane.

## 1. Mandate

Dinis, 15 Nov 23:55: "the iOS app, the same as the website, has to have a monetisation angle straight away: like VoiceDebrief and SGit, everything we do is paid, on the website and in the app, and people pay for usage."

The brief from the conductor:

1. A usage meter in the news app (PrompTugal, `news.promptugal.reader`) that matches the website's: the same prices for the same kinds of reading, the same starting balance, a balance chip, a history of charges, and the cost shown before it is spent.
2. Top-ups with StoreKit 2, reusing the Team app's consumables. Never fake a purchase; say clearly when a purchase is a test.
3. A public hook other screens call to charge (the Places reader, AI, Talk).
4. Later round (Dinis, via the conductor): reading revenue should eventually flow to local media, so attribute each paid read to its outlet and show "Where your credit goes", labelled as planned, never implying money was sent.

## 2. What this lane owns

| Path | What |
| --- | --- |
| `Packages/PTLocal/Sources/PTLocal/Credit/MeterConfig.swift` | The website's meter config (sg-meter v1.5) and the pricing formula |
| `Packages/PTLocal/Sources/PTLocal/Credit/CreditKind.swift` | What can be charged, the price list, outlet attribution, the string-based `named(...)` |
| `Packages/PTLocal/Sources/PTLocal/Credit/CreditBook.swift` | The ledger as a value (adapted from VoiceDebrief, Apache-2.0, attribution in the header), money formatting, `byOutlet()` |
| `Packages/PTLocal/Sources/PTLocal/Credit/LocalCredit.swift` | `LocalCredit.shared`: the public hook, persistence, live price refresh |
| `Packages/PTLocal/Sources/PTLocal/Credit/LocalTopUps.swift` | StoreKit 2 top-ups (ported from `Apps/Team/Sources/Store/CreditStore.swift`) |
| `Packages/PTLocal/Sources/PTLocal/Credit/CreditViews.swift` | `CreditChip`, `CostTag`, `LocalCreditView`, `PlannedBadge`, `.chargesCredit(_:)` |
| `Packages/PTLocal/Sources/PTLocal/Resources/billing-meter.json` | Built-in copy of `https://promptugal.news/api/v1/billing/meter.json` (site v0.1.1514) |
| `Packages/PTLocal/Tests/PTLocalTests/CreditTests.swift` | Pricing, ledger, top-up, persistence, refresh, string hook, outlets |

Small hooks outside the folder (other lanes own these files, so keep edits minimal):
- `Apps/PrompTugal/PrompTugalApp.swift`: `LocalCredit.start()` in `init()`.
- `Apps/PrompTugal/Shell/Destinations.swift`: More, `local.credit` opens "Reading credit" (`LocalCreditView`). It is also reachable from `PublicSettingsView`.
- `Apps/PrompTugal/PrompTugal.xcodeproj/xcshareddata/xcschemes/PrompTugal.xcscheme`: `StoreKitConfigurationFileReference` → `../../../Team/Sources/Store/PrompTugal.storekit` (Run and Test actions).
- `Packages/PTLocal/Sources/PTLocal/NewsroomCentreView.swift`: `CreditChip()` in the toolbar.
- `Apps/PrompTugal/Shell/PlacesWiring.swift` (owned by appdev.wire@): sets `PlacesCredit.charge` / `.costText` from `LocalCredit`.

Branch: `work/credit` (head 2d1e7b6 before this debrief, all merged into `dev`). `night/credit` is obsolete: do not push there.

## 3. How it works

**Prices.** `MeterConfig` decodes the site's `meter.json`: `start` (500 = £5.00, in pence), `floor` (1p), `minDepth` (0.1), `prices` (precomputed table, `type` and `type_tier`), `types` (`base`, `decays`, `as`), `tiers` (fresh ≤1 day ×2, new ≤7 ×1.5, current ≤30 ×1, archive ×0.5). The price is `max(floor, round(base × multiplier))`, read from the site's table first and computed only if a pair is missing. JavaScript `Math.round` rounds halves up, and Swift's `.toNearestOrAwayFromZero` matches for positive amounts (company "new" = 4.5 → 5p). A page with no date gets the base price. The age is measured from midnight UTC of the page date, as `Date.parse` does in the browser. Load order: this device's cached live copy, then the built-in file, then a hard-coded fallback. `refreshPrices()` reads the live file at launch and when the credit screen opens. The price list footer shows where the prices came from (`ProvenanceLabel`).

**Units.** Micro-credits (1/1,000,000 £; a penny = 10,000), whole numbers, as VoiceDebrief does. `CreditMoney.money` / `.price` format "£4.96", "2p", "free".

**What is charged** (the conductor's decision, 16 Nov 00:28: browsing is free):

| App action | Site page-type | Price | Rule |
| --- | --- | --- | --- |
| `story` (a story's full detail opened) | `story` | 1–4p by freshness | once per session per ref |
| PrompTugal.news's own article (Places passes `"article"`) | `article` | 3–12p by freshness | once per session per ref |
| `ai.summary` | `topic` | 3p | once per session per thing |
| `talk` (a question to a town's agent) | `article`, base | 6p | every time |
| `contribution` | `evidence` | 1p | every time |
| towns, the newsroom, lists | (kinds exist: `place`, `site`, `data`) | | not charged |

As on the website, nothing is ever blocked. The balance may go below zero, and `charge` returns only whether a charge was written. Never gate content on it.

**Public API** (in `LocalCredit.shared`):
- `charge(kind: CreditKind) -> Bool`, `cost(of:) -> Int` (micro), `costText(of:) -> String` ("2p", "free", or "read" when already paid this session), `wouldCharge(_:)`.
- String form, for packages that do not import PTLocal: `charge(action:ref:date:title:outlet:)` and `costText(action:ref:date:)`. Actions: `"story"`, `"ai.summary"`, `"contribution"`, `"talk"`, or any site page-type (`"article"`, `"place"`…).
- `byOutlet: [OutletLine]`, `history`, `balanceText`, `topUps`.
- Views: `CreditChip()` / `CreditChip(compact: true)`, `CostTag(kind)`, `LocalCreditView()`, `.chargesCredit(kind)`.

**PTPlaces stays PTCore-only.** `Packages/PTPlaces/Sources/PTPlaces/PlacesCredit.swift` (owned by ios.places@) declares two closures. The app shell (`PlacesWiring.swift`) points them at `LocalCredit`. PTPlaces charges `"article"` when one of PrompTugal.news's own articles is opened (`PlaceDetailView.swift`) and `"contribution"` when a comment is sent (`Comments.swift`). It deliberately does not charge for third-party local outlets' stories, because Dinis wants to send readers to local media.

**Ledger.** `CreditBook` is an append-only list of entries: start, charge, topup, refund. The balance is the sum, and `addsUp` checks the running balances. It is saved as JSON at `Application Support/PrompTugal/local-credit.json`. A file that cannot be read is moved aside (`local-credit.unreadable-<ts>.json`), never overwritten, and the screen says so. A top-up is credited once per reference (`appstore-<transaction id>`, the same reference the Team app uses). A declined charge gets a refund entry with the reason. Nothing checks the file: it is the user's own device, like the site's meter in browser storage.

**Outlets.** `CreditKind.outlet` is set only for reads (`story`, `page.*`). It is the publisher if one is given, else the URL host without `www.`, and `promptugal.news` reads as "PrompTugal.news". AI summaries, questions, contributions and towns are never attributed. "Where your credit goes" lists the paid reads per outlet, less declined ones, under a `PlannedBadge` ("Planned, not yet paid"), and its footer says plainly that no money has been sent to any outlet. Older ledgers without `outlet` still decode.

**Top-ups.** `LocalTopUps` sells `news.promptugal.reader.credit.5` (500p) and `news.promptugal.reader.credit.20` (2000p). `LocalCredit.start()` starts listening to `Transaction.updates` and replays `Transaction.unfinished`. A transaction is finished only after the credit is saved; an unverified one is left to StoreKit; a revoked one is finished without credit. `AppTransaction.shared.environment` tells Xcode, sandbox or production apart, and each top-up's `source` records it (`appstore:xcode` / `appstore:sandbox` / `appstore:production`). Anything other than production is labelled "Test purchase, no money taken" on the screen and in the history. Top-ups are on in Release too, which the conductor confirmed: the app is internal TestFlight only and Dinis wants it paid from day one.

## 4. State

**Done, on `dev`, green.** The credit tests passed in candidate run 553 and dev runs 554–564 (the last checked was 564, `f348331`, 16 Nov 05:54).

**Open:**
1. **App Store Connect in-app purchase products are still needed.** Create the two consumables for the reader app (`news.promptugal.reader`) with exactly these ids: `news.promptugal.reader.credit.5` (£5 of reading credit) and `news.promptugal.reader.credit.20` (£20). The Paid Apps agreement must be signed. Until they exist, TestFlight builds show "Top-ups are not available from the App Store yet." The Xcode `.storekit` file works only when run from Xcode with the PrompTugal scheme. Check whether the Team app (`news.promptugal.team`) already registered these ids: product ids are unique per account, and the Team app's `CreditStore` uses the same ones.
2. **The AI summary and talk charges are not wired.** `.aiSummary(of:title:)` and `.talk(to:)` exist and are tested, but no screen in `PTLocal/AI/` or `PTTalk` calls them yet. Wiring them is a one-line `LocalCredit.shared.charge(kind:)` plus a `CostTag` beside the button, but those files belong to the AI and Talk lanes, so coordinate through the conductor.
3. **`CreditChip(compact: true)` is not placed on the Places home yet.** wire@ was to put it in `PlacesWiring` / the places home accessory.
4. **Outlets in practice show only PrompTugal.news**, because PTPlaces charges only for its own articles. If local outlets' stories should become paid reads, or if PlacesCredit should pass a publisher (a fifth closure argument), that is ios.places@'s and Dinis's call.
5. **Not built yet:** syncing the ledger across devices or into the user's vault (VoiceDebrief's design allows it), and the site's usefulness rating ×0–×2 (`rating` in meter.json is decoded nowhere).

## 5. How to work here

- No Mac in the session: CI is the compiler. **Push only to `work/credit`.** Do not push `night/**` and do not dispatch runs (conductor rule, 16 Nov 00:31: the shared macOS runners were flooded). Tell the conductor "ready at <sha>" at most hourly; the conductor integrates every lane and runs one build.
- Read failures from the integration build: `actions_list` → find the run on `night/going-local`, `work/candidate` or `dev`; `actions_get get_workflow_run_logs_url`; `curl` the zip into the scratchpad, unzip, then `grep -rh "error:\|✘"`. `get_job_logs` with a tail misses the build step: the errors sit in the middle of a long log.
- Commit trailers: `Agent: appdev.credit@promptugal.dinis` / `For: conductor.a.ios@promptugal.dinis`.
- Never push to `dev` or `main`. Merge `origin/dev` into `work/credit` before a new round.
- Apple SDK only. No secrets. Nothing simulated without saying so.

## 6. Lessons learned

- **@Observable init:** reading a stored property (`config`) before every stored property is set is a use of `self` and does not compile. Build on locals, then assign (run 535).
- **A helper that clears state in the init:** `write()` reset `problem = nil` on success, which wiped the "unreadable ledger" note set just before it (run 547). Set such notes after the first save.
- **Don't edit other lanes' screens.** My first hooks into `LocalViews.swift` / `TownView.swift` clashed with night/live and were reverted at the conductor's request. Expose a hook and let the owner or the shell call it.
- **Keep packages independent:** a string-based closure (`PlacesCredit`) let PTPlaces charge without importing PTLocal.
- **Check the site's page types.** PrompTugal.news's own articles are `article` (6p base), not `story` (2p). Town pages are `place`, the newsroom is `site`: curl a page and read `<meta name="page-type">`.
- **A push to a new branch did not always trigger `ios.yml`.** Don't work around it with dispatches; leave it to the conductor's integration build.

## 7. First things the next session should do

1. Read this file, `briefs/2026-11-15__going-local/tonight.md`, `README.md`, and `Packages/PTLocal/Sources/PTLocal/Credit/`.
2. `git fetch origin dev && git checkout work/credit && git merge origin/dev`.
3. Ask the conductor (or Dinis) whether the App Store Connect products (open item 1) exist. If not, put that at the top of the morning list.
4. Offer the AI and Talk lanes the one-line charge hooks (open item 2), and ask wire@ about `CreditChip(compact: true)` on the Places home (item 3).
5. Check that `https://promptugal.news/api/v1/billing/meter.json` still decodes (`version`, `start`, `prices`). If the site changed its prices, refresh `Resources/billing-meter.json` and make sure `formulaMatchesTable` still passes.
