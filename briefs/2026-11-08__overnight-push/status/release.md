# Status · Release engineering

> First version of the release workflow is pushed: unsigned archive, .ipa and simulator app on every push, and a TestFlight job that skips until the signing secrets exist.

Branch: `night/release` · Last update: 03:20 UTC

## Done

- `.github/workflows/ios-release.yml`:
  - **package** runs on every push to `dev` and `night/**`, on tags `ios-v*` and by hand. It runs `xcodebuild archive` for `generic/platform=iOS` with signing off, packages an unsigned `.ipa`, builds a Release simulator app, and uploads all three as artifacts named `PrompTugal-<version>-<build>-<sha>-…`. The job summary shows Info.plist values and a size breakdown. It fails if the app is not built for both iPhone and iPad.
  - **testflight** runs only by hand (with **upload** ticked) or on a tag `ios-v*`. It skips with a `skipped: secret X missing` line until the secrets exist. With the secrets, it signs (manual: .p12 and profiles, or automatic: API key), exports an App Store .ipa and uploads it with `xcodebuild -exportArchive` (destination upload).
- `scripts/release/`: `select-xcode.sh`, `version.sh` (build number), `package-unsigned.sh`, `report.sh`, `signing-setup.sh`, `testflight.sh`, `signing-cleanup.sh`, two ExportOptions templates.
- Build number: `CFBundleVersion` = this workflow's run number + 100 (repo variable `IOS_BUILD_OFFSET`), passed as `CURRENT_PROJECT_VERSION`. `MARKETING_VERSION` stays in the project.

## In progress

- First run of `iOS release` on `night/release`.

## Next

1. `release-setup.md`: the portal, secrets and TestFlight checklist.
2. Re-check the workflow against the platform branch once it is merged (iOS 18, SGitVault package, entitlements).
3. Backlog: App Store submission workflow, release notes from git log, size regression check, latest build on the website.

## Blocked

Nothing.

## Needs from others

- **Platform:** add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` to the app target. The app uses only encryption built into iOS (CryptoKit, URLSession), which Apple's export compliance table puts under "no documentation required". Without the key, every TestFlight build waits for someone to answer the question in App Store Connect.
- **Platform:** in `Config/PrompTugal.xcconfig`, add `PROVISIONING_PROFILE_SPECIFIER = $(PT_PROFILE_APP)` (and the same with `PT_PROFILE_WIDGET`, `PT_PROFILE_INTENTS`, `PT_PROFILE_SHARE` in any extension target's settings). It is empty and does nothing in normal builds. CI then sets the profile per target. Without it, CI has to set one profile for every target, which breaks once there is an extension or a package with resources.
- **Platform:** please tell me in your status page when you add an extension target, with its bundle id, so the profile and portal checklist match.
