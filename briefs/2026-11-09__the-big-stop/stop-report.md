# Stop report: conductor.B@ios.PrompTugal.dinis (account B, iOS)

Written 10 November 2026, 00:05 UTC, for conductor@web-summit.dinis, conductor.b@PrompTugal.dinis and Dinis.

## What was running when the order came (brief 628d2f6, pushed 23:36 UTC)

- **My hourly :00 rota wake** (scheduled task "conductor.B iOS: rota wake :00"). I read the brief at the 00:02 wake, the first after 23:36 UTC.
- **The testflight session**, which watches builds and posts status pages. It had two one-shot checks booked, for 00:04 and 00:06.
- **iOS CI:**
  - release #140 (v0.4.59, 87211d1) was building. It carries the report.sh fix and should upload the public app's 0.4.57 changes: the 21 cultures and the globe button.
  - ios.yml run 448 (687ab02) was queued.
- **App Store:** 0.4.24 (205) is waiting for Apple's review. Nothing is running on our side for it.
- The other worker sessions (team, design, i18n, apps, platform, collab, release, review, ux, editor, m-ipad) had no recurring wakes of mine. They work only when messaged, and I have sent them nothing since.

## What ran in the previous hour (23:00 to 00:00 UTC)

- **My 23:00 wake:**
  - watch line 01bd4de on News__Website;
  - a read-only ios-submit preflight.
- **TestFlight:** v0.4.56 (237) uploaded and was accepted on all three apps (internal testers only).
- **Release #138 (v0.4.57):** the public app failed after a green export. The cause was a SIGPIPE in scripts/release/report.sh; the Team app uploaded.
- **Fix:** I fixed it on iOS dev as 687ab02. That commit triggered Release and deploy #143 (green), ios.yml run 448 and release #140.
- **The testflight session:** status pages 149 to 151 (testflight-ops, read-only).

## When each thing stopped

| What | Stopped | How |
|---|---|---|
| My hourly :00 wake | 00:03 UTC | scheduled task disabled (kept, not deleted, so it can be turned back on) |
| The testflight session | after its 00:04 and 00:06 one-shot checks | told at 00:03 to report on release #140 once, book nothing more and stop |
| Merges to iOS dev, new work for workers | 00:03 UTC | none started |

Time from the brief (23:36) to my stop: about 27 minutes. The cause was my wake cadence: the first wake after the brief was 00:02.

## What could not be stopped, and why

- **Release #140 and ios.yml run 448** keep running. The brief allows builds already queued to finish uploading, and cancelling them would leave the public app without the fix for the 0.4.57 failure.
- **App Review of 0.4.24 (205)** is in Apple's queue. It is not ours to stop.
- **The "@inbox session run" scheduled task** on this account (session_01494ENweZLCHUFJvzSn6qbR, next fire at 01:49 UTC) is not mine and not an iOS worker. I left it for conductor.b@ to decide.

## How effective the stop was

- No iOS agent wakes on a schedule now, apart from the testflight session's two one-shot checks.
- The only spend left is CI on the macOS runners for one release, plus one ios.yml run already queued.
- Restart: conductor.b@ or Dinis turns the scheduled task back on (trig_01XJQTX8X1KKoXJfAtz8RqBk) or messages this session.
