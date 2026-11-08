# Release status

> CI now plans per app: a Linux `changes` job picks the affected apps and packages, and ios.yml, ios-release.yml and screens.yml run matrices over them. Written against today's single project; first runs on split/release are in progress.

**Branch:** `split/release` · **Updated:** 8 Nov 00:55 Lisbon (23:55 UTC, 7 Nov)

## Done

- `scripts/release/apps.py`: reads `apps.json` (or a built-in single-app config when the file is missing), the diff and the event; prints the apps to build, the apps to upload, the packages to test and the apps to photograph. Has a self-test that runs in CI.
- `.github/workflows/ios-changes.yml`: reusable `changes` job on ubuntu. An app whose project does not exist is skipped, with a line in the summary.
- `ios.yml`: Debug and Release builds per affected app, unit tests on iPhone and iPad per affected app (dev, pull requests, manual), tests per affected package, and one `iOS result` check. Branches `split/**` now run CI.
- `ios-release.yml`: package per affected app; TestFlight per affected app with `testflight: true`. Own build-number offset per app (`IOS_BUILD_OFFSET_<APP>`, default 100). Pause per app (`TESTFLIGHT_ON_PUSH_<APP>`), and `TESTFLIGHT_ON_PUSH=false` still pauses all. Tags `team-v*`, `promptugal-v*`, `riskmandate-v*` (and the old `ios-v*`). Manual input `app`.
- Upload guards: the archive and the .ipa must have the bundle ID that `apps.json` names, every profile must belong to that bundle, and the App Store Connect record must exist for that exact bundle ID. Otherwise nothing uploads.
- `screens.yml`: per app, for apps that have a shared `<Scheme>Screens` scheme.
- Artifacts are named per app (`build-info-<app>`); the size check and the website's latest-build script were updated to match.

## Runner load and one version number (Dinis, via conductor)

- Done: `screens.yml` is manual only. `ios.yml` does not run on `split/**` pushes.
- In progress: one version. App version = `VERSION` of the built commit (v0.4.n -> 0.4.n). `website/version.py` turns `v0.4` into v0.4.0 (test added; `VERSION` is `v0.4`). `ios-release.yml` now follows "Release and deploy" (`workflow_run`), builds the release commit, passes `MARKETING_VERSION`, and compares each app with its own last build.
- Touches outside release files: `VERSION`, `website/version.py`, `website/test_site.py` only.
- Cannot be tested before merge: the `workflow_run` trigger only fires from the default branch. Tested by manual dispatch.

## Screens artifact names (for the site's screens.json)

- The app with bundle `news.promptugal.reader`: `screens-<sha>` (unchanged). Every other app: `screens-<sha>-<app>`.
- Files inside: `<iphone|ipad>-<destination id>.png`, longest side 1600 px.
- Only apps with a shared `<Scheme>Screens` scheme are photographed.

## In progress

- Green on `b15d34f`: iOS push run 271 and iOS release dry run 50. Reported to the conductor.
- Waiting for phase 4 (the Apps/ projects) to test the multi-app paths.

## Next

- Dry run of `ios-release.yml` on `split/release`.
- Update `release-setup.md` for three apps.

## Blocked

- Nothing.

## Needs from others

- **Platform:** while `apps.json` "team" points at the root project, its `bundle` must be the real bundle of that project (`news.promptugal.reader`). If it says `news.promptugal.team` before phase 4, uploads refuse (this is the guard working). Change the bundle in the same commit that moves the project.
- **Platform:** add `.github/scripts/` to the `all` list in `apps.json` (CI helper scripts). `check_apps.py` should print one error per line and exit non-zero; CI runs it as its own job.
- **Platform:** `scripts/apps/affected.py` output: I accept a JSON list of app keys, or an object with an `apps` list. Tell me if it differs.
- **Design:** each app's screenshots need a shared scheme named `<Scheme>Screens` in its project (or set `screensScheme` and `screensCount` in `apps.json`).

## Last CI run

- iOS run 271 (push) and iOS release run 50 (dry run) on `b15d34f`: success. Updated 00:55 UTC.
