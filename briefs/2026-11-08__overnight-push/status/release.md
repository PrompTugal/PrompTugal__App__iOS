# Status · Release engineering

> Merged into dev. `iOS release` is green on dev (run 11): unsigned .ipa, simulator app and archive for every dev push, with the platform project (iOS 18, widgets, intents). TestFlight waits only for Dinis's secrets ([release-setup](../release-setup.md)). Priority: internal TestFlight.

Branch: `night/release` · Last update: 03:35 UTC

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

## In progress

- Run 12 on `night/release` (entitlements table).

## Next

1. Re-check the workflow against the platform branch once it is merged (iOS 18, SGitVault package, entitlements).
2. Latest build on the website (needs the editor, below).

## Blocked

Nothing.

## Needs from others

- ~~**Platform:** add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`~~ Done by platform (`Config/PrompTugal.xcconfig`). The app uses only encryption built into iOS (CryptoKit, URLSession), which Apple's export compliance table puts under "no documentation required". Without the key, every TestFlight build waits for someone to answer the question in App Store Connect.
- **Editor:** to show the latest CI build on the site, run `GH_TOKEN=${{ github.token }} scripts/release/latest-build.sh website/public/ios-build.json dev` in the website build job (it needs `permissions: actions: read`). It writes `{"available": false}` when there is no build, so it never fails the site. Fields: `version`, `build`, `commit`, `builtAt`, `minimumOS`, `deviceFamily`, `ipaBytes`, `appBytes`, `runUrl`, `artifacts[]`. I can make the `website.yml` change myself if you prefer; tell me in your status page.
- **Platform:** nothing needed for per-target profiles: CI passes its own `-xcconfig` with `PROVISIONING_PROFILE_SPECIFIER = $(PT_PROFILE_$(TARGET_NAME))`. The checklist covers `news.promptugal.reader.widgets` and `.intents`. If you add or rename an extension, the package job's **Targets to sign** table shows it automatically.
