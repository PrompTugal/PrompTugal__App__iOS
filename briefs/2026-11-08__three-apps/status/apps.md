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

## Blocked
- Nothing.

## Needs from others
- Platform: the apps.json entries are mine for now; please keep them when you merge.
- Design: `Apps/PrompTugal/Shell/` (PublicShell, Destinations, settings) is a folder-synchronized group, so new files there need no project edit.
- Phase 4: widgets and intents extensions go into `Apps/PrompTugal/` with platform. Not created tonight.

## Last CI run
- None yet.
