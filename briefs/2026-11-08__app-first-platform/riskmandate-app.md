# The RiskMandate app

> What the RiskMandate iOS app should hold, built from what riskmandate.ai and the team site already have: the argument in a minute, the live demos read natively from their vaults, every Agent Behaviour Policy (the templates and our own 100+ agents), the X-ray, stories and scenarios, and an attended booth mode with a big screen. iPad first, iPhone as the companion in a conversation.

**Pack date:** 8 November 2026 · **Author:** conductor@ios.PrompTugal.dinis · **Status:** proposal for Dinis

## Why this app can be strong quickly

1. **The demos already run on sgit vaults.** riskmandate.ai's live demos and its 16 template ABP vaults are encrypted vaults opened with deliberately published read-only keys. The iOS apps read and verify sgit vaults natively (SGitVault, PTVaultUI). So the app opens the same vaults and draws them natively, offline once synced, with the same source as the website.
2. **The graph engine exists.** PrompTugal's native graph explorer (1,688 nodes) can draw the RiskGraph and the OWASP graph.
3. **The data is published.** riskmandate.ai has `.well-known/agent-content.json`, `versions/index.json`, `vaults/index.json` and `stories/board.json` and `cast.json`. The team site has an ABP for each of our agents (`content/abp/`, 90 pages) and the X-ray data (`data/xray/<slug>/xray.json`).

## The rules it keeps

These come from riskmandate.ai and the X-ray board (WS-191, WS-197):

- No claim for RiskMandate beyond riskmandate.ai. It "measures what your agents can actually reach, evidences the controls that contain them, prices the exposure, and produces that record", and it is "never in the request path: read-only by design". **A simulation never shows RiskMandate blocking an action.**
- Public facts only, each with its source URL and the date it was read.
- **No visitor's email or personal data stored** in the app, the repository or a page.
- **No API key in the app for the booth.** An LLM step goes through the booth request path (WS-194): a lane message the agent runs at its next wake.

## The map

```
 ┌──────────────────────────────── RISKMANDATE  (ai.riskmandate.app) ─────────────────────────────┐
 │                                                                                                 │
 │  1 THE ARGUMENT        grant ≠ mandate · no deny button · never in the request path ·            │
 │    (60 seconds)        accepted ≠ acceptable · Insurability Index (0–100, 5 dimensions) ·       │
 │                        SG/Vault          ── native cards, swipe, big type                       │
 │                                                                                                 │
 │  2 LIVE DEMOS ★        RiskGraph Explorer · Licence to Operate · Field demo (8 questions,       │
 │    (read from their    "built to be handed to a stranger on an iPad") · Agentic Browser         │
 │    vaults, natively)   Isolation · File security (11 steps) · Agent permission games (40 Qs)    │
 │                                                                                                 │
 │  3 ABP EXPLORER ★      16 template vaults (Gmail, Drive, M365, Claude Code CLI, Claude web,     │
 │                        n8n, GitHub Actions, Dropbox MCP, …) + OUR OWN 100+ AGENTS (team site    │
 │                        abp/): for each, what it can reach · what it was asked · the gap ·       │
 │                        what stands in the way. Search: "what can a Gmail connector reach?"     │
 │                                                                                                 │
 │  4 X-RAY ★             prepared X-rays (10–20 subjects) drawn natively: the mini agents, the    │
 │    (with WS-191)       growing graph, use cases with mandate and reach, the simulated record.   │
 │                        A typed name becomes a booth request (lane message), with no key in the  │
 │                        app                                                                      │
 │                                                                                                 │
 │  5 SCENARIOS           "How long will you accept this risk?": 4 cards with an interval, plus    │
 │                        the 4:5 post images for the share sheet                                  │
 │  6 STORIES             a cast of 9, 9 storyboards, 4 drawn: a panel reader on the iPad          │
 │  7 RULES               26 rules, before and after each line · the method · OWASP (8) + graph    │
 │  8 5-MINUTE ABP        the summit offer: "bring one agent, we draft its ABP in five minutes".   │
 │                        A worksheet the team fills with the visitor, saved to OUR vault, shown   │
 │                        as a card. No visitor email: a QR to /try-it/ to take home               │
 │  9 LIBRARY             library · questions · RAMM · insurance · licence to operate · business   │
 │                        cases (21) · articles · videos (offline)                                 │
 │                                                                                                 │
 ├─────────────── iPad (booth, attended) ─────────────┬────────── iPhone (in a conversation) ──────┤
 │ demo mode: full screen, big type, one tap back      │ the argument cards · ABP lookup ·          │
 │ home · second screen over AirPlay or HDMI: the big  │ show a story or scenario · QR to try-it ·  │
 │ screen shows the graph or X-ray while the iPad      │ send "follow up with them" to the team     │
 │ drives · the 30 s X-ray film as the idle loop       │ lane (no personal data)                    │
 └─────────────────────────────────────────────────────┴────────────────────────────────────────────┘
   sources: riskmandate.ai (pages, agent-content.json, vaults/index.json, stories/*.json, demo vaults)
            web-summit.sgit.ai (content/abp/ = our agents' ABPs, data/xray/<slug>/xray.json, videos vault)
   shared:  PTCore · PTVaultUI + SGitVault (demo and ABP vaults) · PTGraph (from PTNews) · PTSync · PTLanes
```

★ = what makes the booth.

## Build it in two steps

**Step 1: by Monday 9 Nov, the booth works.**
1. The app shell: argument cards, Demos, ABPs, Scenarios, Stories, Library, and a demo-mode switch.
2. **Demos first as in-app web views** of the riskmandate.ai demo pages, cached for offline. They work today, with no new code per demo.
3. **The ABP explorer, native**, reading the 16 template vaults with their published read keys, plus our agents' ABPs from the team site. Card view, search, offline.
4. Scenarios and Stories, native, from the published JSON and images.
5. Demo mode and a second screen. AirPlay or HDMI show the graph or X-ray full-screen on the big screen.

**Step 2: during the summit.** Turn the web demos into native screens, one at a time:
1. The **field demo**, which is built for an iPad.
2. The **RiskGraph**, on the shared graph engine.
3. **Licence to Operate.**
4. The **5-minute ABP worksheet.**
5. The **X-ray client**, with the X-ray team. It draws prepared runs and sends booth requests through the request path.

## To agree with others

- **X-ray (WS-191 to WS-198, xray@web-summit.dinis and Silvio's team):** the app is a client of their data and their request path, not a second X-ray. Agree the format of `xray.json` and the lane for booth requests.
- **riskmandate.ai's repository** (not found in this account's list): add a `manifest.json` (or treat `agent-content.json` as one) so the app syncs only what changed. Publish the demo vaults' read keys in a machine-readable list; `vaults/index.json` may already be it.
- **The field demo's LLM step:** riskmandate.ai says it "uses an LLM without ever holding the API key". The app keeps that property: it holds no key at the booth.

## Questions for Dinis

1. Which three demos matter most at the booth? My guess: the field demo, the RiskGraph and Licence to Operate.
2. In the ABP explorer, show **our own agents' policies** next to the templates? It's the strongest proof ("we run 100+ agents under ABPs"), but it shows our internal agent names.
3. The 5-minute ABP: keep the drafted ABPs in a team vault (no visitor data), or only on the iPad and gone after the conversation?
