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

## RiskMandate upload
- Dinis: same Apple account. Set `testflight: true` after the first green CI run. Upload waits for the App Store Connect record; release must skip with a clear line until then (conductor to confirm with release).

## Blocked
- Nothing.

## Needs from others
- Platform: the apps.json entries are mine for now; please keep them when you merge.
- Design: `Apps/PrompTugal/Shell/` (PublicShell, Destinations, settings) is a folder-synchronized group, so new files there need no project edit.
- Phase 4: widgets and intents extensions go into `Apps/PrompTugal/` with platform. Not created tonight.

## Last CI run (09:30 UTC)
- 340 promptugal, a53e3cc (phase 4, macos-26): green, full run (Debug, Release, iPhone, iPad, all packages, result job).
- ios-release run 83, df1baa1, app=promptugal dry_run internal_only: success, but only the unsigned archive job ran (bundle id matches, widgets and intents embedded per the build log). The TestFlight job, which has the entitlement guard, was skipped because promptugal testflight is false. Not yet proven: the guard. Asked the conductor whether to flip testflight for one dry run.
- Head df1baa1 = a53e3cc + origin/dev (only Apps/Team/Tests/AppReviewTests.swift and VERSION differ).
- READY sent to the conductor. testflight false.

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
