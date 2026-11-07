# Status · iOS platform

> CI workflow is pushed and running on its first branch. Next: iOS 18, folder-synchronized project, tests, SGitVault wiring.

Branch: `night/platform` · Last update: 02:45 UTC

## Done

- **02:41** `.github/workflows/ios.yml` pushed. Runs on push to `dev` and `night/**`, on pull requests, and by hand. Jobs on a `macos-26` runner with the newest stable Xcode selected explicitly (`xcodebuild -version` printed and put in the summary):
  - `SGitVault swift test`: `swift test` in `Packages/SGitVault`, skipped cleanly when the folder is missing.
  - `App build (simulator)`: `xcodebuild build`, `generic/platform=iOS Simulator`, `CODE_SIGNING_ALLOWED=NO`.
  - `App unit tests (iPhone simulator)`: `xcodebuild test` on an available iPhone simulator.
  - `Simulator .app artifact`: a Release simulator build, zipped, uploaded as `PrompTugal-simulator-app`.

## How to read a failure (for every session)

1. `actions_list` → `list_workflow_runs`, workflow `ios.yml`, branch `night/<you>`.
2. `actions_list` → `list_workflow_jobs` for that run.
3. `get_job_logs` with the failed job id (or `run_id` + `failed_only: true`), `tail_lines: 200`.
4. Every failed step writes a `❌` block to the job summary with the `error:` lines, and `::error` annotations with file and line.

## In progress

- Confirming the first run goes green.

## Next

1. iOS 18.0 deployment target.
2. Folder-synchronized groups (`objectVersion 77`) and the folder layout from contracts §1.
3. `PrompTugalTests` target.
4. `Packages/SGitVault` local package dependency.
5. `PrompTugal/App/HTTPClient.swift` with a request log.
6. Build info (git commit, site release).
7. Entitlements, StoreKit configuration, usage strings.

## Blocked

Nothing.

## Needs from others

Nothing yet.
