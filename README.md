# PrompTugal

SwiftUI beta for iPhone and iPad. Version 0.3.1 opens the live [PrompTugal website](https://promptugal.news/) with a sidebar for switching between the PrompTugal website and the team site. Use the book icon in the bottom bar for the native agenda, saved sessions, and cached news. The project targets iOS and iPadOS 18 and later and uses the system SDK without third-party packages.

## Run from Xcode

1. Open `PrompTugal.xcodeproj` on a Mac with Xcode 26 or later.
2. Select the **PrompTugal** scheme and an iPhone or iPad simulator, then choose **Product → Run**.
3. For a physical device or a TestFlight archive, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` (or pick your team in **Signing & Capabilities**). Confirm that `news.promptugal.reader` is available to your team or change the bundle identifier. See [Building and CI](#building-and-ci) for the capabilities the app asks for.

For a command-line simulator build from this directory:

```sh
xcodebuild -project PrompTugal.xcodeproj -scheme PrompTugal \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Building and CI

**Layout.** The Xcode project uses folder-synchronized groups (Xcode 16 and later). Every file under `PrompTugal/` belongs to the app target and every file under `PrompTugalTests/` to the unit tests, so adding a Swift file needs no change to `project.pbxproj`.

| Path | What it holds |
| --- | --- |
| `PrompTugal/App/` | App entry, reader, HTTP client, build info, web views (`Web/`), resources (`Resources/`) |
| `PrompTugal/<Feature>/` | One folder per feature: Shell, Design, Dashboards, Debug, News, Schedule, Bridge, Team, Notifications, Store, Vault, AI, Lanes, Coordination |
| `PrompTugalTests/` | Unit tests (Swift Testing), hosted in the app |
| `Packages/SGitVault/` | The Swift vault reader, a local package with its own tests |
| `Config/` | Base build settings, entitlements, an example for your local signing settings |
| `Scripts/build-info.sh` | Build phase that writes `BuildInfo.json` (commit, branch, site release) into the app |

Resource files are copied flat into the app bundle, so two files with the same name in different folders (two `README.md`, say) break the build. Keep notes outside `PrompTugal/`.

**Capabilities.** `Config/PrompTugal.entitlements` asks for the App Group `group.news.promptugal.reader` and the associated domains `webcredentials:promptugal.news` and `applinks:promptugal.news`. In-App Purchase is enabled on the App ID and needs no entitlement key. A free personal team cannot sign these, so set `PT_ENTITLEMENTS = Config/PrompTugal-Basic.entitlements` in `Config/Local.xcconfig` to build without them.

**StoreKit testing.** The scheme’s Run action uses `PrompTugal/Store/PrompTugal.storekit`, with two consumables: `news.promptugal.reader.credit.5` and `news.promptugal.reader.credit.20`. Purchases in the simulator or a debug build go to this local file, not to the App Store.

**Tests.** In Xcode, **Product → Test** (⌘U). From the command line:

```sh
xcodebuild test -project PrompTugal.xcodeproj -scheme PrompTugal \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
(cd Packages/SGitVault && swift test)
```

**CI.** `.github/workflows/ios.yml` runs on every push to `dev` and `night/**`, and on pull requests, on a macOS runner with the newest stable Xcode. Its jobs are `App build and SGitVault tests` (the simulator build, then `swift test` for the package on the same runner) and `App unit tests`, which runs on an iPhone and an iPad simulator. Release artifacts (archives, `.ipa`, simulator app) come from `.github/workflows/ios-release.yml`. A failed step writes its `error:` lines to the job summary and repeats them as the last lines of the step’s log, so they can be read with a short log tail.

## Distribute a private beta

CI can sign and upload for you: see [the release setup](briefs/2026-11-08__overnight-push/release-setup.md) (morning checklist at the top). The steps below are the manual Xcode route.

1. Create an iOS app record in App Store Connect using the bundle identifier in Xcode.
2. Select a generic iOS device as the run destination. Choose **Product → Archive**, then **Distribute App** from Organizer and upload to App Store Connect.
3. Add the processed build to an internal TestFlight group. Use the standard upload flow to keep the build eligible for external groups.
4. For testers outside your App Store Connect team, add the build to an external group, fill out the beta test information, and submit it for TestFlight App Review. Invite testers by email after approval. Increment the build number for each upload.

[Apple’s TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) · [External tester setup](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

## Configure the website shortcuts

On iPad, the sidebar appears beside the current website and the sidebar button toggles it. On iPhone or in a narrow window, the same button opens the list in a sheet. Each shortcut keeps its own page and back history while the app is running.

- To change the bundled defaults in Xcode, edit `PrompTugal/App/Resources/Websites.json`.
- To customize one device without rebuilding, launch PrompTugal once, then edit or replace `Websites.json` under **Files → On My iPad** (or **On My iPhone**) **→ PrompTugal**. Quit and reopen the app. Delete the local copy and reopen to recreate it from the bundled defaults.
- Each entry has a unique `id`, a display `name`, an HTTPS `url`, an SF Symbols `icon` name, and a `color`. Supported colors are red, orange, green, teal, blue, indigo, and purple. The array sets the sidebar order and its first entry opens at launch. Invalid local JSON falls back to the bundled shortcuts. Optional `iconAsset` selects a bundled image and `iconText` supplies a text badge. A custom shortcut can keep using its SF Symbol.
- Existing 0.3.0 configurations still load. The original summit-team URL is updated to web-summit.sgit.ai on launch, with custom entries and order preserved.

Sidebar artwork comes from the [PrompTugal icon](https://promptugal.news/assets/brand/icon-512.png) and the [Web Summit team's road-trip badge](https://web-summit.sgit.ai/assets/stickers/vote/01-road-trip-patch-v1.webp). Devices that already have a `Websites.json` in Files keep their own list.

## Website and device storage

PrompTugal opens live websites on iPhone and iPad, so website releases appear in the app without rebuilding it. WebKit uses its persistent store for the site's cookies and local storage. The website already uses local storage for schedule picks, theme, and profile state. This storage belongs to the app on the current device and is separate from Safari and the native reader's bookmarks.

The live website needs a connection. The native reader keeps its previous bookmark and content files across app updates. Open the native reader online once to fill its cache before relying on it offline.

## What to test

- Upgrade from 0.3.0 without removing the app. Check that the second shortcut points to web-summit.sgit.ai and the sidebar displays the new artwork with the existing JSON.
- Select all five shortcuts, then revisit a site after opening an article and check that the page and Back history are still there.
- Reorder shortcuts and add an HTTPS entry in the local `Websites.json` in Files. Relaunch and check that the new first entry opens. Try an invalid file and confirm the sidebar shows the defaults with a notice.
- Open the live site, change its theme and save a session to the website's schedule. Force quit, reopen, and verify that the website remembers both.
- Open a same-site article and use Back, Reload, and Home. Confirm that a tapped external source link opens outside the app.
- Try the website on an iPhone and iPad in portrait, landscape, and a narrow multitasking window. With airplane mode enabled, check that Offline Reader is accessible if the site fails to load.
- In Offline Reader, verify that the app still shows bookmarks saved in version 0.1.0 when installed over that build with the same bundle identifier.
- On iPhone, browse Now, search for a venue in Agenda, and open a session.
- On iPad, select an item in the list and confirm the detail appears alongside it. Try portrait, landscape, and a narrow multitasking window.
- Save a session online, turn on airplane mode, force quit, and reopen. Check that Saved still shows the title, time, and venue. Open a session online before going offline to cache its original source details.
- Check a session that ends at midnight and switch the device time zone. Agenda times should stay in Lisbon time.
- After a refresh failure, check that cached content stays visible and the previous sync time remains on screen. On first launch without connectivity, check that Refresh can recover when connectivity returns.
- Browse News and open a full article. Story summaries are cached after a successful sync. Full articles and the complete web agenda require a connection.

## Content

The offline reader reads the [live agenda](https://promptugal.news/api/v1/live/agenda.json), individual [event records](https://promptugal.news/api/v1/events/registration-2026-11-09.json), and [news RSS](https://promptugal.news/feed.xml). The live agenda is the 9–12 November 2026 summit feed and carries a subset of the [website’s side events](https://promptugal.news/events/index.html). The app links directly to the full agenda. Now shows upcoming sessions when the feed has them and directs users to past sessions in Agenda after the summit.

Bookmarks and the last successful feed responses are stored on each device. Content and app icon come from PrompTugal.news. PrompTugal’s coverage is independent of Web Summit.

## Product website

`website/` builds the static product site for [ios.app.promptugal.news](https://ios.app.promptugal.news/) into `website/public/`. It uses Python's standard library only, ships no JavaScript and loads no third-party assets.

```sh
python3 website/build.py                      # regenerate website/public/
python3 website/validate.py                   # refuse broken links, missing twins, drift
python3 -m unittest website/test_site.py      # validator rules with negative controls
```

- Edit pages in `website/pages/` (each is the `<main>` body plus a front-matter comment). The shared shell is `website/template.html` and the styles are in `website/site.css`.
- App facts are read from the Xcode project on every build and never typed by hand. These are the version, build, minimum iOS, bundle ID, Swift line count and the `Websites.json` list. Artwork is copied from the asset catalog. Bump `MARKETING_VERSION` and rebuild, and the site follows.
- Every page gets a Markdown twin at the same path, listed in `llms.txt` and `sitemap.xml`.
- `website/public/` is generated and not committed.

### Deployment and versioning

`.github/workflows/website.yml` runs on every push to `dev`:

1. **Release.** It bumps `VERSION` (`v0.1.n` → `v0.1.n+1`), commits `release: v0.1.n+1`, tags it and pushes both to `dev`.
2. **Build.** It tests, builds and validates the site from that release commit.
3. **Deploy.** It publishes to GitHub Pages and polls `https://ios.app.promptugal.news/version.json` until it serves the new release. The deploy isn't done until that check passes.

Pull requests run only the build step, with no release and no deploy. After a push, run `git pull` to pick up the release commit CI added.

| Version | Set by | Shown as |
| --- | --- | --- |
| Release, `v0.1.n` in `VERSION` | CI, once per push to `dev` | Footer, git tag, `version.json` |
| App version (`MARKETING_VERSION`) | You, in Xcode, when you start a new release | Version badge, page text, JSON-LD, `version.json` |
| App build (`CURRENT_PROJECT_VERSION`) | The iOS release workflow, on the `xcodebuild` command line: its run number plus `IOS_BUILD_OFFSET` (default 100). A hand upload from Xcode must use a build number above the last CI one. | The CI build panel on the site, `ios-build.json` |

One-time GitHub setup: under **Settings → Pages**, set **Source** to **GitHub Actions** and the custom domain to `ios.app.promptugal.news`. Under **Settings → Environments → github-pages**, allow deployments from the `dev` branch. If `dev` is protected, let GitHub Actions push to it so the release commit and tag can land.
