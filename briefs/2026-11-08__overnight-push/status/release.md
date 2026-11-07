# Status · Release engineering

> CI packages every dev build unsigned (.ipa, simulator app, archive) and is ready to sign and upload to internal TestFlight as soon as Dinis adds 8 secrets. His 8-step morning checklist is at the top of release-setup.md.

Branch: `night/release` · Last update: 07:08 UTC

## Done

- `.github/workflows/ios-release.yml`:
  - **package** runs on pushes to `dev` and `night/release` (not docs-only), on tags `ios-v*` and by hand. It runs `xcodebuild archive` for `generic/platform=iOS` with signing off, packages an unsigned `.ipa`, builds a Release simulator app, and uploads all three as artifacts named `PrompTugal-<version>-<build>-<sha>-…`. The job summary shows Info.plist values and a size breakdown. It fails if the app is not built for both iPhone and iPad.
  - **testflight** runs only by hand (with **upload** ticked) or on a tag `ios-v*`. It skips with a `skipped: secret X missing` line until the secrets exist. With the secrets, it signs (manual: .p12 and profiles, or automatic: API key), exports an App Store .ipa and uploads it with `xcodebuild -exportArchive` (destination upload).
- `scripts/release/`: `select-xcode.sh`, `version.sh` (build number), `package-unsigned.sh`, `report.sh`, `signing-setup.sh`, `testflight.sh`, `signing-cleanup.sh`, two ExportOptions templates.
- **Run 3 green** (42331786804): archive 49 s, Xcode 26.6 (`DTXcode 2660`), iOS SDK 26.5, `UIDeviceFamily [1,2]`, app 1.0 MB, .ipa 657 KB, executable 524 KB. Artifacts: `PrompTugal-0.3.1-103-742a304-unsigned-ipa`, `…-simulator-app`, `…-xcarchive`, `build-info`.
- Size check (`size-check.sh`, budgets in `size-budget.json`, compares with the latest dev build) and release notes from git log (`release-notes.sh`) in every package run.
- `scripts/release/asc.py`: App Store Connect API client (standard library and `openssl` for the token; signature verified locally with a throwaway key). The TestFlight job uses it to wait for processing, answer export compliance and set "What to Test".
- `.github/workflows/ios-submit.yml`: App Store review submission, by hand only, dry run unless **confirm** is ticked. Metadata stays manual.
- `scripts/release/latest-build.sh`: writes the latest successful dev build's info (version, build, commit, sizes, run link, artifacts) as JSON for the website.
- [release-setup.md](../release-setup.md): the portal, App Store Connect and GitHub secrets checklist, how to trigger an upload, how testers install, how to re-sign the unsigned .ipa, and the gotchas.
- Build number: `CFBundleVersion` = this workflow's run number + 100 (repo variable `IOS_BUILD_OFFSET`), passed as `CURRENT_PROJECT_VERSION`. `MARKETING_VERSION` stays in the project.

- **03:10** Run 8 (manual, `upload` ticked, `source_ref: night/platform`): package green on the platform project, minimum iOS 18.0, `UIDeviceFamily [1,2]`, app 1.7 MB, .ipa 892 KB. TestFlight job green and skipped: `skipped: secret ASC_KEY_ID missing`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `APPLE_TEAM_ID`. Nothing printed but empty values.
- Runs 4, 5 and 7 green. Pushes no longer cancel manual or tag runs (separate concurrency group).
- New manual inputs: `internal_only` (`testFlightInternalTestingOnly`), `source_ref` (build another branch with these scripts), `build_number`.

- **03:24** Push trigger narrowed for the macOS queue (conductor): `dev` and `night/release` only, docs/site-only pushes skipped (`paths-ignore` like `ios.yml`). Tags and manual runs unfiltered.
- Rebased on dev `cbbbb89`, which has the platform project (iOS 18, SGitVault, widgets, intents).

- **03:32** Conductor merged `night/release` into dev (`d6b9cd2`). Run 11 on dev green. From now on I merge dev into `night/release` (no rebase).
- Editor wired `latest-build.sh` into `website.yml`; the site shows the latest dev build.
- Checklist: Time Sensitive Notifications capability (new app entitlement on dev). Each package run now lists every target's entitlements next to its profile secret, so the portal setup can be checked against the build.

- **03:48** Run 13 on dev (`f4d84fd`, with the entitlements table) green. Merged dev into `night/release` twice (merge, not rebase).
- Push trigger is now `dev` only. Night branches are built by `ios.yml`; release workflow changes are tested by a manual run. Saves one macOS run per merge.
- Checked dev's targets and entitlements against the checklist: app (Associated Domains, Time Sensitive Notifications, App Groups), widgets and intents (App Groups). No drift.

- **04:08** Run 15 (manual, `night/release` at `93339e6`, trigger change) green; no push run started for `night/release`. Run 16 on dev (`96012e5`, after the vault merge) green. Merged dev again; targets and entitlements unchanged (app, widgets, intents).

- **04:30** Run 18 on dev (team merge) green. Merged dev (`417be29`). Scanned the merged app for capabilities: no new entitlements; NFC usage string but no Core NFC code; background modes need no portal step; StoreKit products go in App Store Connect. Checklist updated.
- **Privacy manifest missing.** The app uses `UserDefaults` (5 files) and file timestamps (4 files), which App Store Connect requires to be declared (ITMS-91053, rejects the upload). Drafted `scripts/release/templates/PrivacyInfo.xcprivacy` with the reasons; package runs now warn while it is missing.

- **04:50** Run 20 (manual, privacy-manifest warning) green. Platform added `PrompTugal/App/Resources/PrivacyInfo.xcprivacy`, identical to the draft. A UI-test target appeared (`news.promptugal.reader.uitests`); it is not archived or signed, so the checklist is unchanged.
- **Dry run for signing:** manual input `dry_run` signs and exports the App Store .ipa without uploading. Before archiving, `check-profiles.sh` checks each signed target's entitlements against its profile and names any missing capability (tested locally with good and bad profiles).

- **05:08** Run 24 on dev (editor merge) green. Merged dev (`b00dc15`); targets, entitlements and privacy manifest unchanged.

- **05:17** `ios-release.yml` no longer cancels a started run (`cancel-in-progress: false`): dev runs 21-23 had been cancelled mid-archive by the next merge. A newer push now replaces only a run still waiting for a runner. Same fix as platform's.

- **05:50** Run 25 (manual `dry_run`) green after 22 min in the runner queue: package green (archive step about 5 min now), TestFlight job ran and skipped on missing secrets. Conductor merged `night/release` into dev (`0b0fe88`): the concurrency fix is live, and dev run 28 was not cancelled by run 29. Targets, entitlements and manifest unchanged.

- **06:05** Release notes: `release-notes.sh` now starts with each session's status summary (changed since the last `ios-v*` tag), then the commits; 3,454 characters for tonight, under Apple's 4,000. The TestFlight job sets it as "What to Test".
- `release-setup.md`: a morning checklist (8 steps, about 45 minutes, secret names and where to click) at the top, and the install section rewritten for the two extensions: build from Xcode first, simulator app, or re-sign the CI .ipa inside-out with three profiles.

## In progress

- Dev run 28 green at 06:20 after an hour in the runner queue; it was not cancelled by later merges (runs 29 and 30 were replaced while still waiting, as designed). Run 31 (platform merge) building. With no-cancel concurrency, iOS release holds at most one running and one waiting run on dev, so it cannot pile up in the queue. Targets, entitlements and manifest unchanged at 06:40.
- **07:06** Dev run 31 (platform merge) green; run 32 building, 33 waiting. Editor updated the README: the private-beta section points to release-setup.md, and the build-number row says CI sets it. Targets, entitlements and manifest unchanged.

## Next

1. Re-check the workflow against the platform branch once it is merged (iOS 18, SGitVault package, entitlements).
2. Latest build on the website (needs the editor, below).

## Blocked

Nothing.

## Needs from others

- ~~**Platform (blocks the first TestFlight upload):** copy `scripts/release/templates/PrivacyInfo.xcprivacy` to `PrompTugal/App/Resources/PrivacyInfo.xcprivacy` (app target). It declares `UserDefaults` (CA92.1) and file timestamps (C617.1, DDA9.1), found in Team, Schedule, Vault, Dashboards, Debug and Notifications. Keep it current when new code uses required-reason APIs.~~ Done by platform.

- ~~**Platform:** add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`~~ Done by platform (`Config/PrompTugal.xcconfig`). The app uses only encryption built into iOS (CryptoKit, URLSession), which Apple's export compliance table puts under "no documentation required". Without the key, every TestFlight build waits for someone to answer the question in App Store Connect.
- **Editor:** to show the latest CI build on the site, run `GH_TOKEN=${{ github.token }} scripts/release/latest-build.sh website/public/ios-build.json dev` in the website build job (it needs `permissions: actions: read`). It writes `{"available": false}` when there is no build, so it never fails the site. Fields: `version`, `build`, `commit`, `builtAt`, `minimumOS`, `deviceFamily`, `ipaBytes`, `appBytes`, `runUrl`, `artifacts[]`. I can make the `website.yml` change myself if you prefer; tell me in your status page.
- **Platform:** nothing needed for per-target profiles: CI passes its own `-xcconfig` with `PROVISIONING_PROFILE_SPECIFIER = $(PT_PROFILE_$(TARGET_NAME))`. The checklist covers `news.promptugal.reader.widgets` and `.intents`. If you add or rename an extension, the package job's **Targets to sign** table shows it automatically.
