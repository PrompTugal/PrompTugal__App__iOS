# Platform status

> Phase 1 and 2 are on dev. AppLinks.scheme (ce3602e) is merged with origin/dev into 439ad32; run 301 (self-hosted) is queued. Phase 4 prepared, not started.

## Done
- Phase 1: workspace, seven empty packages, apps.json, check scripts, CI jobs. On dev (9220d7e).
- Phase 2: moved into Packages/PTCore: Design/, HTTPClient and HTTPLog, Content.swift (Event, Lisbon, EventDetail, Story, FeedClient), LisbonDay, BuildInfo, RemoteFeed, LoadPhase, FeedCache, Wire / LooseText / LooseScalar / WireDate, TimingBar and FilterChip. Everything they expose is public. Run 278 green: Release build, App build, SGitVault, package tests, iPhone and iPad unit tests, apps.json check.
- Tests with no app host moved to PTCore/Tests: HTTP client, Lisbon time, build info decoding.
- apps.json "all" now includes .github/scripts/.
- Merged origin/dev (PTVaultUI, e5328ff) with no conflicts.

## In progress
- Nothing. Idle until phase 3 packages are on dev.

## Phase 4 plan (Team project move). Not started; waits for phase 3 on dev
Checked against the code on dev at 116a350. I do these in order, in one branch, and CI runs after step 8.

1. **Layout.** `git mv` only.
   - `PrompTugal.xcodeproj` to `Apps/Team/Team.xcodeproj`.
   - `PrompTugal/` (what is left after phase 3) to `Apps/Team/Sources/`, with `App/PrompTugalApp.swift` renamed `TeamApp.swift`.
   - `PrompTugalTests/` to `Apps/Team/Tests/`, `PrompTugalUITests/` to `Apps/Team/UITests/`.
   - `Config/PrompTugal*` to `Apps/Team/Config/` (renamed Team*). `Config/Local.xcconfig.example` stays at the root.
   - `Scripts/build-info.sh` stays at the root (all three apps share it).
2. **Project edits (sed on project.pbxproj, then check_apps.py).**
   - Target and product names: PrompTugal to Team. Project name Team. Test targets TeamTests, TeamUITests.
   - Root groups `PrompTugal`, `PrompTugalTests`, `PrompTugalUITests` become `Sources`, `Tests`, `UITests`.
   - Package `relativePath = Packages/X` becomes `../../Packages/X` (check_apps.py reads the last path part, so it still passes).
   - Build phase script: `"$SRCROOT/../../Scripts/build-info.sh"`. In `build-info.sh` set `root` to `$SRCROOT/../..`, so git and `VERSION` are read from the repo root.
   - `TEST_HOST` and the product path: `Team.app/.../Team`.
   - Drop the Shared group (NowNext is in PTAgenda by then), and the widgets and intents targets, their embed phases and target dependencies.
3. **Identity.**
   - Bundle `news.promptugal.team` (tests `.tests`, uitests `.uitests`).
   - `MARKETING_VERSION = 0.4.0` (Dinis: one version for all apps).
   - Display name "PT Team" (`INFOPLIST_KEY_CFBundleDisplayName`).
   - URL scheme `ptteam` in `Team-Info.plist`, and its `CFBundleURLName` is the new bundle ID.
   - BGTask ids `news.promptugal.team.refresh` and `news.promptugal.team.vault-refresh` in `BGTaskSchedulerPermittedIdentifiers`.
   - App group `group.news.promptugal.team` in the entitlements, and `webcredentials:promptugal.news` stays. Remove the widgets entitlements file from Team.
4. **Entry point (`TeamApp.swift`, mine).** `TeamBackground.identifier` becomes `news.promptugal.team.refresh`. `VaultBackground.register(taskIdentifier: "news.promptugal.team.vault-refresh")`. Call `TeamLanesWiring.install()` at launch.
5. **The URL scheme string.** `promptugal://` is in Shell/AppShell.swift and Destinations.swift (design), and in ReminderPlan and ReminderScheduler (team, PTAgenda). Per the ruling the scheme comes from the app. I need a one-line seam from team: `ReminderPlan` takes `scheme` from an app-set static. I will ask the conductor when I reach this step.
6. **Schemes.** `git mv` the two shared schemes to `Apps/Team/Team.xcodeproj/xcshareddata/xcschemes/Team.xcscheme` and `TeamScreens.xcscheme`. Replace BlueprintName, BuildableName and `container:` paths with the Team names.
7. **Keychain services** (`news.promptugal.reader.ai`, `.lanes`, `.lanes.identity`) are collab's and vault's strings. The ruling says teammates import their key again, so no change needed. Tell collab if they want the new prefix.
8. **Workspace and CI.** `PrompTugal.xcworkspace` points at `Apps/Team/Team.xcodeproj`. `apps.json` team entry: project `Apps/Team/Team.xcodeproj`, scheme `Team`, bundle `news.promptugal.team`, `paths: ["Apps/Team/"]`, packages `["PTLanes","PTAsk"]`. Root `ios.yml` env `PROJECT` and `SCHEME` and `scripts/release/lib.sh` defaults are release's; release already has the Apps/Team paths in `apps.py`.
9. **Widgets and intents.** The apps session owns the PrompTugal project. After they confirm their paths, I `git mv PrompTugalWidgets` and `PrompTugalIntents` to `Apps/PrompTugal/Widgets` and `Apps/PrompTugal/Intents` (or where they say), and remove them from the Team project in step 2.

Open point for the conductor: step 5 (URL scheme seam) and where the apps session wants Widgets and Intents.

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

## Handoff (01:35 UTC, 8 Nov)

- **Branch head:** `split/platform`. The last code commit is ce3602e (`AppLinks.scheme` in PTCore). A status-page commit follows it. Everything is pushed; nothing is local.
- **Last CI run:** run 292 (id 42433932986), commit ce3602e, dispatched at 01:21 UTC. It was still queued when I stopped; I did not read a result. Read it, and merge ce3602e into dev if green. Before that: run 278, commit f1be270, green (7 of 7 jobs), and it is on dev (116a350).
- **Not half-done:** nothing is half-done. No file has been moved for phase 4.
- **Check-ins:** I deleted my three pending send_later reminders. I will dispatch no more CI.
- **Exact next step:** read run 292. If red, fix the failure in `Packages/PTCore/Sources/PTCore/Feed/AppLinks.swift` or `Packages/PTCore/Tests/PTCoreTests/AppLinksTests.swift`. The code uses `nonisolated(unsafe) static var`; if Swift 6 rejects it, use an `OSAllocatedUnfairLock` or a `@MainActor` property and tell team and design. If green, tell the conductor so ce3602e is merged. Then phase 4, following the nine steps in "Phase 4 plan" above, once the phase 3 packages are on dev.
- **Rules to remember:**
  - Pushes to `split/**` do not start `ios.yml`. Start it with workflow_dispatch on the branch.
  - Merge `origin/dev`; never rebase or force-push.
  - Team Xcode scheme is "Team" (+ "TeamScreens"); `ptteam` is only the URL scheme.
  - `MARKETING_VERSION = 0.4.0` in all projects; CI sets the real one from the tag.
  - `apps.json` entries for "promptugal" and "riskmandate" are edited by the apps session; I keep "team", "packages" and "all". Until phase 4 the "team" entry keeps bundle `news.promptugal.reader` and project `PrompTugal.xcodeproj`; change both in the commit that moves the project.
  - The Team entry point calls `TeamLanesWiring.install()` and `VaultBackground.register(taskIdentifier: "news.promptugal.team.vault-refresh")`, and sets `AppLinks.scheme = "ptteam"` before any view reads it.
  - Widgets and Intents move to `Apps/PrompTugal/Widgets` and `Apps/PrompTugal/Intents` with `git mv`; the apps session adds the targets to its own project, and I remove them from the Team project.
- **Open questions:**
  - The `promptugal://` strings in AppShell.swift, Destinations.swift, ReminderPlan.swift and ReminderScheduler.swift must read `AppLinks.scheme`. Design and team were told. Check it before phase 4 step 5.
  - The rest of `Dashboards/WireModels.swift` (Wire.Me, Person and so on) is still in the app; design decides where it goes.
  - Keychain service names (`news.promptugal.reader.ai`, `.lanes`, `.lanes.identity`) keep the old prefix; the ruling says teammates import their key again.

## Update (02:40 UTC, 8 Nov, account B)
- Merged origin/dev (36508b6 runner choice) into split/platform: 439ad32, no conflicts.
- Cancelled run 292 (GitHub-hosted, ce3602e). Dispatched run 301 on 439ad32 with runner=self-hosted. Waiting for it, then READY to the conductor.
- Phase 4: no file moved. Waiting for the conductor's go.
