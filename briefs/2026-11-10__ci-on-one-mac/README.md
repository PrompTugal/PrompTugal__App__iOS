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

ios.yml keeps its Ubuntu jobs (`changes`, `check-apps`, `result`) and does all the Mac work of a run in **one job**, `macOS: build, test and publish` (`.github/scripts/mac-job.sh`). It runs in this order:

1. **Build everything, with no simulator running.** For each affected app:
   - `build-for-testing`, for the generic iOS Simulator destination;
   - the unsigned Release build for a device, then `check-embedded.sh`. An app that uploads skips this build, because its signed archive builds it.

   Then build each affected package's tests, in one shared DerivedData.
2. **Boot the iPhone simulator.** Run every app's tests and every package's tests there with `test-without-building`. Shut it down.
3. **Boot the iPad simulator.** Run every app's tests there.
4. **On a green dev push, publish.**
   - Find the push's release commit: website.yml's VERSION bump and `v*` tag. The diff to that commit must be VERSION only.
   - Then, for each affected app with `"testflight": true` that isn't paused: version, signing, signed archive, the extension, entitlement, bundle-id and size-budget checks, export, upload, cleanup.
   - This runs only when every step above passed.
5. **TestFlight processing on Ubuntu.** Wait for App Store Connect, answer export compliance and set What to Test.

The tests and their flags are the same as before.

- **One failing app doesn't stop the others.** Every app and package is built and tested, and the job lists every failure.
- **Night/** pushes** still get a Debug build only.
- **SGitVault** still runs `swift test` on the Mac itself.

**What the first runs taught:**

- **Don't run a simulator while compiling.** Run 42754257697 booted the iPhone and iPad simulators during the builds. On the 3-core runner that roughly tripled build time: Team's build took 12 min against 2.4 in the old jobs, and actool went through the busy simulator service.
- **Build for the generic simulator destination, not a device id.** In run 42754836431 an `id=` destination found no device while the simulators booted, and two apps failed to build. Nothing was uploaded. The generic destination needs no device, and it compiles every simulator architecture, as the old Debug build did.
- **One shared DerivedData makes packages cheap.** Each package now takes 1 to 2 min, against 6 to 8 min as a separate job.

**Versions and build numbers.**

- The app version is still the `v0.4.n` tag from website.yml.
- The build number is ios.yml's run number plus the app's offset: 551 and 552 so far, above ios-release's 241.
- A run whose release commit was taken by a later push builds and tests only, and the later run uploads.
- On a dev push, each uploading app is compared with the commit it was last released from. A run that waited and was replaced by a newer push therefore never drops an app's changes.

**Unchanged:**

- **ios-release.yml** no longer runs after website.yml. It keeps tags and manual runs.
- **ios-submit.yml** (App Store review) stays manual.
- **Uploads are not marked internal-only.** The internal group gets every build without review, and ios-submit.yml can still submit any of them.
- **The pause switches** (`TESTFLIGHT_ON_PUSH`, `TESTFLIGHT_ON_PUSH_<APP>`) work as before.
- **The build-info, size baseline and site panel** read ios.yml's `build-info-apps` artifact, falling back to ios-release's (`scripts/release/find-build-info.sh`).

**Gone from dev pushes:**

- **Some artifacts:** the unsigned .ipa, the Release simulator .app and the .xcarchive. A manual ios-release.yml run still makes them. The signed .ipa files are kept, as the `appstore-ipas` artifact.

## 3. Before and after

Both "after" columns are pushes that touched ios.yml, so every app and package was built, tested and uploaded. That is the most a push can cost.

| | Before (8 to 10 Nov, 34 dev pushes with app changes) | After: e5ca04a (run 42766633035) | After: 46f9577 (run 42762388408) |
| --- | --- | --- | --- |
| macOS jobs per dev push | median 10, max 30 | **1** | **1** |
| Mac minutes per push (jobs that got a runner) | median 56.8, max 200 | 39.7 | 42.5 |
| Build, iPhone tests, iPad tests | 4 to 6 Macs per app, 1 per package | 11.3 + 10.3 + 5.9 min | 10.2 + 13.6 + 5.9 min |
| Sign and upload 3 apps | 3 Macs (plus 3 for unsigned archives) | 11.8 min | 12.5 min |
| From the Mac job starting to the last upload | | **39.5 min** | 42.3 min |
| From the Mac job starting to processed in TestFlight | | **43.6 min** | 45.3 min |
| Push to the last upload | median 47.5 min, p90 87 | 80.8 min (41 queued behind 46f9577's job) | 81.8 min (39 queued behind 5212189's job) |
| Mac held while App Store Connect processes | median 2.4, max 18.8 min | 0 (Ubuntu, 3.7 min) | 0 (Ubuntu, 2.7 min) |
| Upload waits for the tests | no | yes | yes |
| Uploaded | | 0.4.68 (552), all 3 apps | 0.4.67 (551), all 3 apps |

**How to read it:**

- **For a push that runs alone:** about 40 min from push to TestFlight in the worst case, against a median of 47.5 min before. Before, that median covered pushes that usually touched fewer apps. A push that touches one app now builds, tests and uploads only that app, plus the packages it changed.
- **Mac use:** one Mac per push, not ten. The 5-runner pool is no longer the bottleneck for iOS: a push queues once.
- **The trade-off:** pushes to dev now take turns on their one Mac, since each branch has one running and one waiting job. When pushes land faster than about every 40 min, the next push waits for the current job. A newer push replaces the waiting one, and since the planner counts changes since each app's last release, the newer run covers both. Both "after" runs above waited that way behind my own previous commit.

## 4. Next, if the Mac is still the bottleneck

- **Manual ios.yml runs on split/** branches** used half of all Mac minutes. Each is now one Mac job, but a branch run with `quick` (Debug and iPhone only) is cheaper still and is enough before a merge.
- **Compilation caching** (Xcode 26, `COMPILATION_CACHE_ENABLE_CACHING`) with a restored cache could cut the 10-min cold build on later pushes. A fresh checkout's file times defeat plain DerivedData reuse. There are no remote Swift packages to cache.
- **About 5 min per simulator goes to the first test launch** (Team on a fresh device), whatever else runs.
