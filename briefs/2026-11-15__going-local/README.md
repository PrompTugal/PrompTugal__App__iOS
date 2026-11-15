# Going local: a newsroom per city, and the agents command centre

> From conductor.a.ios@promptugal.dinis (started by the VoiceDebrief iOS conductor at Dinis's word, voice memo of 15 November 2026, 11:22). First plan for the pivot: PrompTugal becomes the case study for our stack (the app, sgit vaults, append lanes, agents) by running an agentic newsroom per Portuguese city. Copy to conductor.3@web-summit, which holds the PT news websites.

## 1. The minimum city newsroom

One newsroom per city (concelho). Each is a small set of agents, one sgit vault per city, and append lanes between them. Nothing talks to anything except through a vault or a lane, so every step leaves a signed, replayable trail: that trail is what we demo.

| Agent | Role | Reads | Writes | Cadence |
| --- | --- | --- | --- | --- |
| **Researcher** (`researcher.<city>`) | Maps the town: companies, people (public roles only), events, the câmara and juntas, associations, venues. Every fact carries its source URL and the date it was seen. | Public web, council agendas and atas, event listings, company sites | `graph/` in the city vault (entities, edges, sources) | Daily sweep; on demand from the editor |
| **Verifier / outreach** (`outreach.<city>`) | Turns each graph entity into a short "is this correct?" message to the entity itself, with the sources shown. Records replies: confirmed, corrected, declined, no answer. | `graph/`, replies on its inbox lane | `outreach/` (asks, replies, consent state); updates `graph/` confidence | Batches under a rate policy; never more than one ask per entity per N days |
| **Reporter** (`reporter.<city>`) | Writes short local items from what is confirmed or clearly sourced: what is on this week, what the câmara decided, who opened. Every item links out to its sources. | `graph/`, `outreach/`, council feeds | `drafts/` | Several times a day |
| **Editor** (`editor.<city>`) | Applies the policies (below), checks sources resolve, merges or bounces drafts, publishes the city page and feed, sends work back to the researcher. The one agent that can publish. | `drafts/`, policy file | `published/` (the city's page and `feed.json`), `board/` | Hourly |

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

The Algarve, starting with the town of the first showcase company (Algarve Evolution), then the towns Vicky H's agents are already researching. Each city is a copy of the same vault template plus a city id, so adding a town is a script, not a project.

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

- The "is this correct?" page each entity receives is web (the city site), not the app. The app shows the outreach queue, replies and consent state, and lets a person approve a batch before it goes.

### D. The public side (news app, later)

- A **local** tab: pick your town, read its page, every item linking to its sources. Reads `published/feed.json` the same way the news app reads `promptugal.news` feeds today.

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
6. **Outreach** pages on the city site (with conductor.3@web-summit) and the queue in the app.
7. **News app: local tab**, once a city has a week of published items.

## 5. What I need from Dinis

1. **Read access to VoiceDebrief/VoiceDebrief__App__iOS** for this session (adding it was refused here), so I port the Agents screen and the conductor's report writer rather than rewrite them.
2. **The first city.** Which town is first: the town of Algarve Evolution, or one Vicky's agents already cover?
3. **Vicky's agents.** Where her town-by-town research lands (a vault or repo), and whether her researcher becomes our `researcher.<city>` or feeds it.
4. **A conductor report vault** to test against: the read key handed to the app the way VoiceDebrief gets it (in person or by QR, never in a commit or a chat).
5. **Who sends outreach.** The sender name and reply address for "is this correct?" messages, and whether the first batch needs your approval each time.
6. **Where the city pages live:** under promptugal.news (`/local/<city>/`) or a domain per city. That decides what conductor.3@web-summit builds.
7. **The policy owner key:** whether city policies are signed by your key or by a per-city owner key we create.

## Not done

- No code changed. No Mac here, so nothing built or run.
- VoiceDebrief's code not read: the reuse table cites the paths I was given.
