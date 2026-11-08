# RiskMandate app: the visualisation player

> The research behind the RiskMandate app's showcase: about 50 animated pieces and a dozen interactive pages that already exist across our repos and sites. Nearly all of them can be copied into the app and played offline. They sit behind one native menu, are voted on by the team through an append lane, and every play is logged. It also covers what is missing for "show our agents in action": a table of agents and capabilities, and an OAuth / MCP / user explainer.

**Pack date:** 8 November 2026 · **Author:** conductor@ios.PrompTugal.dinis · **Research:** three read-only inventories in [research/](research/ux-book-presentation.md) ([team site](research/team-site.md), [riskmandate.ai and news](research/riskmandate-news.md))

## What we found

| Source | What is there | Offline as is? |
| --- | --- | --- |
| **Presentation**, The Ultimate Insider (`SGit-AI__Website__Presentation__The-Ultimate-Insider`) | **About 50 animated pieces** on one 9 KB engine (`talk/engine/slide.js`): motion M01–M03, studio E01–E14, 10 SHarness pieces, the policy-gate and action-journey ports, and 27 deck slides. Plain JS and SVG, no libraries. `talk/talk.json` holds the 58-slide running order **with the spoken script**. | Yes, after copying about 3.2 MB (all) or about 0.6 MB (top 15). About 15 pieces need a local URL handler for their JSON |
| **Book** (`…Book__The-Ultimate-Insider`) | No animations. 28 clean infographics and 16 Wardley maps (5.6 MB). Also sold on Leanpub, so check the terms before using the images | Yes (images) |
| **riskmandate.ai** | 85 pages, each one HTML file with **inline CSS and JS and no external dependencies**. The risk propagation visualiser, 4 animations (`assets/anim/`), scenarios, grant-gap, the ABP vault pages, RAMM, the Index, stories (1.6 MB of panels), 24 rules | Yes, nearly all |
| **riskmandate.ai live demos** | RiskGraph Explorer, Licence to Operate (13 MB), the field demo, Browser Isolation, File security, Permission games. Each opens a vault from another site at runtime; the read keys are published in the pages | No. Pre-fetch with the native sgit reader and give the page a stand-in for its vault calls |
| **Team site** | Angelo's **"ABPs you can watch"** prototype (with and without, 3 levels, one HTML file plus 22 KB of data); Angelo's live graph of agents talking; Vicky's Live AI Office (pixel art, 19 agents); the X-ray (13 subjects, mandate ring); **documented near misses** (the in-action page) | Yes, from a snapshot. The live views need a replay mode |
| **UX** (ux.sgit.ai) | A register of 63 UX findings, no animations | n/a |
| **"uv.sgit.ai"** | Most likely **ruv.sgit.ai** (`SGit-AI__Website__Ruv`). The player and the studio ports came from there. It is not visible to this account and this session's network refuses it | Not checked: may hold more pieces |

## The first playlist (a proposal for the vote)

Ranked by impact for the booth and ease of putting it in the app. ◆ = no data files at all.

| # | Piece | Shows | Source |
| --- | --- | --- | --- |
| 1 | **ABPs you can watch** | The same agent and job at level 0, 1 and 3: fake secrets reaching the agent's context 5/4 → 3/4 → **0**, with the job done every time | team site, Angelo's prototype (his call to show it) |
| 2 | **M01 "The building"** ◆ | People stop at a room, agents keep going: insider risk and blast radius | Presentation |
| 3 | **Risk propagation visualiser** | One agent: 5 of its 9 capabilities never asked for, each travelling up the org chart to the board. Connect, disconnect and add controls | riskmandate.ai |
| 4 | **Policy gate** | 11 actions with no policy (all allowed), then under a policy (4 denied, 2 sent to a human), with receipts | Presentation, studio ports |
| 5 | **E09 "Mandate against grant"** | An ABP in one picture | Presentation |
| 6 | **E10 "Only a boundary is a control"** | Turning Claude Code's confirmations off ("allow all") moves one barrier and changes no number | Presentation |
| 7 | **E02 / E12 "The blast radius", then "contained"** | Everything the grant reaches, then with and without a policy | Presentation |
| 8 | **E08 "The lethal trifecta"** ◆ | Private data, untrusted content and a way out | Presentation |
| 9 | **E01 "What an agent is"** ◆ | Ends on agents calling agents | Presentation |
| 10 | **Near misses** | Our own documented cases: a vault key printed into a transcript, a push with the operator's token, invitations sent against "never send", a conductor starting sessions. 7 caught by review, 7 fixed, 6 open | team site, in-action page, plus M02 "It could have been much worse" |
| 11 | **Scenarios** | "How long will you accept this risk?", 10 cards that build an acceptance record | riskmandate.ai |
| 12 | **X-ray: one mailbox, the whole mailbox granted** | The Gmail story, as a mandate ring | team site, X-ray |
| 13 | **The 16 ABP vaults** | Grant, mandate and gap for Claude Code (confirmations on and off), connectors, MCP servers, OAuth read-only scopes | riskmandate.ai, native sgit reader |
| 14 | **The live demos** | RiskGraph Explorer, Licence to Operate, the field demo | riskmandate.ai vaults, pre-fetched |
| 15 | **Vicky's Live AI Office / Angelo's live graph** | Our agents at work right now (online), or a replay of the day (offline) | team site |

## How the player works

```
 ┌───────────────── RiskMandate app · Visualisations ─────────────────────────────────────┐
 │ ☰ PLAYLIST            │                                                                │
 │ ★ ABPs you can watch  │        ┌──────────────────────────────────────────────┐        │
 │   The building        │        │                                              │        │
 │   Risk propagation    │        │     piece, played from the app's own         │        │
 │   Policy gate         │        │     files (pt-local://viz/…), 16:9,          │        │
 │   Mandate vs grant    │        │     letterboxed                              │        │
 │   …                   │        │                                              │        │
 │ ── by theme ──        │        └──────────────────────────────────────────────┘        │
 │   with / without ABP  │  ◀ prev   ⏯ play/pause   ▶ next   ⏩ 1× 1.5×   ⤢ big screen    │
 │   blast radius        │  ───●────────────── step 3 of 7 ────── 0:31 / 0:48 ──────      │
 │   agents → agents     │  caption: the spoken line from talk.json                      │
 │   near misses         │  👍 3   💬 2   (team votes, offline-safe)                      │
 └───────────────────────┴────────────────────────────────────────────────────────────────┘
```

- **Local files only.** Every piece and its data is bundled into the app at build time and served through a custom URL scheme (`WKURLSchemeHandler`). That fixes the JSON fetches, the paths starting with `/` and the same-origin checks. No network, ever, for a bundled piece.
- **Native controls drive the pieces.** Each Presentation piece exposes `window.RuvClock` (seek, pause, play, speed) and its step stops. The native bar calls them, so scrubbing, stepping and the big-screen view are native even though the drawing is JavaScript.
- **Captions and running order** come from `talk/talk.json`, which holds the 58-slide order and the spoken script.
- **Big screen:** AirPlay or HDMI shows the piece full screen while the iPad keeps the controls.
- **iPhone:** pieces are 16:9 at 1280×720, which is unreadable in portrait. On iPhone the player rotates to landscape. Pieces with lots of text are iPad-only.
- **Reduce Motion:** the engine jumps to the last frame when iOS Reduce Motion is on. In the player, honour it with an "animations are off on this device" note and a play-anyway button.
- **Network code removed at build time:** the comment pane (`pane.js` posts to a vault and can call openrouter.ai), the service worker, store and contact links, and the leaderboard. A link that truly needs the network shows "needs a connection".
- **Vault demos:** the build pre-fetches each demo vault with the native sgit reader, using the read key published on its page at build time, never kept in the repo. The page gets a small `window.sg` stand-in that serves the pre-fetched files. The AIUC-1 vault stays out; its key is held back on purpose.
- **Licences:** everything found is Apache-2.0, with UX content under CC BY 4.0. Keep `LICENSE-ruv-sgit.txt` and the Ruflo MIT credit beside the studio ports. Check the book's Leanpub terms before using its images.

## Voting and the record of what was shown

- **Votes and comments** go to an append lane, `lanes/team/viz-votes`, the same mechanism as Messages. Each entry has the piece id, version, vote, comment, the team member and the device key signature. Entries wait in an outbox when offline and send later. The team tallies in the app.
- **The play log** records, for each play, the piece id, start and end time, steps viewed, whether a big screen was used, and the app version. It is stored on the device and pushed in batches to a team observability lane when online, so the debug panels can show it.
- **No visitor data**, ever: no names, emails or faces. It counts that a piece was shown, not who watched.
- **The 5-minute ABP and other things drafted on the iPad** follow the same path: written to the team vault when online, queued when not, never containing visitor personal data. The framework for it is still to be designed with Dinis.

## What is missing for "our agents in action"

What you asked for: which agents reach my Gmail and Drive, which can start other agents, OAuth vs MCP vs user, "allow all", blast radius, with and without an ABP. The visuals exist, but the data does not:

1. **A table of agents and capabilities.** Today the 87 ABPs are prose only.
   - Connectors are "not known" for **75 of 87**.
   - Gmail is in reach for 4 (whether they can send is not recorded).
   - 15 name Claude Code Remote, meaning they can start or steer sessions.
   - No agent records "allow all".

   The team site needs one JSON file, one row per agent: connectors and tools (send on or off), whether it can start sessions or scheduled tasks, secret names, network level, permission mode, write paths, and barriers with evidence. Then the app draws the "who can reach my Gmail" graph and the blast radius from real data. Measuring the 75 unknown agents is a team task, first asked at the 2 Nov stand-up.
2. **An incidents JSON** built from the in-action page, so near misses become a native timeline.
3. **An OAuth / MCP / user explainer.** It doesn't exist anywhere. It is the one new animation to commission: user grants an OAuth scope → MCP server exposes tools → the agent calls them → "allow all" removes the last human step. It can be drawn on the same engine as E10.
4. **Angelo's prototype** made public at a stable URL, with richer runs: level 2, several agents, and a case that actually leaks at level 0. That is his call.
5. **A stable public contract** for `live.json` and the map data, so the live graph and the AI Office replay offline from a snapshot.

## Build order (account B's sessions)

1. **The player shell** (native menu, URL scheme handler, native controls, captions) **with the ◆ pieces** (M01, E08, E01). No data files, so it proves the engine works in a web view.
2. **The rest of the top 10**, with their JSON. Angelo's prototype goes in only once he says yes.
3. **The riskmandate.ai interactive pages:** the risk propagation visualiser, scenarios, grant-gap, RAMM, the Index.
4. **Voting lane and play log.**
5. **The vault demos**, pre-fetched with the native reader.
6. **Native rebuilds** of the pieces the vote picks.

## Questions for Dinis

1. **Angelo's "ABPs you can watch"** is marked "an experiment; nothing public". Ask Angelo to show it at the booth?
2. **ruv.sgit.ai:** is that the "uv" site? Its repo isn't visible to this account, so add it to the session or confirm that the Presentation copies cover it.
3. **The agents and capabilities JSON:** who builds it on the team site, and can measuring the 75 unknown agents happen this week?
4. **Book images:** fine to use in the app, given the Leanpub edition?
