# Information architecture: PrompTugal.news, local news town by town (c.ios.ux, 25 Nov 2026, revised 26 Nov)

> Revised to Dinis's word relayed by c.ios (~23:35): no Web Summit anywhere; the summit screens go. The app's identity is **all the local towns, a highly visible map, locality as the frame, news bubbling up from town to region to country, and the many data sources and data sites**. Read against `Shell/Destinations.swift` on candidate c3 (`92c0fb1`). The shell work is in `shell-spec.md`.

## The frame

Every screen answers "where?" first. A story belongs to a town; the region shows what rose from its towns; the country shows what rose from its regions. The map is how you move between them, and every number on it opens the data site it came from.

## Tabs (Dinis, 26 Nov: Home, Places, News, Now; candidate c6)

| Tab | Id | Leads with | Why |
| --- | --- | --- | --- |
| **Home** | `home` (PTPlaces `PortugalHomeView`) | **The PrompTugal.news front page**: the country's lead stories, each with its town; "Bubbling up" from towns to regions to Portugal; the map as a visible entry to every town; a Data sources strip. | The front page of a newspaper of places: the national view that the towns feed. |
| **Places** | `places` (opens on Portugal) | **The map** and the places: Portugal, then the Algarve and the district capitals, then each town. Town search, Near me and followed towns over the map. | Locality as the frame: you go down from the country to your town. |
| **News** | `news.home` | A scope switch My towns · The Algarve · Portugal; each story shows its town and its "rose from Lagos → Algarve" trail. Latest, Stories, Newsletter. No Interviews, no "from Lisbon". | The bubbling-up feed seen at three levels. |
| **Now** | `now` | Your towns, now: each followed town's "Now in" line (IPMA) and newest story; Since you last looked; events today near you. | The personal page, still framed by place. |

**Explore is off the tabs** (Dinis): its stories, organisations and library stay reachable (`explore`, `explore.stories`, `explore.library` ids, from Home and More), but it is not a tab. **No language button** in any toolbar; the app follows the iPhone's language.

The town page (`place:<id>`, c6) is the unit every tab leads to.

## Where Data sources lives

Data sources is part of the identity, so it is visible in three places, one screen behind all of them:

1. **`local.sources`** (new destination, a full screen): the 13 sites (promptugal.news, newsroom, data, weather, events, civic, bulletins, live, videos, library, cyber, signals, startups and travel), each with what it publishes, how many places it covers, its last `read_at` (amber when old, today all of data.* says "read 21 Nov"), and a link to the site. Source list in `briefs/2026-11-25__c-ios/bigger-pass.md`.
2. **Home and Places**: a "Data sources" strip opens it.
3. **Every town page**: a "Data for <town>" block (which sites have something for this town: IPMA station, events, council notices, cameras), and every provenance line opens it.

Also reachable as the first row of More (`local.sources`, on c6). Owner of the screen: PTLocal (it already reads data.* and the dashboard); the shell adds the id.

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
