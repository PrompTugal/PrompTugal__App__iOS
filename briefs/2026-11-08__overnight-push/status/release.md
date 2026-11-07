# Status · Release engineering

> Done. Every dev build is packaged by CI without keys (unsigned .ipa, simulator app, archive). Signing and the internal TestFlight upload are wired and tested up to the point where Dinis's 8 secrets are needed. His checklist is at the top of release-setup.md.

Branch: `night/release` (merged into dev; nothing open) · Final update: 08:45 UTC

## What Dinis does next

Follow **Morning checklist** at the top of [release-setup](../release-setup.md) (8 steps, about 45 minutes):

1. Apple Developer portal: three App IDs (`news.promptugal.reader`, `.widgets`, `.intents`), App Group `group.news.promptugal.reader`, and on the app ID Associated Domains and Time Sensitive Notifications.
2. Apple Distribution certificate as a .p12.
3. Three App Store profiles, one per App ID.
4. App Store Connect: app record, and an API key with the App Manager role.
5. TestFlight internal group "Team" with automatic distribution.
6. Eight GitHub secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_APP_BASE64`, `IOS_PROFILE_WIDGETS_BASE64`, `IOS_PROFILE_INTENTS_BASE64`.
7. Actions → **iOS release** → Run workflow on `dev` with **dry_run**. The "Profiles against entitlements" table must be all ✅.
8. Run again with **upload**. The team gets the build in TestFlight.

No code change is needed for any of this.

## Done

**Unsigned packaging, every dev build** (`.github/workflows/ios-release.yml`, job `package`)
- `xcodebuild archive` for `generic/platform=iOS` with signing off, on `macos-26` with the newest stable Xcode (26.6, iOS SDK 26.5 tonight), printed in the summary.
- Artifacts named `PrompTugal-<version>-<build>-<sha>-…`: unsigned .ipa, simulator .app zip, .xcarchive (with dSYMs), `build-info.json` and release notes.
- Job summary: Info.plist values, size breakdown, largest files, size check against `size-budget.json` and the latest dev build, the targets to sign with each one's entitlements and profile secret, and a warning if the privacy manifest is missing.
- Fails if the app stops being built for both iPhone and iPad (`UIDeviceFamily` 1,2).
- Green on dev throughout the night: runs 11, 13, 16, 18, 24, 28, 31, 32, 35 and 36; run 37 building at 08:45 (latest packaged app: iOS 18 minimum, app, widgets and intents extensions, SGitVault).

**Build numbers:** `CFBundleVersion` = this workflow's run number + `IOS_BUILD_OFFSET` (repository variable, default 100), passed as `CURRENT_PROJECT_VERSION`. `MARKETING_VERSION` stays in the project. README updated by the editor to match.

**Signed path and TestFlight** (job `testflight`, by hand or on tag `ios-v*`, never on push)
- Skips cleanly with one `skipped: secret X missing` line per missing secret (runs 5, 8 and 25).
- Manual signing (default): .p12 into a temporary keychain, App Store profiles installed, one profile per target through a CI-only xcconfig, profiles checked against each target's entitlements before archiving.
- Automatic signing (alternative): `-allowProvisioningUpdates` with the API key.
- Export with `app-store-connect` ExportOptions, upload with `xcodebuild -exportArchive` (destination upload) and the API key; `altool --upload-package` as fallback. No third-party tools.
- After upload: waits for processing, answers export compliance, sets "What to Test" from each session's status summary and the commits (`asc.py`, Python standard library and `openssl`).
- Inputs: `dry_run`, `internal_only`, `signing`, `build_number`, `source_ref`.
- Keychain, profiles and key removed at the end of every run. No secret values in logs.

**Other**
- `.github/workflows/ios-submit.yml`: App Store review submission, by hand, dry run unless confirmed. Backlog by Dinis's priority (internal first).
- Export compliance: the app uses only encryption built into iOS, so `ITSAppUsesNonExemptEncryption = NO` (added by platform).
- Privacy manifest: required-reason APIs found in the code (`UserDefaults`, file timestamps), draft written, added by platform.
- Website: `latest-build.sh` feeds the site's latest CI build panel (wired by the editor).
- CI load: runs only on dev pushes that change more than docs, never cancels a started run, at most one running and one waiting.

## Open items

- The signed path has never run with real secrets. The first dry run will be its first real test. If it fails, the summary names the step and the missing capability.
- Signing and upload need macOS runners. Tonight the queue was often 20–60 minutes, so allow for that in the morning.
- App Store submission, external testers and the App Store listing are later. Metadata stays manual.

## Blocked

Nothing.

## Needs from others

Nothing open. Platform added the encryption key and the privacy manifest. The editor wired the latest-build panel and updated the README.
