# App Store screenshots (c.ios.ux, 25 Nov 2026)

> `Apps/PrompTugal/PrompTugalUITests/ScreensTests.swift` now shoots five destinations, all ids that exist in `Shell/Destinations.swift`. Agreed with c.ios.design (25 Nov ~23:30 UTC, their captions and per-shot rules: `briefs/2026-11-25__c-ios/design/screenshots.md` on work/c-design 9c7013b). Based on candidate c3 (Explore opens on Stories; ids `explore.stories`, `explore.library`, `explore.summit`).

## The set, in store order

| # | Id | What it shows | Why it sells "local news, every fact sourced" |
| --- | --- | --- | --- |
| 1 | `places` | Places home: masthead, the Algarve hero with its towns, the case studies | The product in one frame: Portugal by place. |
| 2 | `now` | Your towns and the latest news | Personal front page. Needs `now` empty, or Now shows the summit. |
| 3 | `news.home` | The newsroom's latest stories | National coverage next to the towns. |
| 4 | `local.newsroom` | The agents, read-only, with the "Simulated" badge on the verify step | Ends with who makes it, in the open. If a replay is in frame, its badge must be too. |
| 5 | `explore.stories` | Explore on Stories (c3) | Optional: check the shot before keeping it. |

Removed: `team.schedule`, `explore.talk`, `explore.people`, `explore.graph`, `map` (summit screens).

## Wanted, blocked on a destination id

- **A town page** with "Now in" and the lead story's "Read at the source" (Loulé is the deepest). The strongest proof of "every fact sourced".
- **The Algarve styled map** (towns coloured by how much news they have).

Neither has an id; `-PTDestination` can only open a tab or a More screen. Spec S5 in specs.md asks for routable `place:<id>`, `place:<id>#now`, `place:<id>#lead` and `local.maps`. When they exist, the order becomes (design): places, town, story source, maps, now, news, newsroom.

## How to run screens.yml (for the conductor)

- app `promptugal`, store `true`
- ids `places,now,news.home,local.newsroom,explore.stories`
- ids_required `places,now,news.home,local.newsroom`
- seed_picks **empty** (no picks, no notification prompt)
- now **empty** (the default `2026-11-10T11:00:00Z` puts Now in its summit "during" state)
- hide_term `Web Summit` (keep the default)
- locales `en-US,pt-PT,pt-BR`

Notes:
- `-PTSampleData` is passed but nothing reads it now, so the shots use the live sites. Places and Newsroom need the network on the runner (they have it).
- The Places footer still contains the words "Independent of Web Summit" (J1-03). `hide_term` hides events and news, not that footer; it is below the fold in shot 1, but fix P0 before the store run anyway.
- Every shot needs its live / saved / built-in line in frame; the Places shot must not show the footer.
- Before uploading, check each shot for: a provenance line (live / saved / built-in), the "Simulated" badge in shot 4, no sign-in, no comment button, no summit words.
