# c.ios workers (started 25 Nov 2026 ~23:19 UTC at Dinis's word)

| Worker | Session | Branch | Owns | First tasks |
| --- | --- | --- | --- | --- |
| c.ios.places | session_01Kw9UwCrJrnZs1pD4S7PwjA | work/c-places | Packages/PTPlaces | "Since you last looked" (since.json); all 17 district capitals; town news from by-place/{id}.json |
| c.ios.local | session_01Kw9UwBhp7h2EvdjAt3RfRY | work/c-local | Packages/PTLocal | freshness from each feed's read time; newsroom/status.json on the live board; events and council notices per town |
| c.ios.explore | session_01Kw9UwDrQbPcL3ZSsTZ3UCu | work/c-explore | Packages/PTExplore, Shell/ExploreView.swift | Explore rebuilt on the newsroom (stories, companies, places, library, videos); summit index behind one row |

| c.ios.design | session_01Kw9UwDpwnrHpHqKYuhPdX6 | work/c-design | briefs design/, PTCore tokens (after telling c.ios) | visual audit, design direction, store screenshot set |
| c.ios.ux | session_01Kw9UwCvcpiPb73mVR3pdwc | work/c-ux | briefs ux/, PrompTugalUITests/ScreensTests.swift | IA, core journeys, store screenshot destinations |
| c.ios.synthetic | session_01Kw9UwCTwTFh2iXFrsWwwam | work/c-synthetic | briefs synthetic/ (read-only) | 8 synthetic users, walk-throughs, App Review risk list |

Flow: workers push to work/<name> (no CI) and send "ready at <sha>"; c.ios merges ready work into a candidate branch (work/candidate-cN, never force-pushed), runs one quick ios.yml, and pushes green candidates to dev (dev push = TestFlight). Shell wiring and apps.json stay with c.ios. This batch ships in the version after the one going to App Review now.
