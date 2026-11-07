# Status · iOS platform

> Done. CI builds and tests the integrated app on an iPhone and an iPad simulator (124 of 124 unit tests pass on both) and screenshots all 13 screens on both devices; the project, targets, entitlements, privacy manifest and widget/Siri extensions are in place. Dinis must set the signing team and register the App ID capabilities before a device build or TestFlight.

Branch: `night/platform` (equal to `dev` at `44fbe3f`) · Last update: 09:15 UTC · Final for the overnight push

## What's on dev

**Project** (`PrompTugal.xcodeproj`, objectVersion 77)

- Folder-synchronized groups: any `.swift` file under `PrompTugal/` compiles, no project-file edit. Same for `Shared/`, `PrompTugalWidgets/`, `PrompTugalIntents/`, `PrompTugalTests/`, `PrompTugalUITests/`.
- iOS 18.0 minimum, iPhone and iPad. Version and build number set once at project level.
- Targets and bundle IDs: app `news.promptugal.reader`; widget `.widgets` (Now and next: small, medium, lock screen, reads the App Group); App Intents extension `.intents` ("Next session", Siri phrase "What's next in PrompTugal"); unit tests `.tests`; UI tests (screens).
- `Packages/SGitVault`: the vault session's package, linked into the app as a local package.
- Build settings live in `Config/PrompTugal.xcconfig` and `Config/PrompTugalWidgets.xcconfig`, with an optional, git-ignored `Config/Local.xcconfig` for signing.

**App code I own** (`PrompTugal/App/`)

- `PrompTugalApp.swift`: root is `AppShell()` with the reader store and team features; registers and schedules the background tasks (`VaultBackground`, `TeamBackground`).
- `HTTPClient.swift`: one client for every request; each lands in `HTTPLog.shared` (Debug → Network), URLs redacted.
- `BuildInfo.swift`: commit, branch, build time, CI run for Debug → Build (written by `Scripts/build-info.sh`).
- `ReaderStore.swift`, `Content.swift`, `NowNextPublisher.swift`, `TeamBackground.swift`, `Web/` (website browser through the team bridge, default shortcuts: promptugal.news, then web-summit.sgit.ai).
- `Resources/PrivacyInfo.xcprivacy`: UserDefaults (CA92.1), file timestamps (C617.1, DDA9.1), no tracking.

**Info and entitlements**

- `Config/PrompTugal-Info.plist`: URL scheme `promptugal`, background modes fetch and processing, BG task ids `news.promptugal.reader.refresh` and `.vault-refresh`, `WKAppBoundDomains` promptugal.news and web-summit.sgit.ai, `ITSAppUsesNonExemptEncryption = NO`, usage strings (Face ID, camera, microphone, speech, NFC, calendar write-only).
- `Config/PrompTugal.entitlements`: App Group `group.news.promptugal.reader`; associated domains `webcredentials:` and `applinks:promptugal.news`; time-sensitive notifications. `Config/PrompTugal-Basic.entitlements` has none of these, for a free personal team.
- `PrompTugal/Store/PrompTugal.storekit`: consumables `news.promptugal.reader.credit.5` (0.99) and `.credit.20` (2.99), on the scheme's Run action.

## CI facts

**`ios.yml`** (push to `dev` and `night/**`, pull requests, by hand)

| Job | Runs on | When |
|---|---|---|
| `Already on dev?` | Ubuntu, ~5 s | every run; on a `night/**` push whose commit is already on `dev`, it skips every macOS job |
| `App build and SGitVault tests` | `macos-26`, ~4 min | every run: `xcodebuild build` (simulator, unsigned), then `swift test` in `Packages/SGitVault` |
| `App unit tests (iPhone / iPad simulator)` | `macos-26`, ~9 min each | `dev`, pull requests, by hand only (not `night/**` pushes, for runner capacity) |

- Pushes that change only `briefs/`, `website/`, root Markdown or `VERSION` don't run it.
- Concurrency is per job: a started job always finishes; a queued one is replaced by the newer push's.
- Last result on `dev` (`8a060e8`, run 173): all green, **124 tests in 33 suites on iPhone and on iPad**.
- A failed step writes its `error:` lines to the job summary and repeats them at the end of the log, so `get_job_logs` with `tail_lines: 80` shows them.

**`screens.yml`** (push to `dev`, by hand)

- `ScreensTests` (scheme `PrompTugalScreens`): one test per destination, 13 ids, launched with `-PTDestination <id> -PTSampleData -PTMe ana`. iPad in landscape.
- Artifact `screens-<sha>` with `iphone-<id>.png` (736×1600) and `ipad-<id>.png` (1600×1103), longest side 1600 px, no EXIF/XMP. Exactly 13 per device or the job fails.
- iPad screenshots are the whole screen (`XCUIScreen.main.screenshot()`), turned upright from their own EXIF orientation, then stripped. Fixed at 08:35 (`0616379`); run 14 checked by me and by the editor in Chromium. The site publishes iPad from `dev` screens run 15 on.

**`ios-release.yml`** belongs to the release engineer (archives and TestFlight).

## What Dinis (or Silvio) must do

1. **Signing:** copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`, or pick the team in Xcode → Signing & Capabilities.
2. **App ID capabilities** for `news.promptugal.reader`, `.widgets` and `.intents` at developer.apple.com: App Groups (register `group.news.promptugal.reader`), Associated Domains, In-App Purchase, Time Sensitive Notifications. Xcode's automatic signing does this for an Admin.
3. **AASA on promptugal.news:** `/.well-known/apple-app-site-association` listing `<TeamID>.news.promptugal.reader` under `webcredentials.apps` and `applinks`. A change to the website, not this repo.
4. **App Store Connect:** create the two consumables with the IDs above before any TestFlight top-up test.
5. A free personal team can't sign App Groups or associated domains: set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` in `Config/Local.xcconfig` to build anyway.

## Next

1. **Swift 6 language mode.** The app is Swift 5 mode with complete concurrency checking (warnings). Clear the warnings, then switch; not started tonight.
2. **iPad unit tests on `night/**`** if runners allow: today they run only on `dev`, PRs and by hand.
3. **Screens:** add a destination → add a test method and update the count (13) in `ScreensTests.swift` and `screens.yml` together.
4. **Rules that still hold for everyone:** non-Swift files under `PrompTugal/` are copied into the bundle flat, so give them unique names; don't declare top-level types named like SDK types (`Section`, `Label`, …); make HTTP requests through `HTTPClient.shared`.

## Blocked

Nothing.
