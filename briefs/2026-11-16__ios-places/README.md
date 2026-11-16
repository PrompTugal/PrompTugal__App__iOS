# ios.places: PrompTugal.news by place in the PrompTugal app

> From ios.places@PrompTugal.dinis, started 15 November 2026 at Dinis's word ("fire up a new one, the iOS developer ... super critical"; "the PrompTugal iOS app also needs to be very visual"). Brief: PrompTugal__News__Website `board/briefs/2026-11-15-show-the-power.md`, section "The iOS app". Issue WS-177.

## My part, and what stays with conductor.a.ios@

conductor.a.ios@promptugal.dinis's plan (`briefs/2026-11-15__going-local/`) does the **Team app** first: the agents command centre (`PTAgents`, connect a conductor's vault, talk to agents over lanes) and the per-city newsroom (graph, map, outreach). Its step 7 is "News app: local tab". I take that step, now, and only that:

| Mine (ios.places@) | Not mine (conductor.a.ios@) |
| --- | --- |
| The **public PrompTugal app** (`Apps/PrompTugal`): a Places tab, read-only, from the website's public by-place data | The Team app, its command centre and newsroom destinations |
| Package `Packages/PTPlaces` (depends on PTCore only) | Package `PTAgents`, vault and lane access, sealed conversations |
| A **reader** of conductor-report/v1 for the agents behind each place, built from public records | The report schema itself, the conductor writer, the vault-handed report |

When `PTAgents` lands, `AgentsReport` in PTPlaces moves there and PTPlaces depends on it; the shape is the same (`Packages/PTPlaces/Sources/PTPlaces/AgentsReport.swift`). I do not change the schema; the fields I read beyond v1 (`newsroom`, `newsroomRole`) are the ones its brief proposes, plus `done` and `next` from status.json (readers ignore unknown fields).

## What the app shows (pass 1)

- **Places** is tab 0 (iPhone) and the first sidebar row (iPad). The summit venue map moved to More; `promptugal://open/map` still opens it; `promptugal://open/places` and `/algarve` open Places.
- **The magazine** (`PlacesHomeView`): masthead; the Algarve from above (MapKit satellite imagery, tilted) with its 17 towns pinned in their own accents; Loulé and Faro as the case studies (big aerial covers, lead story, numbers); the national edition (Portugal) as a carousel; the 17 towns as a mosaic of painted covers in each town's accent; the latest local AI stories across all towns; the newsroom strip (one face per place agent, live or researching).
- **A place** (`PlaceDetailView`): aerial hero; the two-line mandate (with the labelled Algarvio voice toggle, same facts); big numbers; centre of gravity with its sources and read dates; the places under it (the Algarve shows its interactive map and town tiles); the lead story big, the rest as cards, each with the PrompTugal test drawn as steps from AI and its path; the AI map as a **connections graph** (rings by steps from AI, coloured by kind; tap for detail) plus cards with source and read date; events; **the agents behind it**; gaps ("what we do not know yet"); how the page is made (written by, updated, signed with, data URL, sources).
- **The agents behind each place** (`AgentsPanel`): a conductor-report/v1 per place, a small network (place agent at the centre, its regional agent above, the by-place team around) and a card per agent: face in its status colour, what it is doing, what it waits for, what it has done and will do next.

## Data it reads (all public, all from promptugal.news)

| URL | For |
| --- | --- |
| `/api/v1/by-place/index.json` | the places, status, agent, counts |
| `/data/by-place/places.json` | each town's seat (`at`: [lon, lat]) for the maps |
| `/data/by-place/<id>.json` | one place |
| `/board/team/<role>/status.json` | the agents' records, until the report below exists |
| `/api/v1/by-place/agents.json` | **asked**, not served yet: a conductor-report/v1 for the by-place team |

Every decoder is lenient: a field that is missing or changed shape is dropped, never the whole file. Everything is cached on disk (RemoteFeed), so it opens offline after one good load.

## Asks

1. **dev.places@** (website): serve `api/v1/by-place/agents.json` as conductor-report/v1, one agent per entry with `newsroom: <place id>` for the place agents and no `newsroom` for the shared team, `status` from each `status.json`, `doing` = `state`, `waitingFor` = first `asks`, `lastActive` = `updated`, plus `done` and `next`. The app reads it first and falls back to status files without it.
2. **dev.places@ / designer.places@**: when the licensed photo per town lands (dev.places@'s ask 8), put its URL in the place file as `look.image`; the app shows it over the satellite cover.
3. **Dinis**: my session key. `pki-agent.mjs keygen --session` was refused in this session (downloading and running the tool was blocked), so there is no `ios.places-promptugal` entry in the website's `board/keys.json` and I cannot write to the website's inboxes. I have no push access to the website either (this session is scoped to this repository). These asks reach dev.places@ through this file and my status; a person or conductor@ to relay, or allow the key tool.

## JSON gaps (sent to conductor@ for datasci.places@ and dev.places@, 15 Nov 23:20 UTC)

Rule from Dinis via conductor@ (website `board/guidance/2026-11-15-json-first-rest-api-and-swagger.md`): nothing only in HTML, the app reads `/api/v1/`. What the app needs:

1. `/api/v1/places/<id>.json` (today `/data/by-place/<id>.json`; `/api/v1/by-place/<id>.json` is 404) and the seats (`at`) in the index.
2. `/api/v1/by-place/agents.json` or `/api/v1/places/<id>/agents.json`, conductor-report/v1 (Asks 1).
3. `/api/v1/places/<id>/articles.json`: the town and region articles on each place page, HTML only today.
4. Provenance per story (maker, time, sources and read dates, capture link and hash).
5. `look.image` per town (Asks 2).

## Ship route

`night/ios-places` (CI builds only) → green → merge to `dev` (CI unit tests on iPhone and iPad, then the `testflight` job uploads PrompTugal to internal TestFlight). Never the App Store.

## Status

See `status.json` in this folder.
