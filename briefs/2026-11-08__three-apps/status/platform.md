# Platform status

> Phase 1 is on dev. Phase 2 (PTCore) is green on split/platform: run 278, commit f1be270. Waiting for the conductor to merge, then phase 4.

## Done
- Phase 1: workspace, seven empty packages, apps.json, check scripts, CI jobs. On dev (9220d7e).
- Phase 2: moved into Packages/PTCore: Design/, HTTPClient and HTTPLog, Content.swift (Event, Lisbon, EventDetail, Story, FeedClient), LisbonDay, BuildInfo, RemoteFeed, LoadPhase, FeedCache, Wire / LooseText / LooseScalar / WireDate, TimingBar and FilterChip. Everything they expose is public. Run 278 green: Release build, App build, SGitVault, package tests, iPhone and iPad unit tests, apps.json check.
- Tests with no app host moved to PTCore/Tests: HTTP client, Lisbon time, build info decoding.
- apps.json "all" now includes .github/scripts/.
- Merged origin/dev (PTVaultUI, e5328ff) with no conflicts.

## In progress
- Nothing. Idle until phase 3 packages are on dev.

## Next
- Phase 4: move the root project to Apps/Team/Team.xcodeproj (bundle news.promptugal.team, scheme Team and TeamScreens, URL scheme ptteam://, MARKETING_VERSION 0.4.0). The apps session makes the PrompTugal and RiskMandate projects.
- Team entry point calls TeamLanesWiring.install() (it calls VaultCollabAccess.install()) and passes the BGTask id to VaultBackground.register.

## Blocked
- Nothing.

## Needs from others
- Team: Schedule/LisbonDay.swift is now in PTCore (Lisbon.day). Do not move it again.
- Design: the rest of Dashboards/WireModels.swift (Wire.Me, Person and so on) stays in the app for now. Wire, LooseText, LooseScalar and WireDate are in PTCore.
- Everyone: pushes to split/** do not start ios.yml. Start it with workflow_dispatch on your branch.

## Last CI run
- Run 278, commit f1be270: green (all 7 jobs).
