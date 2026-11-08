# Status · Editor

> 00:05 UTC: the site structure, the three-apps page, the Team app pages in the admin area and the review notes are done on `split/editor`, green on build, validator and tests. Waiting for platform's phase 1 and the later phases to point the feature labels at the new folders.

Branch: `split/editor` · Last update: 10:40 UTC (editor.B took over from account A at about 01:40)

## Done

- Site: the public pages (Home, The app, Features, Plans, Support, Privacy) describe the PrompTugal app. New page "The three apps", with RiskMandate marked "coming after the summit".
- Site: `teams.html`, the old privacy page and the Overnight page moved to `admin/team-app.html`, `admin/team-privacy.html` and `admin/overnight.html`. The admin index links all three.
- Checks: a feature is in an app only if the app is built from its files (`apps.json` folders and package closure). Before the split the old `PrompTugal/` folder is the app. Test folders never count. Six new tests.
- `features.json` names files, not paths, so moves do not break it. Sample data and reading credit are team features now.
- Push dashboard reads `split/*` branches as well as `night/*`. Test against a throwaway git repository.
- Review notes rewritten for the PrompTugal app: no sample data, no keys needed, no lanes, no purchases.
- Build log checkpoint 13.

## In progress

- 10:40 UTC: merged `origin/dev` (v0.4.13): `apps.json` now uploads the public PrompTugal app to TestFlight; contracts §8 (next round: PTSync, decks, Team native). No site change needed; checks green (69 tests, `check_apps.py` OK). Public page 13 of 13 in the beta. Waiting for the conductor to merge `split/editor`. For §8: when `PTSync` or `PTDeck` land and the PrompTugal app lists them in `apps.json`, I add feature entries (offline sync, decks and presenter mode) with evidence from their files; I will not label them before they are built.

- 10:15 UTC: merged `origin/dev` (v0.4.11: README outcome note, first Team build 0.4.7 in TestFlight). No site change. Checks green (69 tests); public page still 13 of 13 in the beta. READY stands, new head below.

- 10:05 UTC: merged `origin/dev` (v0.4.10) with design's `PublicShell` (`105ca49`). No conflict. Two label problems on my side, both fixed: (1) `parse_destinations` in `website/admin.py` read `Destination(` and `AppDestination(` but the public shell registers screens as `ShellDestination(`, so it saw none (now read, with a test); (2) "Website and app talk to each other" and "Reminders before sessions" needed the root marker `.teamFeatures()`, which only the Team app has; the public app starts them with `.publicFeatures(` in `PublicShell.swift`, so they now check `text:**/PublicShell.swift::.publicFeatures(`. Result: public page 13 of 13 in the beta (the real shell registers every screen they name); Team page unchanged (23 in the beta, 2 debug only, 1 coming). 69 tests green.
- Answer to the conductor on the review texts: `ios-release.yml` does not read `what-to-test.txt` or `review-notes.txt`; it sets What to Test for every app from `scripts/release/release-notes.sh` (git log). Only `testflight-ops.yml` (manual) reads them, and it has `BUNDLE_ID: news.promptugal.reader` fixed, so they only reach the PrompTugal app. Team and RiskMandate are not affected.

- 09:45 UTC: **phase 4 is on dev** (v0.4.8): Team moved to `Apps/Team`, widgets and intents and file sharing are in `Apps/PrompTugal`. Merged `origin/dev` with no conflict. Site facts now come from `Apps/PrompTugal` (version 0.4.8 from `VERSION`, bundle `news.promptugal.reader`, icon and `Websites.json` from the app and `Packages/PTWeb`). Privacy and support re-read against that code: widget, Siri answers and camera are on privacy; file sharing is in the project, so the Files section of support stays. Review texts swapped: `review-notes.promptugal.txt` and `what-to-test.promptugal.txt` now are `scripts/testflight/review-notes.txt` and `what-to-test.txt` (`DEMO_LANE_NAME` is gone from the notes; `tf.py` treats it as optional; its 12 tests pass). Version wording on the admin index and releases pages now says every app's version is the release version. Labels: Team 23 in the beta (2 debug only, 1 coming); public 4 in the beta, 9 coming, because design's `PublicShell` screens are not on dev yet (I saw 5 in the beta in my preview with `split/design`).

- 08:30 UTC: dev unchanged since v0.4.6. Preview of phase 4 in a throwaway worktree: `split/editor` merged with `split/platform` (cd02fa7), `split/apps` (a53e3cc) and `split/design` (b8716f4): no conflicts, build and 68 tests pass, public page 5 in the beta and 8 coming, Team 23 in the beta. `split/apps` already has file sharing (`UIFileSharingEnabled`) and the widgets and intents in `Apps/PrompTugal`, so the support section on `Websites.json` in Files stays. **The validator fails on `split/design`'s status page** (`status/design.md` line 211, the line about Ask being marked as unfinished until PTAsk is on dev, uses a word the validator bans; see `BANNED` in `website/validate.py`). Design needs to reword it before its branch reaches dev, or dev's checks fail. Not my file; told the conductor.

- 08:05 UTC: started the privacy and support re-read against `Apps/PrompTugal` (dev) and its widgets and intents (`split/platform`). Privacy: added the widget and Siri answers (they read a small on-device copy of now and next from the App Group, no network, no vault) and the camera (VisionKit reads a vault QR code on the device, nothing saved or sent). Support: added how to add the widget and ask Siri. Dev has no new commits since v0.4.6.
- **Found in `Apps/PrompTugal`: no file sharing.** The old project had `INFOPLIST_KEY_UIFileSharingEnabled = YES` and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES`; the new project has neither. The support page tells people to edit `Websites.json` in the Files app, which only works with them. See "Needs from others".

- 07:50 UTC: the conductor applied my two build patches to dev (`cf4f548`, `b17edc3`); the patch folder stays out of dev. Merged `origin/dev` (v0.4.6) into `split/editor`: conflicts in `admin.py`, `build.py` and `validate.py` because both sides had the same changes; kept `split/editor`'s versions (they also carry the page and feature scope code). Checked on two layouts: today's dev layout, and `split/editor` merged with the real `origin/split/platform` (`f0c53a9`, no root `PrompTugal/`). Both: build, validator, 68 tests green, and the same labels (Team 23 in the beta, 2 debug only, 1 coming; public 4 in the beta, 9 coming).
- Next: read `Apps/PrompTugal` (widgets, intents, config now there) for the privacy and support pages.

- 07:35 UTC: the conductor asked for a build-only branch `split/editor-build`. My rule is to push only `split/editor`, so I did not push a new branch. I made the same two commits on `origin/dev` (1087a92) and put them as `git am` patches in `briefs/2026-11-08__three-apps/editor-build/` on `split/editor`, with a README. They change only `website/build.py`, `validate.py`, `admin.py` and `test_site.py`, no page text. Checked: applied to a clean `origin/dev` with `git am`, then build, validator and 59 tests pass; and on platform's layout in a worktree (project, sources and tests under `Apps/Team`, `apps.json` team entry on `Apps/Team/`), 59 tests pass. The first version of the fix missed `admin.py`, which reads only `PrompTugal/` for screens, features and screenshots; three tests caught it, so the patch includes it. If the conductor wants the branch pushed as `split/editor-build`, that needs Dinis's word.

- 07:15 UTC: **phase 4 started** (conductor, dev 02f3624). Merged `origin/dev` (v0.4.5) with PTAsk (`02f3624`), no conflict. Public page now 4 in the beta (Ask), 9 coming; Team page unchanged. 68 tests green.
- Test of platform's move before it lands: in a throwaway worktree I did the layout of its plan (step 1: `PrompTugal.xcodeproj` to `Apps/Team/Team.xcodeproj`, `PrompTugal/` to `Apps/Team/Sources/`, tests to `Apps/Team/Tests` and `UITests`; step 8: the `apps.json` team entry on `Apps/Team/`). The first build stopped: the sidebar artwork (`Shortcut*.imageset`) then sits in `Apps/Team/Sources/App/Resources/Assets.xcassets`. I made the site look for it under `Apps/` and `Packages/` too, after the app's own folders. With that, build, validator and all 68 tests pass on the moved layout, with the same labels (Team 23 in the beta, public 4). So dev's `website/build.py` needs no fix for platform's move. Still to check against the real `split/platform` when it pushes.
- Left to do for phase 4: read facts (version, bundle, icon, `Websites.json`) from the real `Apps/PrompTugal` once apps and design finish it; re-read `privacy.html` and `support.html` against its code (widgets, intents, URL scheme `promptugal://`, background refresh); swap in the PrompTugal review texts; then send READY.

- 06:25 UTC: merged `origin/dev` (v0.4.3) with PTLanes and VaultCollabAccess (`6300658`). No conflict. The lanes feature still reads as in the beta on the Team page: its evidence names `**/LanesStore.swift` and `text:**/LanesView.swift::ReportBlockMenu`, which are now in `Packages/PTLanes`, inside the Team app's package closure. Team page unchanged (23 in the beta, 2 debug only, 1 coming); public page 3 in the beta, 10 coming. 68 tests green. Only PTAsk and phase 4 remain.

- 05:55 UTC: merged `origin/dev` (v0.4.2) with PTNews (`d3cb173`): news screens and the graph moved to `Packages/PTNews`. No conflict. Checked the labels against the moved files: Team page unchanged (23 in the beta, 2 debug only, 1 coming), so `features.json` needs no change (it names files, and the `screen:news.home` / `screen:news.graph` registrations are still in the Team app's Destinations). Public page still 3 in the beta, 10 coming, until `PublicShell` registers screens. 68 tests green. Still waiting for PTLanes, PTAsk and the phase 4 word.

- 05:20 UTC: dev has had no new commits since v0.4.1 (merged at 04:15). Nothing to merge. Holding for PTNews, PTLanes, PTAsk and the phase 4 word. Checks last green at 04:15 (68 tests).

- 04:15 UTC: merged `origin/dev` (v0.4.1): reminder links use `AppLinks.scheme`, StoreKit test bound. Swift changes only, no label or site change. Checks green (68 tests). Still waiting for PTNews, PTLanes, PTAsk and the phase 4 word.

- 03:50 UTC: merged `origin/dev` (v0.4.0): release's one-version change, the `Apps/PrompTugal` and `Apps/RiskMandate` projects and their `apps.json` entries. Merged without conflict, but the build stopped twice, and I fixed both in `website/build.py`:
  1. The new project's build configurations carry `baseConfigurationReference` before `buildSettings`, which my parser did not accept, so it saw no bundle id. It does now.
  2. `ShortcutPrompTugal` and the other sidebar images are still only in the old catalog (`PrompTugal/App/Resources/Assets.xcassets`), not in `Apps/PrompTugal/Resources/Assets.xcassets`. The site now takes shortcut images from every catalog of the app's folders, the app's own first.
- The site now reads **0.4.0** from `VERSION` (it matches the new project's MARKETING_VERSION 0.4.0). 68 tests green.
- Effect on labels: the public app now has its own `apps.json` entry (`Apps/PrompTugal/` plus the PTAsk closure), so `features.html` shows **3 in the beta, 10 coming**. That is true today: the new app is only a shell. The Team page is unchanged (23 in the beta). Labels come back as the app gets its screens.

- 03:25 UTC: merged `origin/dev` (v0.1.80) with PTWeb and PTAgenda (`7863ae2`). Conflict in `website/build.py` with the conductor's `_one()` fix (`11ab789`): kept my `admin.find_in_app`, which already searches `Packages/PTWeb`, and dropped `_one()`. The admin screens page now prints the real path of `Websites.json` (`Packages/PTWeb/Sources/PTWeb/Resources/Websites.json`) instead of the fixed text. Labels checked against the moved files: 13 of 13 public in the beta, Team page unchanged (23 in the beta, 2 debug only, 1 coming). `features.json` names files, so nothing else needed changing. Build, validator and 67 tests green.

- 03:15 UTC: merged `origin/dev` (v0.1.79): PTCore `CollabSeams.swift` and `AppLinks.scheme`, platform status. Both are new PTCore files, so the site's Swift file and line counts moved; build, validator and 67 tests green. No `features.json` change: neither file carries a feature label. Still no PTWeb, PTAgenda, PTNews, PTVaultUI-side, PTLanes or PTAsk move on dev.

- 02:40 UTC: merged `origin/dev` (v0.1.77, ios.yml runner choice). CI files only; no site or feature change. No phase 3 package on dev yet. Checks green.

- 02:10 UTC: merged `origin/dev` (v0.1.76, handoff page: Team and RiskMandate App Store Connect records exist). No phase 3 package on dev yet, so `features.json` is unchanged. Checks green.

- 02:00 UTC: merged `origin/dev` (v0.1.75, handoff page). The site's app version now comes from `app_version()` in `website/build.py`: from v0.4 on it is the release number (v0.4.7 gives 0.4.7), before that the project's MARKETING_VERSION (0.3.1 today). The validator and tests use the same function. I did not touch `website/version.py` or its tests, which `split/release` also changes (they will merge without conflict). Build, validator and 67 tests green.
- Still to do once release is on dev: reword `version.py` docstring, release-setup and support pages that say the app and site versions are separate (release's branch already rewrites the docstring and release-setup).

- 01:25 UTC: contact address `agent@riskmandate.ai` (48 hours) is on the support page and in the review notes brief. The `.txt` notes keep `<CONTACT_ADDRESS>` and `<RESPONSE_TIME>` for `tf.py` to fill.

- 01:05 UTC: the conductor gave me `scripts/testflight/review-notes.txt` and `what-to-test.txt` (text files only). The PrompTugal versions are written next to them as `review-notes.promptugal.txt` and `what-to-test.promptugal.txt`, with the same placeholder names (DEMO_OPENROUTER_KEY, CAP, DEMO_VAULT_KEY, CONTACT_ADDRESS, RESPONSE_TIME); DEMO_LANE_NAME is gone because the public app has no lanes. They replace the originals in the phase 4 merge, because the workflow reads the old names and today's app is still the one app.

- 01:00 UTC: merged `dev` to v0.1.67 (TestFlight ops, release). Green, pushed. `scripts/testflight/review-notes.txt` and `what-to-test.txt` still describe the one app (sample data, Who are you); they are not mine. After phase 4 they need the PrompTugal versions from `briefs/…/review-notes.md`.

- 00:45 UTC: merged PTVaultUI (`e5328ff`). Vault, Face ID and trusted-signer labels follow the moved files (`**/VaultKeychain.swift`, `**/VaultViews.swift`): all three still in the beta. Green, pushed.

- 00:05 UTC: merged phase 1 (`9220d7e`). `apps.json` has only a `team` entry on the root project, so the PrompTugal app has no entry and counts as the one app: labels unchanged (13 of 13 public, same team count). Build, validator and 66 tests green. Pushed.

- Conductor: hold `split/editor` and merge after phase 4. Keep merging `origin/dev` in. Answers received: the public shell is `PublicShell(` in `Apps/PrompTugal/PublicShell.swift`; shared screen ids are unchanged; Ask there has no team context; screenshots are `screens-<sha>` for the PrompTugal app and `screens-<sha>-<app>` for the others. Screens check now accepts `PublicShell(`.

- Waiting for the conductor's word that phase 1 (scaffold) is on `dev`.

## Next

- Merge `origin/dev` when platform's phase 1 lands. Read `apps.json` and check the scope code against the real file.
- Phase 3: update `features.json` for the packages (screen ids, root markers) as each lands.
- Phase 4: point facts (version, bundle, icon, websites) at `Apps/PrompTugal`; re-read privacy and support against its code; fix the home screenshot ids.

## Blocked

- Nothing yet.

## Needs from others

- Apps (or conductor): add `INFOPLIST_KEY_UIFileSharingEnabled = YES;` and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES;` to both configurations of the PrompTugal app target in `Apps/PrompTugal/PrompTugal.xcodeproj`, as the root project has. Otherwise the support page's "edit the website shortcuts in Files" section is false for the public app, and I will have to remove it before READY.

- Platform/apps (phase 4): the sidebar artwork (`Shortcut*.imageset`, for example `ShortcutPrompTugal`) has to be in `Apps/PrompTugal/Resources/Assets.xcassets` or in a package resource, or the new app's sidebar will have no icons. The site is fine either way.

- Design: which features the PrompTugal app has. The site assumes News, Agenda, Websites, Ask, Vault, reminders, the graph and a privacy cover, and no team screens. Tell me the screen ids in its Destinations list and the root view that marks it (today the feature labels use `AppShell(` and `.teamFeatures()`).
- Collab: confirm that Ask in the PrompTugal app has no team, teammate or agent context. The privacy page and the review notes say so.
- Release: how `screens.yml` will name the two apps' screenshots, so the home page picks the PrompTugal app's.
- The conductor: merge this branch after phase 4, or earlier? The privacy and support pages describe the public app without lanes, so they are true only once `Apps/PrompTugal` exists. The apps page already says "not finished" until the three projects exist.

## Handoff

- **Head:** see the last commit on `split/editor` (the sha is in my reply to the conductor). It includes `origin/dev` with PTCore (`116a350`), PTVaultUI and the handoff page. Build, validator and 66 tests pass.
- **Held until phase 4.** The public pages (home, the app, privacy, support) describe the public app with no lanes or team data, and are true only once `Apps/PrompTugal` exists. Merge `split/editor` with phase 4.
- **Still to re-point as packages land** (labels are checked by `website/admin.py` against `apps.json`):
  - Phase 3: PTWeb, PTAgenda, PTNews, PTAsk, PTLanes. `features.json` names files (`**/File.swift`), so most labels follow the move. Check `screen:` and `root:` entries, and that the team list still sees PTLanes.
  - Phase 4: add `promptugal` and `riskmandate` to `apps.json` checks; the root view marker for the public app is `PublicShell(` in `Apps/PrompTugal/PublicShell.swift`; read facts (version, bundle, icon, `Websites.json`) from `Apps/PrompTugal` (`APP_PROJECTS`, `APP_FOLDERS` in `admin.py`); re-read `privacy.html` and `support.html` against its code; screenshots are `screens-<sha>` for the PrompTugal app and `screens-<sha>-<app>` for the others.
  - Release's one-version change (v0.4.0): update the wording that says the app version and site version are separate (`version.py` docstring, release-setup and support pages, the footer) once it is on dev. The conductor will ping.
- **Contact:** `agent@riskmandate.ai`, answer "within 48 hours". It is on `support.html` and in `review-notes.md`.
- **Review texts I prepared:** `briefs/2026-11-08__app-review-readiness/review-notes.md`; `scripts/testflight/review-notes.promptugal.txt` and `what-to-test.promptugal.txt`. In the phase 4 merge, `git mv` them over `review-notes.txt` and `what-to-test.txt`. Placeholders `tf.py` fills are unchanged, except `DEMO_LANE_NAME`, which is gone.
- **Scheduled check-ins:** cancelled.
