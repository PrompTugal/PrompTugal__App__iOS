# Going local: a newsroom per city, and the agents command centre

> From conductor.a.ios@promptugal.dinis (started by the VoiceDebrief iOS conductor at Dinis's word, voice memo of 15 November 2026, 11:22). First plan for the pivot: PrompTugal becomes the case study for our stack (the app, sgit vaults, append lanes, agents) by running an agentic newsroom per Portuguese city. Copy to conductor.3@web-summit, which holds the PT news websites.

## Update, 15 November 23:00: the app is the reader and command centre for the regional sites

Dinis's memo of 22:57: "the focus now is the PrompTugal iOS application ... it has a website per region in the Algarve ... create a super powerful iOS application that can show it." This moves the app ahead of the newsroom build: the newsroom already exists and the app's job is to show it.

**What is live tonight** (read from promptugal.news, site v0.1.1496):

- `promptugal.news/algarve/` and 17 town sites, 4 live (Faro, Tavira, Lagos, Vila do Bispo), 13 researching; 66 local AI stories, 100 organisations on the region's map, each story with its source, date and "AI path" (direct, or 1 to 3 steps).
- One agent per place already: `place.algarve@`, `place.<town>@PrompTugal.dinis` (17) plus `place.portugal@`, `designer.places@`, `dev.places@`. All 53 agents are in `api/v1/newsroom/dashboard.json`, which the Team app's Agents dashboard already reads.
- The national graph and API: `api/v1/index.json` (companies, organisations, places, stories, evidence, the whole graph, search index).
- **Gap:** the regional and town sites have no JSON yet: only HTML and Markdown twins (`/algarve/<town>/index.md`). `api/v1/places/faro.json` is the old national place record, not the town site.

**So the first release is a reader, in the news app (PrompTugal), not the Team app:**

1. **Portugal → the Algarve → town.** A region home (the map of the 17 places, live vs researching, the latest from the towns) and a page per town (its stories, its organisations on the map, its centre of gravity). Every story opens its source first; the AI path shows under each story.
2. **The map.** MapKit with the 17 places and the organisations on the AI map; tap a place to open its town.
3. **Pick my town.** Follow one or more towns; Now and the widget show their latest.
4. **The newsroom behind it** (Team app, then a read-only view in the news app): the town's agent, its last wake and next step from `newsroom/dashboard.json`, and "is this correct?" for any fact (opens the outreach page once the web side has it).
5. **Command centre** (Team app): as in section 2A; the town agents are the first rows.

**What the app needs from the web side** (the PrompTugal.news agents: dev.places@, place.algarve@), proposed shape, one file per region and per town, built from the same content as the pages:

```
api/v1/regions/algarve.json
{ "id": "algarve", "name", "updated", "agent": "place.algarve@PrompTugal.dinis", "mandate", "voice"?,
  "places": [ { "id": "faro", "name", "status": "live"|"researching", "lat", "lon", "agent",
                "stories": 10, "mapped": 12, "picture"?: { "url", "caption", "credit" } } ],
  "latest": [ <story> ] }

api/v1/regions/algarve/<town>.json
{ "id", "name", "region": "algarve", "status", "updated", "agent", "mandate", "centreOfGravity",
  "stories": [ { "id", "title", "summary", "url" (the source), "source", "published", "aiPath": { "steps": 0..3, "text" },
                 "places": [ids], "level": "local"|"region"|"national"|"world" } ],
  "map": [ { "id", "name", "kind", "lat"?, "lon"?, "role", "sources": [url], "confidence": "sourced"|"asked"|"confirmed" } ] }
```

Until it exists the app can read the Markdown twins as a stop-gap, but that is brittle and I'd rather not ship it.

## 0. Already settled on the web side (from conductor@web-summit.dinis, 15 Nov)

- Dinis's answer on local sites (14 Nov): https://web-summit.sgit.ai/articles/promptugal-by-place.html (brief with infographics: https://web-summit.sgit.ai/people/dinis/local-sites/, answering Vicky's plan at https://web-summit.sgit.ai/people/vicky/local-sites/).
- City pages live at `promptugal.news/algarve/` and `promptugal.news/algarve/<town>/`: 17 places (the 16 Algarve municipalities and Quarteira). No subdomains or `/local/` path for now.
- Brand is always PrompTugal.news; every story passes the PrompTugal test (connects to AI within 2 or 3 steps); three levels of place (Portugal, the Algarve, the towns); each site is a lens on one semantic graph, with a mandate at the top and a centre of gravity per town.
- The web side (city pages, "is this correct?" pages, `feed.json`) belongs to the PrompTugal.news agents (dev@, ontologist@ for the graph, dev.portugal@ for the Algarve). Outreach messages are **drafted by agents and sent by a person**.
- Split: this conductor does the app and the command centre; the web side stays with the PrompTugal agents; conductor@web-summit keeps the brief.

## 1. The minimum city newsroom

One newsroom per city (concelho). Each is a small set of agents, one sgit vault per city, and append lanes between them. Nothing talks to anything except through a vault or a lane, so every step leaves a signed, replayable trail: that trail is what we demo.

| Agent | Role | Reads | Writes | Cadence |
| --- | --- | --- | --- | --- |
| **Researcher** (`researcher.<city>`) | Maps the town: companies, people (public roles only), events, the câmara and juntas, associations, venues. Every fact carries its source URL and the date it was seen. | Public web, council agendas and atas, event listings, company sites | `graph/` in the city vault (entities, edges, sources) | Daily sweep; on demand from the editor |
| **Verifier / outreach** (`outreach.<city>`) | Drafts, for each graph entity, a short "is this correct?" message to the entity itself, with the sources shown; a person sends it. Records replies: confirmed, corrected, declined, no answer. | `graph/`, replies on its inbox lane | `outreach/` (drafted asks, replies, consent state); updates `graph/` confidence | Batches for a person to send, under a rate policy; never more than one ask per entity per N days |
| **Reporter** (`reporter.<city>`) | Writes short local items from what is confirmed or clearly sourced: what is on this week, what the câmara decided, who opened. Every item passes the PrompTugal test and links out to its sources. | `graph/`, `outreach/`, council feeds | `drafts/` | Several times a day |
| **Editor** (`editor.<city>`) | Applies the policies (below), checks sources resolve, merges or bounces drafts, hands the city page and feed to the PrompTugal.news build, sends work back to the researcher. The one agent that can publish. | `drafts/`, policy file | `published/` (the city's page and `feed.json`), `board/` | Hourly |

That is four. Shared across cities, not per city: a **regional desk** (one per region, Algarve first) that dedups across towns and spots stories bigger than one town, and the **conductor** that starts, watches and stops the agents. Humans sit at two points only: the city's owner of record (who reads the editor's board) and anyone answering an outreach ask.

### Flow

```
web, council, events ──► Researcher ──► graph/ ──► Verifier ──► "is this correct?" ──► entity
                                         ▲    ▲                         │
                                         │    └──── replies (lane) ◄────┘
                                         │
                        Reporter ◄───────┘──► drafts/ ──► Editor ──► published/ (city page, feed)
                                                            │
                                                            └──► board/ (asks for a human, back to researcher)
```

### Behaviour policies (ABP), shown in action

Each agent runs under a policy file in the city vault (`policy/<agent>.json`), signed by the city's owner key. The app shows which rule allowed or blocked each step. Starting set:

1. **Always cite.** No fact enters `graph/` or `drafts/` without a source URL and a seen-at date; the editor bounces anything that fails.
2. **Ask before you assert.** Facts about a private company or a named person are "unconfirmed" until the entity confirms, and are written that way.
3. **Send traffic out.** Every published item links to its sources first; we summarise, we do not replace.
4. **Public people only.** People appear only in a public role (council member, company founder on their own site, speaker at a public event). No personal data beyond that.
5. **Rate and consent.** One outreach ask per entity per 30 days; "stop" on any reply removes the entity's contact for good.
6. **Only the editor publishes.** Researcher and reporter keys cannot write `published/`; this is enforced by the vault's write keys, not by prompt.
7. **Human on the hook.** Anything legal, about a minor, or contested goes to `board/` and waits for a person.

### First cities

The Algarve, starting with the town of the first showcase company (Algarve Evolution), then the towns Vicky H's agents are already researching. The 17 places are fixed (the 16 municipalities and Quarteira); each is a copy of the same vault template plus a town id, so adding a town is a script, not a project.

## 2. What the PrompTugal app needs

The work goes in the **Team app** first (internal, where we experiment), then the parts that are public go to the news app. No new app for now.

### A. The agents command centre

What you see depends on which conductor you connect to.

- **Connect a conductor.** You hand the app a vault (read key) that a conductor writes its encrypted report into, plus a lane to that conductor. Connecting Dinis's conductor shows every session across his accounts (50 to 120 at a time); Vicky connecting hers sees only hers. The scope is the conductor's, not the app's: the app never sees a session the conductor did not put in its report.
- **List:** every session, grouped by conductor, city or project; status (working, blocked, waiting on you, done, failed), last action, what it asks for.
- **Talk to one:** a conversation per agent over a sealed lane (sgit hybrid envelope), so a person can steer an agent from the phone.
- **Newsroom view:** per city, the four agents, today's wakes, items through each stage, and which policy fired.

### B. The city graph and map

- The city's `graph/` drawn two ways: on a map (MapKit, entities with an address) and as a graph (entities and edges).
- Each entity shows its sources, its confidence (sourced, asked, confirmed, corrected) and its outreach history.
- The editor's board as a list: what needs a human.

### C. Outreach

- The "is this correct?" page each entity receives is web (built by the PrompTugal.news agents), not the app. The app shows the drafted queue, replies and consent state, and is where a person reviews and sends each batch (agents draft, a person sends).

### D. The public side (news app, later)

- A **local** tab: Portugal, the Algarve, then the town; read its page, every item linking to its sources. Reads `published/feed.json` the same way the news app reads `promptugal.news` feeds today.

## 3. What we reuse

| Need | From | Where |
| --- | --- | --- |
| Agents screen reading a conductor's encrypted report from a handed-over vault; per-agent sealed conversation | VoiceDebrief iOS | `Apps/VoiceDebrief/Sources/UI/AgentsView.swift`, `Engine/AgentsDesk.swift`, `tools/conductor/` (the conductor-side writer) |
| Vault read/write, commits, trust, object cache | This repo | `Packages/SGitVault` |
| Opening vaults by passkey, recovery code or imported key; collab access | This repo | `Packages/PTVaultUI` (`VaultSession`, `VaultCollabAccess`) |
| Append lanes, sgit hybrid envelope (RSA-OAEP + AES-GCM), lane addresses, sealed messages | This repo | `Packages/PTLanes` (`LaneClient`, `LaneCrypto`, `LaneAddress`, `Messages/`) |
| Agents and newsroom dashboards (wakes, desks, story board, "waiting on a person") | This repo, Team app | `Apps/Team/Sources/Dashboards/AgentsDashboardView.swift`, `NewsroomStatusView.swift`, `WireModels.swift` |
| Per-person command centre | This repo, Team app | `Dashboards/CommandCentreView.swift`, `Team/MyCommandCentreView.swift` |
| Venue map (MapKit + GeoJSON) | This repo, Team app | `Apps/Team/Sources/Map/VenueMap.swift` |
| Graph/explore screens | This repo | `Packages/PTExplore` |
| On-device model for local checks (Foundation Models) | RiskMandate app | `Apps/RiskMandate/Sources/Workbench/OnDeviceModel.swift` |

The plan for the code: lift VoiceDebrief's report reader and agent conversation into a new package here, `PTAgents` (depends on `PTCore`, `SGitVault`, `PTVaultUI`, `PTLanes`), with the report format written down as a shared schema both apps and both conductors use. The Team app gets a "Command centre" destination built on it, then a "Newsroom" destination per city that adds the graph and map. Neither needs a new server: vaults and lanes on `dev.send.sgraph.ai` are the whole back end.

## 4. Order of work

1. **Report schema** (`conductor-report/v1`): sessions, status, asks, lane address per agent. Agree it with the VoiceDebrief conductor so both apps read the same file.
2. **`PTAgents` package** in this repo: report reader + sealed conversation, ported from VoiceDebrief, with tests.
3. **Team app: Command centre** (connect a conductor, list, talk to one). Green in `ios.yml`, to TestFlight.
4. **City vault template** (`graph/`, `outreach/`, `drafts/`, `published/`, `board/`, `policy/`) and one real city with the researcher running.
5. **Team app: Newsroom per city** (graph, map, board, policy trail).
6. **Outreach** queue in the app; the pages are the PrompTugal.news agents' work.
7. **News app: local tab**, once a city has a week of published items.

## 5. What I need from Dinis

0. **Go-ahead for the reader in the news app** (above) as the first release, with the regional JSON asked of the PrompTugal.news agents; the city-newsroom build (sections 1 and 4) follows.

1. **Read access to VoiceDebrief/VoiceDebrief__App__iOS** for this session (adding it was refused here), so I port the Agents screen and the conductor's report writer rather than rewrite them.
2. **The first city.** Which town is first: the town of Algarve Evolution, or one Vicky's agents already cover?
3. **Vicky's agents.** Where her town-by-town research lands (a vault or repo), and whether her researcher becomes our `researcher.<city>` or feeds it.
4. **A conductor report vault** to test against: the read key handed to the app the way VoiceDebrief gets it (in person or by QR, never in a commit or a chat).
5. **Who sends outreach.** Agents draft and a person sends (settled); which person, and the reply address.
6. **The policy owner key:** whether city policies are signed by your key or by a per-city owner key we create.

## Not done

- No code changed. No Mac here, so nothing built or run.
- VoiceDebrief's code not read: the reuse table cites the paths I was given.
