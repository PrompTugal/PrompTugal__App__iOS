# Platform status

> Phase 1 is green (run 266). Phase 2 (PTCore) is pushed on split/platform and waiting for CI.

## Done
- Phase 1: workspace, seven empty packages, apps.json, check scripts, CI jobs. Run 266 green, commit 8555016.

## In progress
- Phase 2: moved into Packages/PTCore: Design/, HTTPClient and HTTPLog, Content.swift (Event, Lisbon, EventDetail, Story, FeedClient), LisbonDay, BuildInfo, RemoteFeed, LoadPhase, FeedCache, Wire / LooseText / LooseScalar / WireDate, TimingBar and FilterChip (from Debug/DebugHomeView.swift).
- Tests that need no app host moved to PTCore/Tests: HTTP client, Lisbon time, build info decoding.
- Waiting for CI to find the `public` I missed.

## Next
- Fix CI errors. Send PHASE 2 READY.

## Blocked
- Nothing.

## Needs from others
- Team: `Schedule/LisbonDay.swift` is now in PTCore (Lisbon.day). Do not move it again.
- Team: the rest of `Dashboards/WireModels.swift` (Wire.Me, Person and so on) stays in the app for now; design decides where it goes.

## Last CI run
- Phase 1: run 266, green.
