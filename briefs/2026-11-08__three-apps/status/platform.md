# Platform status

> Support role. Event.showsAs (PTCore, from the feed's shows_as) is green on split/platform dff3c24 (quick run 420, app=team); the conductor merges it to dev. I never push to dev. The SecretStore/SpeechDictation move stays parked in history (e7a6ac4, reverted by db548cd).

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

## Update (02:57 UTC)
- Run 301 green on 439ad32; the conductor merged it to dev as 5500c02.
- Waiting for phase 3 on dev (PTWeb/PTAgenda, PTNews, CollabSeams/VaultCollabAccess, PTLanes, PTAsk). Then phase 4 per the nine steps above.

## Update (07:12 UTC): phase 4 pushed, proof pending
- Commit 09623bd. Merged origin/dev (02f3624, v0.4.5) first, no conflicts. Done in one branch:
  - Layout: `Apps/Team/Team.xcodeproj`, `Sources/`, `Tests/`, `UITests/`, `Config/` (Team.xcconfig, Team.entitlements, Team-Basic.entitlements, Team-Info.plist). `git mv`, so history follows.
  - Identity: bundle `news.promptugal.team` (`.tests`, `.uitests`), 0.4.0, "PT Team", URL scheme `ptteam`, BGTask ids `news.promptugal.team.refresh` and `.vault-refresh`. Schemes `Team` and `TeamScreens`. Module name `Team` (tests use `@testable import Team`).
  - `TeamApp.swift`: sets `AppLinks.scheme = "ptteam"`, calls `TeamLanesWiring.install()`, registers `news.promptugal.team.vault-refresh`.
  - Entitlements kept: `com.apple.developer.associated-domains` (`webcredentials:promptugal.news`, read by the vault passkey in PTVaultUI) and `usernotifications.time-sensitive` (ReminderScheduler uses `.timeSensitive`). Dropped: the App Group. Only NowNext read the group container, and the Team app has no widgets, so `group.news.promptugal.team` is not declared.
  - Widgets and Intents: `git mv` to `Apps/PrompTugal/Widgets` and `Apps/PrompTugal/Intents`, removed from the Team project. Their xcconfig and entitlements moved to `Apps/PrompTugal/Config/`. The apps session adds the targets.
  - NowNext: `Shared/NowNext.swift`, `NowNextPublisher` and its test moved into PTAgenda (`NowNext/`) with `public` API, so the widgets link PTAgenda. In the Team app the App Group is absent, so `publish` returns without writing.
  - `apps.json` "team": project `Apps/Team/Team.xcodeproj`, scheme `Team`, bundle `news.promptugal.team`, paths `Apps/Team/`, packages PTLanes, PTAsk. `check_apps.py` OK. Workspace points at the new project.
  - Tests: BGTask ids and the reminder scheme (`ptteam`) updated; the StoreKit file path is `Sources/Store/PrompTugal.storekit`.
- Left as is: `Schedule/ScheduleIntents.swift` stays in the Team app (it reads `TeamFeatures.shared`, so it cannot move to the public app unchanged). StoreKit product ids and Keychain service names keep the `reader` prefix.
- For other roles: `website/build.py`, `validate.py` and `test_site.py` on dev read `PrompTugal.xcodeproj` and `PrompTugal/Store/...`. Editor's branch (admin.public_project) already handles the moved layout; merge editor with this branch. `scripts/release/lib.sh` still defaults PROJECT to `PrompTugal.xcodeproj` (release's file; the workflows pass the project from apps.json).
- Next: read the ios.yml run, fix, then the ios-release dry run (app=team) and READY.

## Update (08:35 UTC)
- Merged split/team (NowNext in PTAgenda, d599843). My first merge commit carried conflict markers in `NowNext.swift` (d9ffef5); fixed in f0c53a9 by taking team's files. Run 335 (on d9ffef5) was cancelled before it ran. Always grep for conflict markers before committing a merge.
- Run 336 (f0c53a9): Team Release build compiled; Team iPad tests failed only on `@testable import PrompTugal` in AppReviewTests (the merge restored the old module name). Fixed in cd02fa7; cancelled 336.
- Run 338 (cd02fa7), so far green: apps.json check, Debug and Release builds (Team, PrompTugal, RiskMandate where run), Team iPad tests, PrompTugal iPhone tests, PTAsk, PTNews, PTLanes. Still queued: Team iPhone tests, remaining package tests, RiskMandate tests.
- ios-release dry run, app=team, run 81 (id 42461685105), dispatched at 08:09, queued.
- Team entry point also sets `SharedContainer.appGroup = "group.news.promptugal.team"` so the Now/Next snapshot can never go to the PrompTugal group (Team declares no group, so nothing is written).

## Update (09:02 UTC): READY sent
- Run 338 green on cd02fa7 (all jobs). Release dry run 81 (app=team) green: unsigned archive, bundle id matches apps.json, sign and export with associated-domains and time-sensitive, no upload.
- READY sent to the conductor with both run ids.
- Open for others: the apps session adds the widgets and intents targets to Apps/PrompTugal (sources in `Apps/PrompTugal/Widgets` and `Intents`; link PTAgenda for `SharedContainer`, `NowNextSnapshot`, `LisbonClock`). Their xcconfig and entitlements are in `Apps/PrompTugal/Config/`.

## Update (11:20 UTC): SecretStore and SpeechDictation into PTCore
- Phase 4 merged to dev as d94a5b4 (cd02fa7, run 338, dry run 81).
- New task from the conductor (collab noted the duplicates): one copy of `SecretStore` (with `SecretStoreError`, `KeychainSecretStore`, `MemorySecretStore`) and one `SpeechDictation` now live in `Packages/PTCore/Sources/PTCore/Secrets` and `Speech`, public. Both copies are gone from PTAsk and PTLanes. `KeychainSecretStore(service:)` has no default; `AIKeyStore` passes `news.promptugal.reader.ai` and `LanesStore` passes `news.promptugal.reader.lanes`, so the Keychain services are unchanged. PTCore builds in Swift 5 language mode now (every other package and the apps already do). New `SecretStoreTests` in PTCore.
- Commit e7a6ac4 on split/platform, merged with origin/dev v0.4.12 first. Run 348 (ios.yml app=all, macos-26): the PrompTugal iPhone unit tests passed (they build PTCore and PTAsk); the rest was queued at 11:18.
- `scripts/release/lib.sh` PROJECT default: asked release; I edit it only if they say yes. No answer yet.
- Reviewed team's PTNowNext reference in `Apps/Team/Team.xcodeproj` (split/team e70d928): one packageReferences line and one XCLocalSwiftPackageReference block, nothing else. Fine.

## Update (11:30 UTC): parked, now support
- New priority from the conductor (briefs/2026-11-08__summit-app-store/README.md): everything goes to the summit app. The SecretStore/SpeechDictation dedupe was not fully green, so it is parked: commit e7a6ac4 stays on split/platform, run 348 cancelled (only the PrompTugal iPhone tests had run, green). To resume: merge origin/dev, dispatch ios.yml, READY after a green run. Nobody depends on it.
- Support: I review package and project changes from apps, deck and team for dependency-graph and `check_apps.py` problems before they reach the conductor.

## Update (12:25 UTC): consolidated into split/rc
- Cookie fix: `HTTPClient.makeSession()` sets `httpCookieStorage = nil`, `httpShouldSetCookies = false`, `httpCookieAcceptPolicy = .never`, with a test (b30c9f7 on split/platform). The conductor folded it into split/rc 75203d5 (dev + design 1b5a0a7 + team d310767 + b30c9f7); the full run is there. No runs of mine are queued.
- Reviewed split/i18n a8aee16 for package risk earlier: no blocker (see the message to the conductor and i18n; follow-ups: pt-PT and pt-BR in the PrompTugal project knownRegions, widget bundle check, PTExplore resources).
- Standing by as support for graph and check_apps reviews; not dispatching CI.

## Update (19:30 UTC, 9 Nov): Event.showsAs
- Conductor's request (news-app clash fixes): `Event.showsAs: String?` in PTCore, decoded from "shows_as" ("free" or "busy"), optional so old feeds decode, init default nil, decode tests. Done on split/platform dff3c24 (merged origin/dev 556f4d3 first). Quick run 420 (ios.yml app=team, macos-26) green. Sha sent to the conductor and to team.
- The conductor asked me to push to dev myself; I did not: my standing rules say only the conductor pushes to dev. I told them, and they merge dff3c24.
