# App Store screenshots: PrompTugal.news (c.ios.design, 25 Nov 2026)

> Proposal for c.ios.ux, who owns the screenshot test list. Sizes: iPhone 6.9" (1320 x 2868), 6.5" (1284 x 2778), iPad 13" (2064 x 2752). Light appearance, en-US first; pt-PT if the run allows. Captions are the line above the device, sentence case, at most about 40 characters so they hold on 6.5".

## The set, in order

| # | Screen | Destination | Caption | Why here |
| --- | --- | --- | --- | --- |
| 1 | Places home: masthead, Algarve map hero with town pins | `places` | **Local news for Portugal, town by town** | Says what the app is in one look |
| 2 | A town page: Faro cover, "Now in Faro", latest stories | *needs* `place:faro` | **Every town has its own front page** | The place identity |
| 3 | A story with its source line open | *needs* `place:faro` scrolled, or News story | **Every story opens its source** | The promise in the subtitle |
| 4 | "Now in" card: weather station, forecast, IPMA warnings, fire risk, sea | *needs* `place:faro#now` | **Weather, warnings and the sea, from IPMA** | Daily reason to open it |
| 5 | The Algarve maps | *needs* `local.maps` | **The Algarve's 17 towns on one map** | Visual, works on iPad |
| 6 | News | `news.home` | **The latest, with the date each fact was read** | Shows provenance stamp |
| 7 | Newsroom | `local.newsroom` | **See the newsroom of agents behind each story** | Honest about AI; "Simulated" badge visible if a replay is on screen |
| 8 (iPad only, optional) | Explore: companies and places | `explore` | **Companies, stories and places** | Fills the iPad set |

Six on iPhone is the minimum we want; 1 to 7 is the target. iPad 13": 1, 2, 5, 7, 6, 8 (maps and the town cover use the width).

## Rules for every shot

- A provenance stamp is on screen and readable (live, saved copy or built-in, with its date). Built-in is fine and honest; shoot with `-PTSampleData` only if the stamp then says **Built-in**.
- No "Web Summit" text (audit items 1, 2 must land first, or the Places footer must be off screen). Keep `PT_HIDE_TERM` for event names that are trademarks.
- No sign-in, comments, "Connect to the newsroom", top-ups or CI status visible.
- No summit screens: no Talks, My program, Venue map, countdown (`PT_NOW` empty or after 12 Nov).
- If a simulated block is in frame, its "Simulated" badge is in frame too.
- Debug off (Release defaults), so no Native/Web badges in the toolbar.

## What the test needs (for c.ios.ux and the owners)

`-PTDestination` opens only shell destinations. Shots 2, 3, 4 and 5 need either:

- a routable destination `place:<id>` (PTPlaces, `PlaceDetailView(id:)`) and `local.maps` (PTLocal, `AlgarveMapsView`) in `Apps/PrompTugal/Shell/Destinations.swift` `routable`, or
- the UI test tapping into them from `places` (slower and more fragile).

The first is a small shell change (c.ios) and I recommend it. `screens.yml`'s current list (explore.talk, team.schedule, map) must be replaced in the same change; see `app-store-submission.md`.

## Captions only (for pasting)

1. Local news for Portugal, town by town
2. Every town has its own front page
3. Every story opens its source
4. Weather, warnings and the sea, from IPMA
5. The Algarve's 17 towns on one map
6. The latest, with the date each fact was read
7. See the newsroom of agents behind each story
8. Companies, stories and places
