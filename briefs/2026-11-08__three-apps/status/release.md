# Release status

> Handed off to conductor.B at 01:40 UTC. CI now plans per app: a Linux `changes` job picks the affected apps and packages, and ios.yml, ios-release.yml and screens.yml run matrices over them. Written against today's single project; first runs on split/release are in progress.

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

- iOS run 271 (push) and iOS release run 50 (dry run) on `b15d34f`: success. Newer proof runs 287 and 59 on `d0ad4d6` pending (see Handoff). Updated 01:40 UTC.

## Handoff

Handed off at 01:40 UTC (8 Nov) to the session under conductor.B. I dispatch no more CI and have cancelled my own scheduled check-ins.

**Head:** `split/release` at `c66bcdb` (last code commit `0ed75bc`; later commits are the status page and a merge of `origin/dev`). `VERSION` on this branch is `v0.4`; the merge with dev's `v0.1.74` conflicted, and the branch keeps `v0.4`. A conflict marker briefly reached the branch in `b5805a9` and was removed in `c66bcdb`.

**Last runs (all on `d0ad4d6`, same code as the head apart from `0ed75bc`):**

- iOS run 287 (`ios.yml`, `quick=true`, `app=all`): queued at 01:31 UTC, no result yet.
- iOS release run 59 (dry run, `app=all`): in progress at 01:31 UTC, no result yet.
- Earlier startup failures (runs 282, 283, release 57) were the `changes` call asking for `actions: read` that the caller did not grant. Fixed in `d0ad4d6`.
- Last fully green runs: iOS 271 and iOS release 50 on `b15d34f` (before the one-version and quick work).

**Still to prove**

1. **Quick mode** (`ios.yml` `quick=true`): expect Debug build only, iPhone tests only, package tests for what the branch changed. Run 287.
2. **One version, dispatch path:** in run 59's unsigned package log, `MARKETING_VERSION=0.4.0`, `tag none` (not a release commit), summary line `0.4.0 (build) · tag none · commit <sha>`, and the Info.plist table shows version `0.4.0`.
3. **One version, `workflow_run` path:** cannot run before merge, because `workflow_run` only fires from the default branch. After the merge, watch the first dev push: "Release and deploy" makes tag `v0.4.0`, then "iOS release" starts, builds that commit, and the app version is `0.4.0`. Check the `Changes` job summary line "release `v0.4.0` (…): `team` since never built" or since the last build, and that each app uses its own `build-info-<app>` commit as the base.
4. **Record-missing skip:** only runs with signing secrets. Reviewed and syntax-checked only. Expect `asc.py has-record` to exit 3 for a bundle with no record: the job is green with "skipped: no App Store Connect record", and no archive happens.
5. **`app=riskmandate` and `app=promptugal` dispatch:** works once `apps.json` has them and their projects exist (today the plan prints "not in apps.json").

**Merge condition (conductor's):** a green `quick=true` run plus a green ios-release dry run. Then merge `43207a8`, `6c26a23`, `279dbca` and the later fixes (`d0ad4d6`, `0ed75bc`) together, and run the site checks first, since `VERSION` is now `v0.4` and `website/version.py` and `website/test_site.py` changed.

**Next steps**

1. Read runs 287 and 59. If red, `get_job_logs` with failed only, fix on `split/release`, re-dispatch.
2. When both are green, send the conductor the head sha and the two run numbers.
3. After the merge, watch the first dev push end to end (point 3 above). If `workflow_run` does not fire, check that the default branch is the one holding `ios-release.yml` and that "Release and deploy" is the exact workflow name.
4. Phase 4: `apps.json` "team" must switch bundle to `news.promptugal.team` in the same commit that moves the project, or the upload guard fails. Ask platform to add `.github/scripts/` to `all`.
5. The editor should read the app version from `VERSION` (the site's `build.py` still reads the project's `MARKETING_VERSION`, 0.3.1).
6. Risk to know: if "Release and deploy" fails for a push (for example the site validator), that push is not built; the next successful release builds everything since each app's last build.
