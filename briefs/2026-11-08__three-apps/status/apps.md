# Apps status

> The RiskMandate and PrompTugal projects are written and pushed on split/apps. Neither has been built yet: CI is the first compiler.

## Done
- `Apps/RiskMandate/RiskMandate.xcodeproj`: bundle ai.riskmandate.app, version 0.4.0, one screen, privacy manifest, placeholder icon, one unit test, scheme "RiskMandate". Links PTCore.
- `Apps/PrompTugal/PrompTugal.xcodeproj`: bundle news.promptugal.reader, version 0.4.0, `PrompTugalApp` and placeholder `PublicShell`, schemes "PrompTugal" and "PrompTugalScreens", unit and UI test targets. Links PTAsk and its closure (PTCore, PTWeb, PTAgenda, PTNews, PTVaultUI, SGitVault).
- Info: scheme `promptugal`, two background task ids, WKAppBoundDomains promptugal.news only, camera for vault QR only, no NFC, no speech.
- `apps.json`: entries "promptugal" and "riskmandate", both testflight false. `check_apps.py` and its tests pass on Linux.

## In progress
- Dispatching ios.yml on split/apps for riskmandate, then promptugal.

## Next
- Fix whatever CI finds. Add packages to PrompTugal as they land (PTLanes is not in it by design).

## Phase 4 plan (extensions), starts when the conductor says
1. Platform `git mv`s PrompTugalWidgets to `Apps/PrompTugal/Widgets` and PrompTugalIntents to `Apps/PrompTugal/Intents`.
2. I add two targets to `PrompTugal.xcodeproj`: `PrompTugalWidgets` (news.promptugal.reader.widgets, links PTAgenda) and `PrompTugalIntents` (news.promptugal.reader.intents). Both use App Group group.news.promptugal.reader, folder-synchronized groups, own Info.plist and entitlements, version 0.4.0.
3. Embed widgets in "Embed Foundation Extensions" and intents in "Embed ExtensionKit Extensions", as the root project does. Add target dependencies.
4. Run check_apps.py (PTAgenda is already in the closure), dispatch app=promptugal, and check `scripts/release/check-embedded.sh` passes.
5. Then set promptugal testflight true when the conductor switches.

## RiskMandate upload
- Dinis: same Apple account. Set `testflight: true` after the first green CI run. Upload waits for the App Store Connect record; release must skip with a clear line until then (conductor to confirm with release).

## Blocked
- Nothing.

## Needs from others
- Platform: the apps.json entries are mine for now; please keep them when you merge.
- Design: `Apps/PrompTugal/Shell/` (PublicShell, Destinations, settings) is a folder-synchronized group, so new files there need no project edit.
- Phase 4: widgets and intents extensions go into `Apps/PrompTugal/` with platform. Not created tonight.

## Last CI run
- None yet.
