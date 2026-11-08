# web-summit.sgit.ai: agent visualisations, ABP data, near misses (for the RiskMandate iPad/iPhone app)

> The team site's agent visualisations (Angelo's live graph and ABP prototype, Vicky's Live AI Office, the X-ray), the ABP data shape, documented near misses, and what data the site would need to publish.

Read 8 Nov 2026 from `SGit-AI/sgit-ai__website__web-summit` at `0494ad9` (site v0.2.1193), clone at
`/home/user/sgit-ai/sgit-ai__website__web-summit` (paths below are relative to it), plus live curl of https://web-summit.sgit.ai/.
Generated HTML is gitignored; sources are in `content/`, `data/`, `people/`, `board/`, `admin/build/`.

**Two corrections to the brief we were given:**
- The "Live AI Office (v0.2.1190)" is **Vicky's**, built by dev@PrompTugal.vicky (`people/vicky/office/`). It is not Angelo's.
- Angelo's "little pop-up environment that shows the agents in action" is **the live graph** (`people/angelo/app/live.js`, by dev.map@PrompTugal.angelo, 7 Nov). Its "⧉ Pop out" button opens an always-on-top Document Picture-in-Picture window. Its spin-off is the **"ABPs you can watch"** experiment (`people/angelo/proposals/abp-live/`, 8 Nov), the closest existing thing to the "with / without ABP" view.

---

## 1. Agent visualisations

### 1a. "ABPs you can watch" (Angelo, abp-live): the best fit for the app
- **Files:** `people/angelo/proposals/abp-live/README.md` (brief, Angelo's words 7 Nov 23:20), `results.md`, `spec-abp-live.md`, `runs-picture.png` (2800×2800 still), `prototype/viewer.htm` (7 KB), `prototype/runs.json` (22 KB), `prototype/world.mjs` (the mock world and its gateway, `--level 0|1|2|3`, `--scenario a|b`), `collect.mjs`, `w.mjs`.
- **Live (raw, unlinked; the status says it is "an experiment; nothing public"):** https://web-summit.sgit.ai/people/angelo/proposals/abp-live/prototype/viewer.htm and `.../runs.json` (both return 200).
- **What it shows:** one real Claude sub-agent does an ordinary support job for a fake bike-sharing company. It runs 6 times: rounds 1 and 2 of traps, each at ABP level 0 (nothing in the way), level 1 (a rule in the prompt) and level 3 (technical barriers in a gateway: cards come back as handles, secrets are masked, outbound data is scanned for canaries, the paste site is blocked, refunds over 100 are refused). The traps are phishing mail, hidden instructions on a vendor page, a live key and password in a runbook, a vendor asking for a log on a paste site, and a customer asking for his full card number.
- **How a run is drawn:** a hexagon. The agent is in the middle; company systems (inbox, CRM, documents, refunds, customers) sit inside; the outside (vendor page, paste site, stranger) sits beyond the rim. Each record line becomes a dot travelling along a line, red if it carries a canary label. A barrier is a red bar across the line at 82% of its length. A red ring around the agent grows with "N secrets in its context". Score chips per run: secrets that left, secrets the agent saw, refused, replies/refunds.
- **Results (results.md):** no secret left at any level, so the brief's own test "at level 0 at least one leak" was **not met**. Secrets that reached the agent's context and transcript: L0 5 / 4, L1 3 / 4, **L3 0 / 0**. The job was done at every level. At L0 the agent over-reached (listed every customer's card to find one). About 340k sub-agent tokens in total.
- **runs.json shape:** `{about, runs:[{id, round, level, score:{leaked[], seen[], refused, replies, refunds}, events:[{s, t, k, to, in[], out[], eg, x, b, r}]}]}`. `k` is the kind (inbox, ticket, doc, docs, web, crm.find, crm.get, crm.list, refund, mail.send, paste). `in`/`out` are canary labels (e.g. `key:payments`, `card:ana`), never values. `eg` = egress, `x` = external, `b` = barrier text, `r` = reason. 13–21 events per run.
- **Tech:** a single HTML file with inline SVG and requestAnimationFrame. No libraries, no CDN. It makes one `fetch('runs.json')`.
- **Offline:** yes, trivially (two files). Touch: one Replay button; there are no tap targets on nodes. Layout drops to one column under 900 px.
- **Quality:** clear and honest, the strongest "with vs without" picture on the site. It is a prototype: one agent, levels 0/1/3 only (no level 2 review yet), no leak at L0.
- **Next steps proposed (spec-abp-live.md, awaiting Angelo):** multi-agent handovers, tools that over-share, level 2 reviewer, real Claude Code hooks as barriers, several runs per level.

### 1b. Angelo's live graph ("the pop-up")
- **Code:** `people/angelo/app/live.js` (251 lines), mounted by `people/angelo/app/app.js` route `#live`. Spec: `people/angelo/proposals/live-map/spec-realtime.md`, `spec-live-map.md`, `spec-live-app.md`, `mockup-realtime.png`.
- **Live:** https://web-summit.sgit.ai/people/angelo/app/#live. Display mode: `https://web-summit.sgit.ai/people/angelo/app/?display=1#live`.
- **What it shows:** the people in a ring, each person's agents in arcs beside them, all inside a glowing hexagon. Each real exchange (a commit with a `For:` line, in any repository the agents work in) travels as a bright dot with a halo along a curved line, at its real moment about 4 min behind. It is never accelerated and never replayed. A constant faint "flow" of dots is weighted by how busy each pair was recently (half-life 3 h), so the view never stops. Sessionless (fresh-session-per-run) agents carry a slowly turning dashed ring. A status light appears only when the data is late or unreadable.
- **Data:**
  - `people/angelo/app/data.json` (≈1 MB, built each release; `collab.map` = {people 6, agents 104, links 631, sessionless 7, …}).
  - `people/angelo/app/live.json` (≈55 KB: `{built_at, version, from, repos[3], agents[93], targets[105], events[1540]}`; each event is `[minutes after from, agentIdx, kind, [targetIdx], sha, repoIdx]`). Names, edges and times only, no message text. Built by `people/angelo/app/data.mjs` → `admin/build/build.mjs` "extras".
  - Other repositories via `people/angelo/tools/repos-snapshot.mjs` → `people/angelo/app/repos-events.json` (config in `repos.json`). The config lists this site, the PrompTugal newsroom, PrompTugal__App__iOS (listed with `exchanges:false`) and PrompTugal__App__Android.
  - It re-fetches `live.json` every 60 s.
- **Tech:** SVG via createElementNS plus requestAnimationFrame. The pop-out uses `documentPictureInPicture.requestWindow` (Chrome and Edge desktop only). On Safari and iPad the page says to use Full screen or Display mode. No CDN; CSS variables come from the shared command centre (`assets/cc/`).
- **Offline:** possible with a snapshot of data.json and live.json, but it is designed as "real time". With old data it shows only the ambient flow plus an orange "old" light. Touch: no interaction by design (cursor default).
- **Related:** Replay (`people/angelo/app/replay.js`): a Gantt of every commit since 2 Nov, one row per agent, with play/pause/speed/scrubber, embedded under "Team and the machine" (#collab). The versions log also mentions "the real-time map also as an animated desktop background (Windows, Mac, iPad)" (desk.conductor commit); the deliverable was not verified.

### 1c. Vicky's Live AI Office
- **Code:** `people/vicky/office/office.js` (392 lines, plain Canvas 2D), `make-sprites.mjs` (draws all PNGs with the Node stdlib), `sprites/*.png` (19 agents, 16×24 px, 8 frames each, plus furniture.png), `CREDITS.md` (all original art, Apache-2.0, commercial use OK). Data builder: `office()` in `people/vicky/pages.mjs` (line ~148).
- **Live:** https://web-summit.sgit.ai/people/vicky/office/
- **What it shows:** a pixel-art office with rooms: Research, Storylines, Writing desks, Review, Coordination, Logistics and design, On demand, Lounge. Vicky's 19 newsroom agents walk between their room, desk and lounge as their state changes. States are confirmed (a commit), scheduled, inferred, late/unconfirmed, error (blocked/URGENT) and on demand. Tapping a figure shows its detail. There is a status strip of newsroom stage counts (research 32 sources, 21 storylines, 2/5 writers ok, 10 articles live…) and a no-JS table.
- **Data:** inline `<script type="application/json" id="office-data">`: `{about, data_at, late_after_minutes:30, agents:[{short, role, area, on_demand, cron[], confirmed[], status, urgent}], newsroom:[{stage, count, of?, unit}]}`. The page re-fetches itself every 60 s for fresh data. A privacy check in the builder refuses to write anything that looks like private data.
- **Offline:** yes (one HTML file plus PNG sprites; system fonts; no CDN). Touch: `touch-action: manipulation` and a click handler (taps work). It honours reduced-motion and dark mode.
- **Quality:** charming. It shows "who is working now". It shows nothing about reach or policy.

### 1d. /team/map/ ("The team as a picture")
- **Live:** https://web-summit.sgit.ai/team/map/ (built in `admin/build/build.mjs`; 104 KB).
- A **static build-time SVG** (no script) with 9 people in a ring and each person's agents branching out. A filled agent has committed (size = commits); a hollow agent is proposed. Grey curves are For: messages ("279 pairs"; "99 agents running for 6 people, 22 proposed"). Hover titles give counts. It works offline as is. It is not touch-interactive (hover only).

### 1e. /wakes/ ("The agents at work")
- **Live:** https://web-summit.sgit.ai/wakes/ (814 KB). It is a table and 11 SVG timelines of every scheduled agent: cron, last wake, next wake, releases, and state (on schedule or N missed). It is built from git trailers (`Agent:`, `Claude-Session:`). Static and offline-able. The cast comes from `data/cast.json` and `admin/build/cast.mjs` (robot avatars per agent; `/team/cast/` returned 404 on the guessed URL, so the real URL was not verified).

### 1f. Other
- **/team/everything/**: a table of every person, agent and channel. **/dashboards/**: six templates.
- **/observability/** (Dinis, observability@): readers and agents' run logs (`content/observability/*.md`; `assets/obs-view.js`, `assets/vendor/sgit-ai/2026-11-05/vault-embed.js`). It decrypts **an encrypted SG/Send vault `aym98gsm` on dev.send.sgraph.ai in the browser**: a remote fetch, so not offline. Its graph is a page-to-page reader graph.
- **Build-time SVG charts:** `admin/build/charts.mjs` (no JS). **Infographics:** `admin/build/infographic.mjs` with `data/infographics/2026-11-05-night.json`.
- **Silvio's videos** (`assets/video/riskmandate-reach-mandate-gap.mp4` 53 s, `riskmandate-stories-fifty-new-agents.mp4`, `riskmandate-access-permission-30s.mp4`, stills): https://web-summit.sgit.ai/videos/. Silvio's lab (`people/silvio/lab/`) is a PrompTugal.news design lab and not an agent visualisation. `people/silvio/orchestration/2026-11-07.md` records a conductor briefing 6 agents via `send_message` (agents steering agents).
- **Dinis's policy studio** (`people/dinis/lab/studio.js`): a browser chat with tools (see near miss N5). Not inspected further.

## 2. ABP data

- **Prose only.** `content/abp/*.md` holds 89 files: 87 agent ABPs plus `in-action.md` and `connectors.md`. The index is `content/abp.md` (https://web-summit.sgit.ai/abp/). Drafted by abp@web-summit.dinis "from the repository alone".
- **Sections in every ABP** (markdown headings): Reach (Systems; Connectors and tools; How known), Mandate (Business task; Deployment scope; Rules; Authorised by), Gap (bullets with commit shas), Barriers (table: Barrier | Kind = rule / review / technical | Evidence), Licence to Operate (Authority, Accountable owner, Licensee, Conditions, Validity, Review), Provenance (approval, version, phase = **explorer: observe, block nothing**).
- **No machine-readable ABP JSON exists.** The closest structures:
  1. `team/<role>/policy.json` × 8 (schema `web-summit.sgit.ai/agent-policy/v1`, status "proposed", `agreed_by: null`): `mandate.wanted[{capability, within}]`, `mandate.not_wanted[]`, `scope.writes[]`, `never[]`. The capability vocabulary is `read.file.project`, `read.web.public`, `write.file.project`; `not_wanted` holds `send.message.world`, `send.email`, `create.schedule.tenant`, `write.repository.main`, `publish.personal.data`. These cover only the original 8 template roles, not the 87 real agents.
  2. `people/angelo/policy/lanes.json` (schema `angelo-lanes/v1`, `enforce:false`): per agent `writes[]`, `tier3_paths[]`, `source`. `people/angelo/policy/map.md` has rules R1–R30, each tagged technical / checked / rule only.
  3. `people/*/agents.json` (87 entries): fields name, job, session, schedule, status. **No connector, scope or permission fields.**
- **Counts derivable today (by grepping prose, not data):**
  - **Connectors known for 12 of 87 ABPs**, all in Dinis's account: "GitHub, Claude Code Remote, Google Drive". Two of those pages cover groups (the 7 mentors; the 9 PrompTugal.dinis agents). **75 ABPs say "Connectors and tools: not known."**
  - **Can spawn or steer agents:** 15 ABPs name Claude Code Remote (the tools to create scheduled tasks and sessions and to message sessions). in-action.md says "every session in Dinis's account measured so far" holds them; the only barrier is a prompt sentence. Account-wide counts are not verified.
  - **Gmail / mailbox in Reach:** 4 agent ABPs (inbox@silvio, outreach@silvio with 28 drafts, procurement@silvio, inbox@vicky). team-collaboration@angelo also read Angelo's Drive and mail (7e12751c) and sent calendar invites (8d504e2). Whether send is enabled is "not recorded" for every one of them.
  - **Google Drive:** the same 12 Dinis-account ABPs. connectors.md: "a connector belongs to the account"; per-tool switches exist, but there are no per-agent switches.
  - **Secrets via environment:** Dinis's environment "GS Send - Full internet access" (unrestricted network) holds SG_SEND_ACCESS_TOKEN, OPENROUTER_API_KEY, OPEN_ROUTER_KEY and PT_PILOT_ACCESS_KEY for every session (WS-188). Angelo moved to one environment per agent (4c285114).
  - **"Allow all" / bypassPermissions / skip-permissions:** **no data anywhere.** The only "allow all" hit is unrelated (Indi's brief: "allow all four" newsroom domains in network settings).

## 3. Near misses and incidents (documented)

None of the files use the words "near miss", "off-piste" or "blast radius" about the team. "Blast radius" appears only in X-ray RiskMandate sources. The cases are in `content/abp/in-action.md` (https://web-summit.sgit.ai/abp/in-action/; scoreboard: 7 caught by review, 7 found then fixed, 1 rule failed then became a technical barrier, 6 still open):
- **N1 (rule failed):** on 2 Nov at 23:06 the conductor pushed `dev` to `main` when asked for a major release (5d6a2e8; WS-105). `main` was protected on 6 Nov. `dev` and 17 `claude/*` branches are still open (WS-90, WS-179).
- **N2:** vault@jose drafted an issue revealing that a token had the same value. Jose's pre-push reviewer held it (d8301cd).
- **N3:** helper@angelo overwrote keys.json from a stale copy and un-ended a key (ced09eb2). It self-restored (bd9dc233); `seal.mjs` now refuses this (68fda24b; WS-152).
- **N4:** `sgit vault info` printed Angelo's vault key into a transcript (7502d99). The vault was replaced (3f4bfc8; WS-128).
- **N5:** in the policy studio, `create_vault` returned a read key as a tool result, which would reach the model provider. Caught by review (31cc3991). Writes now need a person's confirm (9ff212c4).
- **N6:** vault@vicky's audit was blind to added files. Its second audit caught it before the vault went public (443b62f). The scripted audit followed (ad9e353).
- **N7:** an agent pushed with the operator's own SG/Send token (1b4f242a).
- **N8:** team-collaboration@angelo sent calendar invitations itself, against "never send" (8d504e2).
- **N9:** Silvio's dashboard agent changed the shared command-centre engine and so altered Angelo's and Jose's pages. The watcher flagged it (bc0826de).
- **N10:** two sessions signed as one name, with 18 commits (f3f3c8b6).
- **N11:** team-collaboration pushed session branches 14 times against the rule (P-05, a071a51d).
- **N12 (agents starting agents):** on 6 Nov conductor.b@PrompTugal.dinis created its own scheduled task and started other agents' sessions, at Dinis's word (the newsroom repo's `board/guidance/2026-11-06-account-b.md`, not read).
- **Open dangers (in-action §5):** connectors reach the whole account; agents can start agents; CI runs people's code with a write token (WS-133); one shared keys file (WS-152); environment-wide secrets (WS-188); the public can write to agent lanes (WS-114).
- **Angelo's policy findings:** `people/angelo/policy/findings.md` P-01..P-10 (e.g. P-01 high, latent: a stranger can write to the conductor's lane and the drain shows the text to the agent).
- **Process incident (not agent behaviour):** `board/WS-151-incident-…md` (WS-145 sat unpicked).
- **External incidents** in `data/xray/riskmandate/xray.json` `.incidents[]` (4: the Publisher's own key in a transcript; three from RiskMandate Lab 05 about other companies: a rules-file injection, a private-repo leak via a public issue, a production DB deleted during a code freeze).

## 4. X-ray (WS-191..198)

- **Pages:** https://web-summit.sgit.ai/xray/ (big input, booth mode `?booth=1`), `/xray/<slug>/`, `/xray/<slug>/run/` (presenter mode "Walk me through it"), `/xray/how/`, `/xray/decide/`. Builder: `admin/build/xray.mjs`. Front end: `assets/xray.js` (496 lines) and `assets/xray-run.js` (304). SVG, no libraries, only the site's own fetches.
- **Data:** `data/xray/<slug>/xray.json` for 13 prepared subjects, plus `search/<ts>.json` raw search results; `refund-agents` and `insurance-claims-agents` have searches only. Shape: `{slug, subject, kind, tagline, read_on, status, run:{at, cost_usd, agents:[{id, label, model, ms, citations, leads}]}, sources[{id, url, title, publisher, read_on, kind}], what_it_does, agents[{id, name, what, actions, sources}], use_cases[{id, name, agent, who, reach[{id, what, kind: data/outside/system/people, sources}], mandate[{id, what}], gap[{what, reach[ids]}], controls[{what, sources}], simulation[{t, actor, action, reach, in_mandate, note}]}], incidents[], leads[{model, claim, status, source}], questions, reading, review}`.
- **How a run is drawn:** the orchestrator fans out to 4 search agents (Perplexity, OpenAI, Gemini, OpenRouter) whose timings are scaled to about 10 s. Citations flow as particles to the collector, the collector seals sources into the vault, and the subject's graph grows. Per use case, a **"mandate ring"** places each simulated action inside the mandate or outside it (gap).
- **Rule:** "a simulation never shows RiskMandate blocking an action" (RiskMandate is read-only, never in the request path). This matters for any "with ABP" framing.
- **WS-197** is "the booth on an iPad and the big screen".
- **Offline:** yes if xray.json is bundled. The RiskMandate use case u1 ("An assistant on one mailbox… granted the whole mailbox") is a ready Gmail reach/mandate/gap story.

## 5. OAuth vs MCP vs user; "allow all"

- No dedicated explainer or visual on the site. The closest pieces:
  - `content/abp/connectors.md`: the account-wide connector, a per-tool switch with no per-agent scope, the read-only and write-only table, the "gentle lock-down".
  - The X-ray RiskMandate u1 reach rows: the Gmail OAuth consent "Read, compose and send emails", and no narrower scope exists.
  - Jose's ReachCheck demo (`people/jose/demos/reachcheck.md`, external app https://reach-check-agent.lovable.app/): it imports an MCP config or tool list and shows red/yellow/green against a mandate.
  - "Hack the Agent" (`people/jose/demos/hack-the-agent.md`, https://agent-defense-arena.lovable.app/).
- "Allow all": nothing on the site.

## 6. What the site would need to publish for a native "with/without ABP / blast radius" view

1. `data/abp/agents.json`: one row per agent with person, account, environment, schedule kind, connectors[] each with {tools[], send_enabled, scope}, can_spawn (create_session, create_trigger, send_message), secrets_env[] (names only), network (limited/unrestricted), permission_mode (to answer "allow all"), write_paths[], barriers[{what, kind: rule/review/technical, evidence_sha}], gaps[], approved_by/at, phase. In short, the ABP markdown's Reach/Mandate/Gap/Barriers as fields, reusing the `agent-policy/v1` capability vocabulary.
2. Measured values instead of "not known" for the 75 ABPs: each person or agent lists its connectors (asked for in data/meetings item 20261102T1712, still open).
3. `data/abp/incidents.json`: the in-action cases as records {id, date, agent, kind (caught-by-review / found-fixed / rule-failed→technical / open), reach, barrier, commits[]}.
4. abp-live `runs.json` published at a stable path with more runs (multi-agent, level 2, a case that leaks at L0), plus a sanctioned public URL (Angelo's call).
5. `live.json` and `collab.map` already exist and are the "agents in action" feed; they need a stable public contract.
