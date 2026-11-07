# Status · iOS platform

> CI and the project are done and on dev; the app builds with every session's code. Since 06:00: screenshots on dev (screens.yml, one UI test per screen), per-job CI concurrency, and night/** pushes run the build only (unit tests on dev, PRs, by hand).

Branch: `night/platform` · Last update: 07:36 UTC

## Ready for other sessions

- **02:42 CI works.** `.github/workflows/ios.yml` builds the app on a `macos-26` runner, Xcode 26.6 (17F113), Swift 6.3.3.
- **02:48 The layout is ready.** The project uses folder-synchronized groups. Put new `.swift` files in your folder under `PrompTugal/` and they compile, with no project file edit. Your folder exists with a `.gitkeep`; leave it or delete it.
- **02:48 Minimum iOS is 18.0.**

## Rules for files in `PrompTugal/`

1. Every file under `PrompTugal/` is in the app target. Swift files compile. **Any other file is copied into the app bundle, flat.** Two files with the same name in different folders (two `README.md`, two `data.json`) break the build with "Multiple commands produce". Keep notes and docs outside `PrompTugal/`, and give resources a unique name, e.g. `Team-sample-me.json`.
2. Don't declare top-level types with common names. A module-level type shadows SDK types everywhere in the app. **Design: please nest the section type as `Destination.Section`**, not a top-level `Section`, or every SwiftUI `Section { }` in the app breaks. The same goes for `Label`, `Link`, `Text`, `Image`, `Color`, `Button`, `List`, `Group`, `Task`, `Error`.
3. Language mode is Swift 5 with complete concurrency checking (warnings). I plan to move to Swift 6 mode once the first features land; write code that has no concurrency warnings and the switch costs nothing.
4. Unit tests go in `PrompTugalTests/` (Swift Testing, `@testable import PrompTugal`). Any file there is picked up.

## How to read a CI failure

1. `actions_list` → `list_workflow_runs`, `resource_id: ios.yml`, branch `night/<you>`, `perPage: 1`.
2. `actions_list` → `list_workflow_jobs` with the run id.
3. `get_job_logs` with the failed job's id, `return_content: true`, `tail_lines: 80`. A failed step ends with `===== … failed. Errors: =====` and the `error:` lines, above about 40 lines of post-job noise.

Jobs: `App build and SGitVault tests` (the build, then `swift test` for the package) on every push. `App unit tests (iPhone simulator)` and `App unit tests (iPad simulator)` run on `dev`, pull requests and by hand (Actions → iOS → Run workflow, pick your branch); since 07:15 not on night/** pushes, for runner capacity. Every feature must work on both. Artifacts belong to the release engineer's `ios-release.yml`.

## Done

- **CI** (above).
- **iOS 18.0** deployment target, project and targets.
- **Folder-synchronized groups**, `objectVersion 77`. Existing files moved, no code changes: `App/PrompTugalApp.swift`, `App/Content.swift`, `App/ReaderStore.swift`, `App/Web/WebsiteView.swift`, `App/Web/WebsiteShortcuts.swift`, `App/Resources/Websites.json`, `App/Resources/Assets.xcassets`.
- **`PrompTugalTests`** target, run by the shared scheme: Lisbon time (winter, summer, bad input), event ranges past midnight, detail URLs, `Websites.json`, build info, HTTP client redaction and log cap.
- **`PrompTugal/App/HTTPClient.swift`** (contracts §8): `HTTPClient.shared.get(url, label:)`, `decode(_:from:label:)` and `data(for:label:)`. Every request lands in `HTTPLog.shared` (`@MainActor @Observable`): method, redacted URL (no user, password or fragment; query values shown as `…`), host, label, status, bytes, ms, error. Newest first, 1,000 kept, with running totals. `FeedClient` uses it. **Everyone: make HTTP requests through `HTTPClient.shared`, not `URLSession.shared`,** so they show in Debug → Network.
- **Build info** for Debug → Build: `BuildInfo.current` has `commit`, `shortCommit`, `branch`, `dirty`, `commitDate`, `siteRelease` (from `/VERSION`), `builtAt`, `builder` (`ci` or `local`), `ciRun`, `appVersion`, `appBuild`, and `rows` for a list. Written at build time by `Scripts/build-info.sh` into `BuildInfo.json` in the bundle.
- **`Packages/SGitVault`**: no `night/vault` branch existed at 02:47, so I pushed a compiling skeleton of contracts §5 (stubs throw `.notImplemented`) and linked it into the app. **Vault: start from `origin/night/platform` (or `dev` once merged) and replace the files freely.**
- **Capabilities groundwork:** `Config/PrompTugal.entitlements` (App Group `group.news.promptugal.reader`; `webcredentials:promptugal.news`, `applinks:promptugal.news`), wired through `Config/PrompTugal.xcconfig`. `PrompTugal/Store/PrompTugal.storekit` with consumables `news.promptugal.reader.credit.5` (0.99) and `.credit.20` (2.99), on the scheme's Run action. Usage strings for Face ID, camera, microphone, speech recognition and NFC.
- File-private reader types renamed with a `Reader` prefix (`ReaderDestination`, `ReaderSectionView`, …) so they can't clash with design's `Destination`.

## Since 02:55

- **Widget** `PrompTugalWidgets` (Now and next: small, medium, lock screen), reading `now-next.json` from the App Group. `Shared/` is compiled into the app and every extension.
- **App Intents extension** `PrompTugalIntents`: "Next session".
- **SGitVault**: the vault session's package, as is, linked into the app.
- **CI**: unit tests on an iPhone **and** an iPad simulator. A push no longer cancels a running run. The artifact job moved to release's `ios-release.yml`.
- **Default shortcuts**: promptugal.news, then web-summit.sgit.ai. Nothing else (conductor ruling).
- **Info and entitlements**: `ITSAppUsesNonExemptEncryption = NO`; `WKAppBoundDomains` = promptugal.news, web-summit.sgit.ai (in `Config/PrompTugal-Info.plist`); Time Sensitive Notifications; calendar write-only usage string.
- **Bundle IDs**: app `news.promptugal.reader`, widget `.widgets`, intents `.intents`, tests `.tests`. Version and build number are set once at project level.

**Design, note:** with `WKAppBoundDomains` set, WebKit allows script injection, user scripts and message handlers only on promptugal.news and web-summit.sgit.ai. Pages on other hosts still load, but script injection on them stops working.

**Team, note:** your code hooks in `App/` (WebsiteBrowser bridge, ReaderStore → `TeamFeatures`) go in as soon as `night/team` is on `dev`.

## In progress

- **07:15** For runner capacity, `night/**` pushes run only `App build and SGitVault tests` (1 runner). The unit tests run on `dev`, pull requests and by hand (Actions → iOS → Run workflow).
- **06:45** `screens.yml` (`dev` only): `ScreensTests` has one test per destination (13, design's ids). Each screenshot is kept before the `pt.destination.<id>` check, and only `.png` attachments are exported. Fixed on the way: dotted ids lost their tail in file names (run 4), the export picked up failure `.txt`/`.mp4` attachments (run 8), and iPad PNGs are rotated upright. Each device must produce exactly 13 PNGs.
- **06:00** Per-job concurrency in `ios.yml` and `screens.yml`: a job that has started always finishes; a job still waiting for a runner is replaced by the newer push's.
- **05:40** Integrated app (`c53c2c0`): iPad unit tests, 64 of 66 passed. The 2 failures were team's key-order tests, fixed in `500b5ad`.
- **07:36** Running on `dev`: iPhone unit tests (`991cbfa`) and iPhone screens (`d33acfe`, design's agenda fix). Results to the conductor when done.
- **05:40 Integration result** (`c53c2c0` on `night/platform`, which already held design, team and vault): app build and SGitVault tests green. Unit tests on iPad: **64 of 66 passed**. The 2 failures are team's key-order tests (`ScheduleTests.swift:34`, `:298`), fixed by team in `500b5ad` on `dev`. The conductor cancelled `dev` run 88 on purpose for the same reason. Per-job concurrency (`ios.yml` and `screens.yml`) is on `dev`, so started jobs now always finish.
- **04:25** The conductor merged the wiring with design and vault into `dev` (`3b77e1c`). `AppShell` is the root on `dev`. The first full integration run (88) is queued for runners.
- **04:28** **Screens** (design's request): `PrompTugalUITests/ScreensTests` opens the 12 main destinations with `-PTDestination <id> -PTSampleData -PTMe ana` and keeps a screenshot of each. It has its own scheme, `PrompTugalScreens`, so ⌘U and `ios.yml` still run only unit tests. `.github/workflows/screens.yml` runs on `dev` and by hand, on one iPhone and one iPad. It uploads `screens-<sha>` with `iphone-<id>.png` and `ipad-<id>.png`, longest side 1600 px (the editor's contract).
- **04:31** **Privacy manifest** (release's TestFlight blocker, ITMS-91053): `App/Resources/PrivacyInfo.xcprivacy` declares UserDefaults (CA92.1) and file timestamps (C617.1, DDA9.1), no tracking. A unit test checks it ships. The extensions call no required-reason APIs.
- **04:24** CI uses 3 macOS runners per push instead of 4: SGitVault's `swift test` runs inside the build job.
- **04:09** The conductor merged design, team and vault into `dev`. I merged `dev` into `night/platform` and pushed the wiring in one commit (`5365593`):
  - `AppShell()` is the root view, with `.environment(store)` and `.teamFeatures()`.
  - `WebsiteBrowser` goes through the team bridge: `configure`, `attach`, `pageDidFinish`, and `handlesNavigation` (in-page and new-window links).
  - `ReaderStore`: saved sessions are the schedule's picks. Each agenda refresh, and the cached agenda at launch, go to `TeamFeatures.agendaDidLoad`, which also feeds the widget.
  - Background tasks: `VaultBackground` and `TeamBackground` (`news.promptugal.reader.refresh` → `TeamFeatures.refreshTeam()`), registered in `PrompTugalApp.init` and scheduled when the app goes to the background.
- Before that, from 03:45: the vault's background-refresh wiring (merged earlier, now on `dev`). Not yet through CI: the `promptugal://` URL scheme (the shell's deep links reach the app), the widget opening `promptugal://open/team.schedule`, and Siri phrases ("What's next in PrompTugal").
- Before the merge I trial-merged design, team and vault locally: no conflicts, no duplicate type names, no clashing extension members, no resource name collisions.
- Watching dev's integration run (79) and mine.

**Design, please:** `Shell/WebPage.swift` has none of the bridge hooks, so its pages get no `pt` bridge or schedule sync, and the Stripe top-up isn't intercepted. Same changes as in `WebsiteBrowser`: `bridge.configure(configuration, for: url)` instead of `.default()`, `bridge.attach(webView)`, `bridge.pageDidFinish(webView)` in `didFinish`, `bridge.handlesNavigation(to:)` in `decidePolicyFor`.

## Next

1. Swift 6 language mode.
2. Widget extension (Now and next) reading the App Group.
3. App Intents skeleton.
4. Fold in other sessions' folders as they land; rebase on `origin/dev` hourly.

## Needs from Dinis or Silvio (Apple team)

- **Signing:** copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`, or pick the team in Xcode.
- **App ID capabilities** for `news.promptugal.reader` at developer.apple.com: App Groups, Associated Domains, In-App Purchase. Register the group `group.news.promptugal.reader`. Xcode's automatic signing can do this for an admin.
- **AASA on promptugal.news:** `/.well-known/apple-app-site-association` listing `<TeamID>.news.promptugal.reader` under `webcredentials.apps` (passkeys, D3) and `applinks`. That is a change to the promptugal.news site, not this repo.
- **App Store Connect:** create the two consumable products with the same IDs before any TestFlight top-up test.
- A free personal team cannot sign App Groups or associated domains. To build anyway, set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` in `Config/Local.xcconfig`.

## Blocked

Nothing.

## Needs from others

- **Design:** nest `Section` inside `Destination` (rule 2 above).
- **Everyone:** use `HTTPClient.shared` for HTTP; unique names for non-Swift files.
