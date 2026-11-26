# App Store screenshots (c.ios.ux, 25 Nov 2026)

> `Apps/PrompTugal/PrompTugalUITests/ScreensTests.swift` now shoots five destinations, all ids that exist in `Shell/Destinations.swift`. Agreed with c.ios.design (25 Nov ~23:30 UTC, their captions and per-shot rules: `briefs/2026-11-25__c-ios/design/screenshots.md` on work/c-design 9c7013b). Based on candidate c3 (Explore opens on Stories; ids `explore.stories`, `explore.library`, `explore.summit`).

## The set, in store order (26 Nov, candidate c6, Dinis's tabs)

| # | Launch id | File id | What it shows |
| --- | --- | --- | --- |
| 1 | `home` | `home` | The PrompTugal.news front page (Portugal). |
| 2 | `places` | `places` | Places, opening on Portugal, with the map. |
| 3 | `place:loule` | `place.loule` | Loulé's town page: cover and "Now in". |
| 4 | `now` | `now` | Your towns, now. |
| 5 | `news.home` | `news.home` | The news. |
| 6 | `local.newsroom` | `local.newsroom` | Who makes it, read-only. |

The file id replaces ":" and "#" with "." (`ScreensTests.fileID`): artifact uploads refuse ":" in paths. Later candidates: `place:loule#lead` (file `place.loule.lead`) and `local.maps`.

## Why run 45727939914 failed (25 Nov, c5)

Not ScreensTests: all 5 shots were taken and uploaded on both devices. The site-set job then checks the count against `screens_count`, which `scripts/release/apps.py:367` defaults to **13** for the legacy news app when `apps.json` has no `screensCount` ("5 screenshots for iPhone, expected 13"). Fix (conductor, not my file): add `"screensCount": 6` to the PrompTugal entry in `apps.json`, or change the default in `apps.py`; the comment at `screens.yml:146` says "13 for PrompTugal today" and needs the same change.

## How to run screens.yml (for the conductor)

- app `promptugal`, store `true`
- ids `home,places,place.loule,now,news.home,local.newsroom`
- ids_required the same
- seed_picks **empty** (no picks, no notification prompt)
- now **empty** (the default `2026-11-10T11:00:00Z` puts Now in its summit "during" state)
- hide_term `Web Summit` (keep the default)
- locales `en-US,pt-PT,pt-BR`

Notes:
- `-PTSampleData` is passed but nothing reads it now, so the shots use the live sites. Places and Newsroom need the network on the runner (they have it).
- The Places footer still contains the words "Independent of Web Summit" (J1-03). `hide_term` hides events and news, not that footer; it is below the fold in shot 1, but fix P0 before the store run anyway.
- Every shot needs its live / saved / built-in line in frame; the Places shot must not show the footer.
- Before uploading, check each shot for: a provenance line (live / saved / built-in), the "Simulated" badge where a simulation is in frame, no sign-in, no comment button, no summit words.
