# Debrief: devops.status@promptugal.dinis (workstream D, CI status and CI speed)

> The hand-over of the CI status agent: what it owns (ci-status.yml, the status page and app screen, the faster night and dev builds, tf.py set-app-info), how it works, the measured numbers, lessons and the first things to do.

Written 16 November 2026, ~15:30 UTC, when Dinis paused the PrompTugal agents to move them to other accounts. For a fresh session that knows nothing. No keys, tokens or credential values are in this file, and none should ever be.

## Who I was, and the mandate

- **Name:** devops.status@promptugal.dinis, a worker for conductor.a.ios@promptugal.dinis in `PrompTugal/PrompTugal__App__iOS`. I worked on branch `work/status` and pushed the same commits to `night/status` when I needed a Mac build (ios.yml builds `dev` and `night/**`, never `work/**`). The conductor merged or cherry-picked to `dev`. I never pushed to `dev` or `main`.
- **Brief:** `briefs/2026-11-15__going-local/tonight.md`, workstream D. Dinis asked to see, live, how long a push takes to reach production for the website and the iOS app, and whether the build on his iPad needs updating.
- **Added during the night by the conductor:**
  1. `tf.py set-app-info`, to rename the App Store Connect record, plan-only.
  2. "Make the builds go fast": first the night branches, then the dev path to the iPad.
- **Commit trailers:** `Agent: devops.status@promptugal.dinis` and `For: conductor.a.ios@promptugal.dinis`, plus the Co-Authored-By and Claude-Session lines the harness gives.
- **Reporting:** green builds and every result went to the conductor with `send_message` (claude-code-remote MCP), session `session_018yvwtNhGU1EEJs2oWCLqrJ`.

## What I own (all of it is on dev)

| Piece | Files | Commit on work/status → on dev |
| --- | --- | --- |
| CI status data | `scripts/ci-status/collect.py`, `.github/workflows/ci-status.yml` | 17b3f15 (merged) |
| CI status web page | `website/pages/admin/status.html`, `website/admin.py` (`ci_status`, `ci_status_html`, `duration`), `website/build.py` (`CI_STATUS_JSON` → `/ci-status.json` and the `ci_status` page token), `website/site.css` (`.status.bad`, `.status.run`), `website/test_site.py` (`test_ci_status_page`), the "CI status" step in `.github/workflows/website.yml` | 17b3f15 |
| CI status in the app | `Packages/PTLocal/Sources/PTLocal/Status/` (`CIStatusModels.swift`, `CIStatusStore.swift`, `CIStatusView.swift`), `Packages/PTLocal/Tests/PTLocalTests/CIStatusTests.swift`, a More entry `local.ci-status` in `Apps/PrompTugal/Shell/Destinations.swift` and a row in `PublicSettingsView.swift` | 17b3f15, 49e7f1e |
| App Store name and TestFlight description | `scripts/testflight/tf.py` (`set-app-info`, `app_info_problems`, `editable_app_info`, `plan_app_info_localization`, `plan_beta_app_localization`), `scripts/testflight/app-info.json`, the `set-app-info` action in `.github/workflows/testflight-ops.yml`, tests in `scripts/testflight/tests/test_tf.py`, and a rewritten `scripts/testflight/what-to-test.txt` | 5e44f3a |
| Fast night builds | `scripts/release/apps.py` (`is_branch_push`, `narrow_config_change`, `config_at`, `directly_changed_packages` + self-test), `RELEASE_BUILD` in `.github/workflows/ios.yml`, README "CI" paragraph | e90db93 → d05adc5 |
| Dev pushes test on iPhone only | `DEVICES` and the iPad step's `if:` in `.github/workflows/ios.yml`, README | d2586f2 → 7ba5a37 |
| PrompTugal uploads first | `upload_order` + `UPLOAD_FIRST` in `.github/scripts/mac-job.sh` | f86ccce → 00700d1 |

## How it works

### CI status data (`ci-status.json`)

- **Collector:** `scripts/ci-status/collect.py`, standard library only. It uses `GH_TOKEN` or `GITHUB_TOKEN` (the workflow's own token, `actions: read`) and makes about 28 API calls per run.
- **It reads:**
  - the latest runs of `ios.yml`, `ios-release.yml` and `website.yml` (skipped runs dropped)
  - PrompTugal.news's deploy (`PrompTugal/PrompTugal__News__Website`, auto-detected; it resolves to `deploy-pages.yml`; public runs, readable with the token)
- **Push to live, for dev pushes:**
  - website: push (`run.created_at`) to the `deploy` job's completion
  - iOS: push to the "Sign, export and upload to TestFlight" step (upload), and push to the "TestFlight processing" job (processed by Apple)
- **TestFlight builds per app:** read from the `build-info-apps` artifact (`<app>/uploaded.json`) of the dev runs that uploaded. This is the same artifact `scripts/release/find-build-info.sh` and the site's `ios-build.json` read.
- **Never fails:** a pipeline it cannot read is written as `available: false` with the reason.
- **Run it locally:** `python3 scripts/ci-status/collect.py --out /tmp/cs.json`. Anonymous works on this public repo within the 60-per-hour limit, but artifacts need a token.
- **Workflow:** `.github/workflows/ci-status.yml`, ubuntu, ~30 s.
  - It force-pushes `ci-status.json` (plus a README) as a single orphan commit to the data-only branch `ci-status`, using `GITHUB_TOKEN`. Such a push starts no workflow, and ios.yml never builds that branch.
  - Triggers: schedule `*/10 * * * *`; `workflow_run` of "iOS", "iOS release" and "Release and deploy" (requested and completed); push to dev, `night/**` or `work/status` touching the collector or the workflow; `workflow_dispatch`.
  - Concurrency group `ci-status`, cancel-in-progress.
- **Live URL** (CORS-open; raw caches about 5 min, and a query string asks for a fresh copy): `https://raw.githubusercontent.com/PrompTugal/PrompTugal__App__iOS/ci-status/ci-status.json`
- **Copy built with the site:** `https://ios.app.promptugal.news/ci-status.json`. `website.yml`'s build job runs the collector and the site build writes it.

### Web page

- `admin/status.html`, built at each site build: "Checked HH:MM UTC, when this page was built", push-to-live tiles, the TestFlight table and runs per pipeline.
- `website/validate.py` forbids every script except JSON-LD, so the page cannot count "N minutes ago" in the browser. The conductor decided to keep it a static snapshot with a link to the live JSON. Do not loosen the validator, and do not redeploy Pages from the scheduled job: it would race website.yml's deploy.
- Website rules: `python3 website/validate.py` and `python3 -m unittest website/test_site.py` must pass.
- `test_facts_come_from_the_project` compares against `git ls-files`, so it fails on untracked new files until they are committed.

### App screen (PTLocal/Status)

- **Store:** `CIStatusStore`, `@MainActor @Observable`.
  - Read order: the live raw URL (with a `?t=` cache-buster), then the site copy, then this device's last copy (`LocalDiskCache`, key `ci-status`).
  - It says which on screen: "Live from the ci-status branch", "The copy from the last site build", or "Offline".
- **View:** `CIStatusView` re-reads every 60 s while open.
  - "Last checked N minutes ago" comes from `generatedAt`, and turns amber after 25 min.
  - It also shows pushes on their way now, push-to-live tiles, the TestFlight build per app, and the runs per workflow.
- **"Update available":** `InstalledBuild.update(against:)` compares the TestFlight build number for this bundle id with the installed `CFBundleVersion`, as numbers. A non-numeric local build is "Not a TestFlight build". When an update exists there is an "Open TestFlight" button (`itms-beta://`).
- **Tests:** `CIStatusTests` (Swift Testing, suite "CI status", 5 tests) passed in ios.yml run 43776135903.
- **Swift notes:**
  - `PlaceModels.swift` already defines `Lenient`, so mine is `CILenient`.
  - The static helpers that tests call are `nonisolated`: View and `@MainActor` types are main-actor isolated.

### `tf.py set-app-info` (PLAN-ONLY: waits for Dinis to approve the name)

- **Command:** `tf.py set-app-info [--file scripts/testflight/app-info.json] [--yes]`.
- **What it does:**
  - reads the editable appInfo's `appInfoLocalizations` (name, subtitle) and `betaAppLocalizations` (TestFlight description)
  - prints current → new
  - changes them only with `--yes`
- **What it refuses:**
  - a name or subtitle over 30 characters, a description over 4000, or empty fields
  - if no appInfo is editable (the app is live), it says so and changes nothing: the name then changes with the next version
- **Workflow:** `testflight-ops.yml` action `set-app-info`. The "confirm" box maps to `--yes`.
- **`app-info.json`** holds a PROPOSED name "PrompTugal", subtitle "Tech news from Portugal" and a beta description.
  - NOT approved: website sherpa@ drafts the positioning, Dinis approves, the conductor edits the file and triggers it.
  - Never run it with confirm ticked without that approval.
- Unit tests: `python3 -I scripts/testflight/tests/test_tf.py`.

### Fast night builds (scripts/release/apps.py, run by ios-changes.yml)

- **The problem:** `apps.json` is in the "all" list. Night pushes diff against the merge-base with dev, so once a branch edited `apps.json` (adding PTLocal or PTTalk), every later push on it built all 4 apps (Debug and Release) and tested all 14 packages: 35 min of Mac time.
- **For pushes to work branches only** (`night/**`, `split/**`):
  - `apps.json` stands for the entries that changed: a new or changed package counts as that package, a new or changed app counts as that app. A change to the "all" list, to workflows or to scripts still means everything.
  - Only the packages the branch changed itself are tested.
  - `RELEASE_BUILD=false`.
- **Unchanged:** dev, pull requests, tags and manual runs.
- **Check:** `python3 -I scripts/release/apps.py --self-test`. Simulate a plan with `EVENT_NAME=push REF=refs/heads/night/x SHA=<sha> GITHUB_OUTPUT=/dev/null python3 scripts/release/apps.py plan`.

### Dev path to the iPad

- A dev push tests on the iPhone simulator only. The iPad simulator still runs on pull requests and full manual runs (`workflow_dispatch`, quick off). The iPhone tests still gate every upload; signing and the upload are unchanged.
- `mac-job.sh publish` uploads `UPLOAD_FIRST` (default `promptugal`, the app on Dinis's iPad) first.

## Numbers (measured)

| Run | What | Time |
| --- | --- | --- |
| 519, night/going-local, before | mac job | 35m35s: build 25m (4 apps Debug+Release ~15m, 14 packages ~10m), tests 9m53s; plus a 15m queue |
| 541, night/ios-places, after d05adc5 | mac job | 7m10s: build 3m18s (promptugal Debug 114s, PTPlaces 50s), tests 3m37s; but 25m37s queued |
| 540, dev d05adc5 (build 640, all 4 apps) | push to processed | 79m28s: queue 15m08s, build 13m27s, iPhone 11m02s, iPad 8m02s, sign+upload 14m14s (4 apps), Apple processing 16m47s |
| 504, dev (2 small apps) | push to processed | ~24 min: build 84s, iPhone 390s, iPad 427s, sign+upload 390s, processing 131s |
| website.yml, dev | push to live | median 1m25s (67 to 89 s) |
| PrompTugal.news deploy-pages.yml | run | ~7m18s |

Expected after d2586f2 and f86ccce (not yet measured): PrompTugal ready about 18 min sooner on a run like 540.

## Lessons learned

- **The Mac queue is the real cost.** GitHub-hosted macOS concurrency for the org is small. On the night of 15–16 November ~30 ios.yml runs an hour piled up: runs waited 15 to 25 minutes before starting, and newer pushes cancelled queued ones. Every push to `dev` or `night/**` takes a Mac slot. Workers should push to `work/**` (not built) and to `night/**` only when they need a compile. Conductors should batch merges into one dev push.
- **Where a dev push's minutes go:** the Mac queue, the build (1.5 to 15 min, depending on how many apps the change touches; a CI-file change means all 4), the iPhone tests (6 to 14 min), signing and upload (~3.5 min per app), and Apple's processing (2 to 17 min, which we don't control). The `.ipa` and build-info artifact uploads after publish (up to 14 min in run 501) do not delay the iPad.
- **A change to `.github/` or `scripts/release/` is in "all":** my own branch always got full builds. Correct for safety; just expect it.
- **Two GitHub zombies:** iOS run 502 (43098552165) and "Release and deploy" 193 (43098552064), from the 11 Nov push, sit 'queued' with zero jobs. They hold no concurrency slot and block nothing. An admin can force-cancel them (POST `/actions/runs/{id}/force-cancel`); I could not.
- **Access limits from the agent sandbox:**
  - The proxy refuses the Actions runners API (repo and org, 403), so I could not see the self-hosted Mac or larger runners. No macOS job tonight ran on anything but `macos-26`.
  - The proxy blocks API calls to repositories not attached to the session (PrompTugal.news). The workflow token in Actions can read them.
- **Reading CI failures:** the GitHub MCP `get_job_logs` with a tail shows mostly noise after a failing step, and the check-run output is empty. What worked: `curl -sSL https://api.github.com/repos/PrompTugal/PrompTugal__App__iOS/actions/jobs/<job_id>/logs -o job.log` (via the proxy), then `grep -n "error:" job.log`. List jobs and steps with `.../actions/runs/<run_id>/jobs`. Time the `##[group]` blocks to see where minutes go.
- **The schedule is unreliable:** `*/10 * * * *` in ci-status.yml fired once (09:56 UTC on 16 Nov) between the merge and 15:30, so the live JSON goes stale while dev is quiet. `workflow_run` covers active periods. See the first things to do.
- **Larger runners:** `macos-26-xlarge` needs larger runners enabled on a paid plan and is billed per minute (roughly $0.16/min, so ~$4 per dev build). Dinis decides. Don't point a job at a label no runner serves: it waits forever.

## State

- **Done and on dev:** every row of the "What I own" table, plus the iPhone-only dev tests and the PrompTugal-first upload (cherry-picked as 7ba5a37 and 00700d1).
- **Waiting on Dinis:**
  - approve the app name, subtitle and description, then the conductor edits `app-info.json` and runs `set-app-info` with confirm
  - a decision on larger runners or the self-hosted Mac
- **Open:**
  - The ci-status schedule reliability (above).
  - The two zombie runs (admin force-cancel).
  - Not measured yet: the first dev upload after 7ba5a37 and 00700d1. Compare it with run 540.
- **Half-done:** nothing.

## First things the next session must do

1. Read this file, `briefs/2026-11-15__going-local/tonight.md`, the README "Building and CI" section and `.github/workflows/{ios,ci-status,website,testflight-ops}.yml`.
2. Check the live data: `curl -sS "https://raw.githubusercontent.com/PrompTugal/PrompTugal__App__iOS/ci-status/ci-status.json?t=$(date +%s)"`. Look at `generatedAt`; if it is hours old, the schedule is not firing.
3. Make the refresh dependable:
   - Move the cron off the busy minutes (for example `'7,17,27,37,47,57 * * * *'`). GitHub delays and drops `*/N` and top-of-hour schedules under load.
   - Or keep `workflow_run`, and add a `workflow_dispatch` the conductor can call.
   - Change only `ci-status.yml`; it runs on ubuntu and costs no Mac.
4. Measure the next dev upload with the collector, or `.../actions/runs/<id>/jobs`, and compare with run 540 (79m28s). The iPhone-only tests and the PrompTugal-first upload should show.
5. Do not run `set-app-info` with confirm until the conductor says Dinis approved the name.
6. Keep pushes to `night/**` and `dev` rare; use `work/**` for everything that does not need a compile.
