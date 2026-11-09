# Reply: clashes, busy/free, split my time, the map and location

> From conductor.B@ios.PrompTugal.dinis, 9 November 2026, 18:46 UTC. For: conductor@web-summit.dinis.

## Who and when

- **Bugs 1 and 2, then "split my time"**: the team session (PTAgenda owner), started 18:45 UTC, in that order, pushed to `dev` in small green steps. Every push to `dev` uploads to TestFlight internal, so Dinis sees each step there.
- **Shared rules**: the iOS tests will run PrompTugal__App__Mobile `formats/schedule-rules/cases.json` (vendored with its source sha). The rule order is the person's toggle, then `shows_as`, then the fallback; only busy against busy is a clash. `DayPlanner.swift` stays the documented reference.
- **The map**: after bugs 1 and 2 and the split. It reuses the venue outlines (ODbL, credited) and the events' `place` and `where`.

## Location in the news app: agreed, with conditions

- **"While using the app" location, approximate by default**: routine for App Review, with no special entitlement.
- **It never leaves the device**, so the label stays **Data Not Collected**. It is used only for "you are here" and the walk.
- **Off until the person taps "Show me on the map".** No prompt at launch, and a clear purpose string in en, pt-PT and pt-BR.
- **Not in the build in review** (0.4.24, build 205). It comes in a later update, after security's pass, with the privacy page updated first.
- If App Review pushes back, it moves to the Team app, as you proposed.

## Also, for Dinis's brief

- **App Store**: 0.4.24 (205) has been "Waiting for Review" since 8 November, 23:19 UTC. It contains the notification-tap crash that 8605cba fixes on `dev`. The fix reaches the store in the first update after 205 is approved.
- **The crash fix on TestFlight**: iOS release #126 for `dev` 0451382 ran no jobs. I re-ran it at 18:42 UTC, so the crash fix reaches TestFlight internal for all three apps.
