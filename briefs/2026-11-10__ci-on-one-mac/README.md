# CI on one Mac: fewer macOS jobs per push, TestFlight straight from dev

> From devops.ios@web-summit.dinis (account A), started by conductor@web-summit.dinis at Dinis's word (10 November 2026, about 02:40 UTC). For the iOS conductor (conductor.B@ios.PrompTugal.dinis) and prompter@web-summit.indi. Brief: brief:2026-11-10T0240Z-restart.

**Dinis:** *"the CI pipeline that we have is good, but it's very inefficient, because it has lots of steps, and the steps all need a separate Mac ... the allocation of the Mac is where the bottlenecks are. So we need to reduce the number of steps, and we need to publish directly from dev."*

## 1. Measured: the last 2 days (8 Nov 00:00 to 10 Nov 04:00 UTC)

From 579 workflow runs and their jobs (`gh api`, with `measure.py` in this folder; re-run it for the after numbers). A job counts as run only when it got a runner: jobs cancelled while they waited also carry start and end times.

**The Mac pool is 5 GitHub-hosted macOS jobs at once.** For 1,177 of the 1,524 minutes when any Mac job ran, exactly 5 ran. More than 5 ran only when the self-hosted Mac took jobs too. Every job above 5 waits.

**Queue time is about three times run time.**

| | Jobs that got a Mac | Run time (Mac minutes) | Queue time (minutes) |
| --- | ---: | ---: | ---: |
| All macOS jobs | 1,244 | 6,980 | 22,427 |
| Median per job (macos-26) | | about 5 | 12.2 (p90 44.9, max 121.5) |

**Where the Macs went:**

| Source | Jobs run | Mac-min | Queue-min | Cancelled while queued |
| --- | ---: | ---: | ---: | ---: |
| ios.yml, manual runs on split/** branches | 711 | 3,601 (52%) | 12,139 | 821 |
| ios.yml, pushes to dev | 321 | 1,903 | 6,954 | 182 |
| ios-release.yml after a dev push | 112 | 740 | 895 | 0 |
| Screens, ios-release by hand, night/** pushes | 100 | 736 | 748 | 6 |

**Per dev push.** 82 pushes to dev. 34 of them changed app code and took a Mac: a median of **10 macOS jobs** each (mean 10.7, max 30). The jobs were:

- **ios.yml:** for each affected app, a Debug simulator build, a Release device build, iPhone tests and iPad tests (4 Macs per app), plus **one Mac per affected Swift package** (up to 12).
- **ios-release.yml:** for each affected app, an unsigned archive, then a TestFlight job (2 Macs per app).

**Push to TestFlight:** median **47.5 min** to the last upload (p90 87, n = 9 pushes with an upload), and 54.5 min until the TestFlight jobs finished.

**Where the waiting comes from:**

1. **Every step is its own Mac.** One app change costs 4 to 6 Macs, and a change to PTCore costs 12 app jobs plus 12 package jobs. Each of those queues on its own for the same 5 slots. The Debug and Release builds ran for a median 2.4 to 2.7 minutes after waiting 7.3 to 7.5.
2. **Every job starts cold.** Each one does a full-history checkout, selects Xcode, boots a simulator and compiles from an empty DerivedData. The iPhone and iPad test jobs each build the same app again, and each package job rebuilds PTCore.
3. **Three stages in sequence.** website.yml (release commit and tag), then ios-release's package job, then the TestFlight job. Each stage queues again: 9 to 39 minutes for the package and 4 to 22 for TestFlight after a busy push.
4. **The upload does not wait for the tests.** ios-release follows website.yml, not ios.yml, so a red ios.yml push still uploads.
5. **A Mac sits idle while App Store Connect processes the build.** The TestFlight job polls processing for up to 20 minutes (median 2.4, max 18.8) on the Mac.
6. **Branch runs crowd out dev.** Manual ios.yml runs on split/** branches used half of all Mac minutes, and 821 of their jobs were cancelled before they got a Mac.

## 2. The change: one macOS job per push

ios.yml keeps its Ubuntu jobs (`changes`, `check-apps`, `result`) and puts all the Mac work of a run into **one job**, `macOS: build, test and publish`:

1. Select Xcode once and boot one iPhone and one iPad simulator.
2. For each affected app, in one DerivedData:
   - `build-for-testing` once;
   - `test-without-building` on the iPhone, then on the iPad (the same tests as before, on both devices);
   - the Release device build (unsigned) with `check-embedded.sh`. When the app uploads, the signed Release archive replaces it.
3. Run each affected package's tests, with one shared DerivedData, so PTCore is compiled once.
4. **On a green dev push**, archive, sign and upload each affected app to TestFlight (internal testers). This runs only after every test in the job has passed.
5. Wait for App Store Connect processing, answer export compliance and set What to Test in a separate **Ubuntu** job, so no Mac waits on Apple.

**Versions.** The app version is still the `v0.4.n` tag that website.yml puts on the push's release commit. The Mac job builds that commit, and looks the tag up after the tests. If a later push took the release commit, this run builds and tests but leaves the upload to that later run.

**Build numbers.** The build number is ios.yml's run number plus the offset. ios.yml's numbers (449 and up) are above ios-release's (141), so build numbers keep rising.

**Nothing an app needs is lost.** On a dev push, each app's diff is taken against the commit it was last uploaded from, as ios-release did. A run that was replaced in the queue therefore never drops an app's changes.

**Other workflows:**

- ios-release.yml no longer runs after website.yml, so there is no double upload. It keeps tags and manual runs.
- **ios-submit.yml (App Store review) stays manual.** There is no step on main.
- Linters, apps.json checks and the site build already run on Ubuntu, and stay there.

Status, before and after: see section 3, filled in as each commit proves itself on a run.

## 3. Before and after

| | Before (8 to 10 Nov) | After |
| --- | --- | --- |
| macOS jobs per dev push that changes app code | median 10, max 30 | _pending: first run_ |
| Push to TestFlight upload | median 47.5 min, p90 87 | _pending_ |
| Mac held while App Store Connect processes | median 2.4 min, max 18.8 | 0 (Ubuntu) |
| Upload waits for tests | no | yes |
