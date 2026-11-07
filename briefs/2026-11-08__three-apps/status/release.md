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

## In progress

- First CI runs on `split/release` (push run and manual runs). Not green yet.

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

- iOS push run 267 on `split/release`: `changes` green, macOS jobs running.
