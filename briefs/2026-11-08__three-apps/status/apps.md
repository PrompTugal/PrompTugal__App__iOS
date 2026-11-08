# Apps status

> RiskMandate is green and on dev. PrompTugal run 316 is nearly done with no failures; I report to the conductor when it finishes.

## Done
- Phase 4 (07:45 UTC): merged split/platform; widgets and intents targets added to PrompTugal.xcodeproj (news.promptugal.reader.widgets and .intents, app group, embed phases, link PTAgenda); shortcut images copied; file-sharing and open-in-place keys set; PrompTugalApp wires AppLinks, schedule, NowNextPublisher and the vault task id. Not yet built: run dispatched next.
- `Apps/RiskMandate/RiskMandate.xcodeproj`: bundle ai.riskmandate.app, version 0.4.0, one screen, privacy manifest, placeholder icon, one unit test, scheme "RiskMandate". Links PTCore.
- `Apps/PrompTugal/PrompTugal.xcodeproj`: bundle news.promptugal.reader, version 0.4.0, `PrompTugalApp` and placeholder `PublicShell`, schemes "PrompTugal" and "PrompTugalScreens", unit and UI test targets. Links PTAsk and its closure (PTCore, PTWeb, PTAgenda, PTNews, PTVaultUI, SGitVault).
- Info: scheme `promptugal`, two background task ids, WKAppBoundDomains promptugal.news only, camera for vault QR only, no NFC, no speech.
- `apps.json`: entries "promptugal" and "riskmandate", both testflight false. `check_apps.py` and its tests pass on Linux.

## In progress
- Waiting for run 316 (promptugal) to finish.

## Next
- Fix whatever CI finds. Add packages to PrompTugal as they land (PTLanes is not in it by design).

## Phase 4 plan (extensions), starts when the conductor says
1. Platform `git mv`s PrompTugalWidgets to `Apps/PrompTugal/Widgets` and PrompTugalIntents to `Apps/PrompTugal/Intents`.
2. I add two targets to `PrompTugal.xcodeproj`: `PrompTugalWidgets` (news.promptugal.reader.widgets, links PTAgenda) and `PrompTugalIntents` (news.promptugal.reader.intents). Both use App Group group.news.promptugal.reader, folder-synchronized groups, own Info.plist and entitlements, version 0.4.0.
3. Embed widgets in "Embed Foundation Extensions" and intents in "Embed ExtensionKit Extensions", as the root project does. Add target dependencies.
4. Run check_apps.py (PTAgenda is already in the closure), dispatch app=promptugal, and check `scripts/release/check-embedded.sh` passes.
5. Then set promptugal testflight true when the conductor switches.

6. (conductor, from editor) Copy the website shortcut images (`Shortcut*.imageset`) from `PrompTugal/App/Resources/Assets.xcassets` into `Apps/PrompTugal/Resources/Assets.xcassets`, so the PrompTugal sidebar has icons. Team keeps its copy. Phase 4.

7. (team, split/team d599843, not on dev yet) NowNext moves into PTAgenda: `NowNextSnapshot`, `SharedContainer`, `LisbonClock`, public `NowNextPublisher`. Once it is on dev: widgets and intents targets link PTAgenda; their three Swift files need `import PTAgenda`; in PrompTugalApp.swift set `AgendaHub.publishNowNext = { agenda, saved in NowNextPublisher.publish(agenda: agenda, saved: saved) }` and call it from agendaDidLoad with the schedule's picks, as TeamFeatures does.

8. (collab, split/collab 86cf060; waits for PTSync on dev and the conductor's go) PTSync (PTCore only): apps.json promptugal packages += PTSync; project reference + product + framework build file; Info.plist BGTaskSchedulerPermittedIdentifiers += news.promptugal.reader.sync; PrompTugalApp.swift imports PTSync, PublicSync.start() at the end of init, SyncBackground.schedule() on background, PublicSync.refresh() on active; new Apps/PrompTugal/Shell/PublicSync.swift (Shell is design's folder: need a ruling on who adds it). Diff is in collab's status page. Later: Seed folder resource and scripts/seed/fetch_seed.py before xcodebuild.

## RiskMandate upload
- Dinis: same Apple account. Set `testflight: true` after the first green CI run. Upload waits for the App Store Connect record; release must skip with a clear line until then (conductor to confirm with release).

## Blocked
- Nothing.

## Needs from others
- Platform: the apps.json entries are mine for now; please keep them when you merge.
- Design: `Apps/PrompTugal/Shell/` (PublicShell, Destinations, settings) is a folder-synchronized group, so new files there need no project edit.
- Phase 4: widgets and intents extensions go into `Apps/PrompTugal/` with platform. Not created tonight.

## Last CI run (12:00 UTC)
- Public app first upload failed processing (ITMS-90683, missing NSSpeechRecognitionUsageDescription). Fixed on 326147f (merged to dev as fb7cd76, dry run 94 proved it in the signed .ipa).
- Quick run 380 (promptugal, 7ba2c14, macos-26): queued then running at 11:56; no failure yet. 7ba2c14 = 326147f + PTNowNext relink (widgets and intents no longer link WebKit), scene manifest from Info.plist (external display), WebsitesPublic, no ShortcutWebSummit, privacy collected-data entry, knownRegions en/pt-PT/pt-BR, PTExplore, vault background DEBUG-only, no second ScheduleStore.
- 7580c50 on top: ScreensTests.swift only (UI tests; proved by the screens run).

## Summit queue (conductor's order; freeze 16:00 UTC)
1. Done and pushed: purpose strings, PTNowNext relink, knownRegions, PTExplore, privacy entry, N2 vault DEBUG-only, screens tests.
2. Waiting: PTSync wiring (PTSync green on split/collab and the conductor's go; glue in PrompTugalApp.swift or Apps/PrompTugal/App/PublicSync.swift, plus a new Apps/PrompTugal/App synchronized group if a file is added).
3. Not mine: -PTNow in the app (design: PublicFeatures sets team's AgendaClock.override and seeds picks).
4. App Store build settings review with review.B (nothing requested yet).
5. Known gap for design: PublicFeatures.agendaDidLoad must call NowNextPublisher.publish for the widget feed.

## Handoff
Handed to a new session (account B) at the conductor's request, 01:3x UTC. Branch split/apps.

- **Head:** see the last commit on split/apps (it contains this page). Code head before this page: 3a63963 (origin/dev merged, PTCore on dev).
- **Runs (all dispatched with ios.yml, none finished when I stopped):**
  - 285: app=riskmandate on 7d28094. The iPhone unit tests passed (project compiles, test runs). Builds and iPad tests were queued.
  - 289 and 290: on 3a63963, one for riskmandate and one for promptugal (I did not note which number is which). Queued or pending.
  - 284 on 7dea0d8 was cancelled (stale).
  - Nothing has been reported green to the conductor yet.
- **RiskMandate:** `Apps/RiskMandate/RiskMandate.xcodeproj`, bundle ai.riskmandate.app, 0.4.0, links PTCore (not imported), scheme RiskMandate, one screen, privacy manifest, placeholder icon, one test. apps.json: testflight false. Dinis: same Apple account publishes it, so set `testflight: true` once its first CI run is green. The upload needs the App Store Connect record first; release must skip with a "no App Store Connect record" line until then (conductor to confirm with release).
- **PrompTugal:** `Apps/PrompTugal/PrompTugal.xcodeproj`, bundle news.promptugal.reader, 0.4.0, schemes PrompTugal and PrompTugalScreens, unit and UI test targets. apps.json lists packages ["PTAsk"], so the closure is PTCore, PTWeb, PTAgenda, PTNews, PTVaultUI, SGitVault (7 references in the project). testflight false until phase 4. Not yet built by CI.
- **File split with design:** I own `PrompTugalApp.swift`, the .xcodeproj, xcconfig, Info.plist, entitlements and the privacy manifest. Design owns `Apps/PrompTugal/Shell/` (PublicShell, Destinations, settings view), a folder-synchronized group, so new files there need no project edit.
- **Phase 4 extensions:** see the plan above. Wait for the conductor to say phase 4 has started.
- **Project generation:** both .pbxproj files were written by a script (not in the repo) because no Xcode is available. Edit them by hand carefully; `check_apps.py` must pass before every push.
- My scheduled check-ins are deleted. I dispatch no more CI.
