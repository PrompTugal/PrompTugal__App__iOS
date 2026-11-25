# Information architecture: PrompTugal.news, local news town by town (c.ios.ux, 25 Nov 2026, revised ~23:45)

> Revised to Dinis's word relayed by c.ios (~23:35): no Web Summit anywhere; the summit screens go. The app's identity is **all the local towns, a highly visible map, locality as the frame, news bubbling up from town to region to country, and the many data sources and data sites**. Read against `Shell/Destinations.swift` on candidate c3 (`92c0fb1`). The shell work is in `shell-spec.md`.

## The frame

Every screen answers "where?" first. A story belongs to a town; the region shows what rose from its towns; the country shows what rose from its regions. The map is how you move between them, and every number on it opens the data site it came from.

## Tabs (four, plus the More button)

| Tab | Id | Leads with | Why |
| --- | --- | --- | --- |
| **Places** | `places` | **The map**, full width at the top: Portugal with the Algarve and the district capitals, each town coloured by how much news it has (the styled map, `AlgarveMapsView`, now in the hero, not further down). Over it: "Find your town" search, Near me, and the reader's followed towns as chips. Below: **Bubbling up** (the strongest town stories that rose to the region, then the country, each with its town label), the towns mosaic, the district capitals, and a **Data sources** strip (the sites feeding these pages, each with its last read date). | The map is the identity and the way in. Locality first, every story placed. |
| **News** | `news.home` | **A scope switch: My towns · The Algarve · Portugal.** Each story shows its town and a small "rose from Lagos → Algarve" trail when it bubbled up. Segments below the switch: Latest, Stories, Newsletter. No "Interviews" (summit replays), no "Independent coverage from Lisbon". | The bubbling-up idea made visible: the same feed seen at three levels. |
| **Now** | `now` | **Your towns, now**: each followed town with its "Now in" line (weather, warnings, sea, fire risk from IPMA) and its newest story; then "Since you last looked" (`since.json`); then events today near you. No greeting by Lisbon time, no summit phases. | The personal front page, still framed by place. |
| **Explore** | `explore` (opens on Stories, c3) | Stories, organisations (the newsroom's 115 companies), events, library, and **Sources**: the data sites. No summit segment (`explore.summit` goes, see shell-spec). | One searchable index of everything placed on the map. |

Tab symbols: Places `map.fill`, News `newspaper`, Now `location.circle` (was a radio wave; it is about where you are), Explore `magnifyingglass`.

## Where Data sources lives

Data sources is part of the identity, so it is visible in three places, one screen behind all of them:

1. **`local.sources`** (new destination, a full screen): the 13 sites (promptugal.news, newsroom, data, weather, events, civic, bulletins, live, videos, library, cyber, signals, startups and travel), each with what it publishes, how many places it covers, its last `read_at` (amber when old, today all of data.* says "read 21 Nov"), and a link to the site. Source list in `briefs/2026-11-25__c-ios/bigger-pass.md`.
2. **Places home**: the "Data sources" strip near the bottom opens it.
3. **Every town page**: a "Data for <town>" block (which sites have something for this town: IPMA station, events, council notices, cameras), and every provenance line opens it.

Also reachable as Explore's **Sources** segment and as the first row of More. Owner of the screen: PTLocal (it already reads data.* and the dashboard); the shell adds the id.

## Town page (the unit of the app)

Hero with a small map of the town in its region (locality) and Follow → provenance line → Now in → latest news → events → council notices (civic) → local media → **Data for <town>** → organisations doing AI here → agents → how this page is made. At the bottom, "Up to the Algarve" and "Up to Portugal" links: the bubbling-up path in reverse.

## More

| Row | Id | Note |
| --- | --- | --- |
| Data sources | `local.sources` (new) | First row. |
| Newsroom | `local.newsroom` | Read-only. Its GapNote loses "comes next". |
| Algarve maps | `local.maps` (new) | The map styles full screen (Map, 3D flight, Grid, Cartogram). |
| How we source | `local.how` (new, optional) | Live / saved / built-in, Simulated, the seal, "read on". |
| On this device | `local.ask` (renamed from "Ask and summarise") | Apple Intelligence status and persona; the summary itself lives on town pages, Near me on Places. |
| Appearance, Show the welcome again, About links, independence note | `settings` | The welcome is the new one (towns and sources). The independence line names no third party. |
| About this build: version, CI status | `local.ci-status` | Kept, at the bottom, read-only. |

**Gone from More:** My program, Venue map, Reminders, the calendar toggle, "At the summit / Meet RiskMandate", Reading credit (hidden until a purchase exists; id stays routable for testers).

## What goes, in one list

Summit: `team.schedule` (My program), `map` (Venue map), `settings.reminders`, `PickCalendarToggle`, `StandSection`, the summit `OnboardingView`, Now's summit phases (`countdown`, `forYou`, `whereToBe`, `InterviewsStrip`, `onNow`, `upNext`, `tomorrow`, `PracticalCard`, `StartProgramCard`), `explore.summit` and the Talks segment, News "Interviews", the graph card "Explore the summit graph". Old ids redirect to `places` so links never fail. Details in `shell-spec.md`.
