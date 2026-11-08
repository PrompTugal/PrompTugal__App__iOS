# ABPs in action: the show, the missing explainer, and the 5-minute ABP

> Sixteen existing animations, each played from a local copy and checked frame by frame, put in one order that tells the ABP story in about five minutes. Then the scene-by-scene script for the one animation that doesn't exist yet (OAuth, then MCP, then the user, then "allow all"), and a framework for drafting an ABP with a visitor in five minutes without keeping anything about them.

**Pack date:** 8 November 2026 · **Author:** conductor@ios.PrompTugal.dinis · **How it was checked:** each piece served from a local clone and opened in headless Chromium at 1280×720. Engine pieces were captured at 10 s, 24 s and the end (`?ruvt=` / `?review`), the others at 6, 18 and 32 s. Nothing needed the network.

## What the frames show

| Piece | Source | What happens on screen | Use |
| --- | --- | --- | --- |
| **ABPs you can watch** | team site, Angelo (approved to show) | Three hexagons per round, level 0 / 1 / 3. "5 secrets in its context", then 3, then none. The job is done every time | **The proof:** a real agent, with and without |
| **Policy gate** (studio v4, ported) | ruv.sgit / Presentation | Round 1, Ruflo default (allow-all): 11/11 allowed. Round 2 with the ABP: **4 denied, 2 held for Dinis Cruz, 5 allowed**. Hash-chained receipts, "ledger valid" | **With and without**, same 11 actions |
| **The Isometric Office** (studio v5) | ruv.sgit | Agents at desks; the queen hands out tasks; actions walk to the ABP gate at the door; "11 actions at the gate: 4 denied, 2 held for Dinis Cruz, 5 allowed"; one vault holds the evidence | **The booth's big screen.** The most "agents in action" piece |
| **The Hive in 3D** (studio v6) | ruv.sgit (three.js, stored locally) | Roles orbit the queen; each writes to its own vault branch, encrypted. "No policy: every action passes"; then with the ABP, 4 denied and 2 held; a wireframe sphere closes | Attract loop; you can drag to orbit |
| **One action's journey** | ruv.sgit / Presentation | Three acts, six boxes each (ask, role, ABP row, engine, what happens, receipt). `file.write`: allowed. **`email.send gmail`: mandate no, DENIED, "agents draft, a person sends"**. `deploy`: waits for Dinis | **The Gmail story**, one action at a time |
| **ABP compiles into Ruflo** | Presentation (ported) | The ABP table (`verb.object.reach`, yes / no / approval) becomes 36 rules in Ruflo's own engine. Real actions hit it: "6 of 11 actions stopped: 4 denied, 2 sent to a human" | How it works, in one slide |
| **E02 The blast radius** | Presentation | Grant: 16 things. Mandate: 4. Excess 12, grouped: credentials 4, files 3, network 2, records 2, schedule 1. "12 of 12 have no control" | **The problem** |
| **E09 Mandate against grant** | Presentation | The ABP in one picture: the mandate inside, the grant around it, the delta numbered, then the barrier per row | The concept |
| **E10 Only a boundary is a control** | Presentation | Four barrier kinds: none, expectation, setting, boundary. Claude Code with confirmations off: **"One barrier moved, and not one number did."** | **"Allow all"**, made visible |
| **E11 The kernel was told first** | Presentation | SHarness: write the policy, hash it, the kernel enforces, six probes, "6 of 6 held" | The fix exists (designed and measured) |
| **E12 The radius, contained** | Presentation | "Today, this agent: 12 of 12 bounded by nothing" becomes "Designed: 8 of 12 still bounded by nothing", rows going dark | Honest: designed, not today |
| **E14 Autonomy, earned level by level** | Presentation | A licence to operate (owner, holder, policy, expiry) and a staircase from read only to act alone, each level unlocked by evidence | The destination |
| **ABP enforcement / review** | Presentation | Five steps every wake; the editor approves each agent's policy item by item | Text-heavy: iPad only, or skip |

## The ABP show: about 5 minutes, in this order

1. **E02, the problem:** an agent's grant is 16 things, its job needs 4, and nothing stands in front of the other 12. (45 s)
2. **E09, the instrument:** an ABP writes the mandate down and derives the gap. (40 s)
3. **E10, "allow all":** switch confirmations off and nothing changes in the numbers; only a boundary is a control. (40 s)
4. **The Isometric Office**, then **the Policy Gate:** the same 11 actions, first with no policy (all through), then with the ABP: 4 denied, 2 sent to a person, every decision a receipt. (60 s)
5. **One action's journey, the Gmail act:** `email.send`, mandate no, denied, "agents draft, a person sends". (30 s)
6. **Angelo's ABPs you can watch:** a real agent, planted traps; secrets in its context go 5, then 3, then 0, and the job still gets done. (45 s)
7. **E12, then E14, the honest ending:** what is measured and what is designed; autonomy earned level by level, with a licence and an expiry. (45 s)

The rule from riskmandate.ai holds throughout: RiskMandate itself never blocks anything (it is read-only and never in the request path). In these pieces the enforcing is done by Ruflo's engine, the kernel (SHarness) or a gateway, and the ABP is the written mandate those enforce. The captions must say so.

## The missing piece: "OAuth, then MCP, then you, then allow all" (a script)

It is drawn in the same visual language as E02, E09 and E10: the agent as a red dot, the mandate as a white ring, grant items as numbered dots, and the four barrier kinds (none, expectation, setting, boundary). It is 1280×720, about 50 s, on the same engine (`slide.js`, RuvClock steps). Numbers come at build time from the Gmail and Workspace ABP vaults on riskmandate.ai (Claude's Gmail connector `oc433z3m`, Gmail read-only `l2zlv3ng`, Google Workspace MCP `pq7ct02p`), never invented.

| Step | On screen | Caption (draft) |
| --- | --- | --- |
| 1. Three parties | Left: **you** and your mailbox. Middle: an **MCP server**. Right: the **agent**. Nothing connected yet | "Three parties touch your mail: you, a server, and an agent." |
| 2. OAuth: the grant | You click "Allow" on a consent screen; a scope travels to the server as a token. The scope opens into numbered dots (`read.message`, `send.message`, `delete.message`, …) | "OAuth is where the grant is set: once, by a click, for the whole scope." |
| 3. MCP: the tools | The server turns the token into tools the agent can see (`search`, `read`, `draft`, `send`, …), each wired to grant dots | "The MCP server turns the grant into tools. Every tool it exposes, the agent can call." |
| 4. You: the mandate | You say what the agent is for: "triage my inbox, draft replies". A white ring settles round 2–3 dots; the rest stand outside: **the gap** | "What you meant is the mandate. Everything else the token allows is the gap." |
| 5. The prompt | A call to `send` raises "Allow once / Always allow". Barrier kind: **setting** (half-filled), between the agent and `send` | "An approval prompt is a setting the agent's own account can change." |
| 6. Allow all | "Always allow" is tapped. The setting icon slides away, and **no number on screen changes** (as in E10) | "Allow all removes the last person from the path. The grant was already the whole mailbox." |
| 7. One email | A message arrives with hidden instructions; the agent reads it, and a red dot travels from `read` to `send` to the world (E08's trifecta, faded behind) | "Private data, untrusted content, a way out: the agent now has all three." |
| 8. Where a boundary sits | Three places light up: a **narrower OAuth scope** (read-only: a boundary above the grant), the **server's tool list** (a setting), a **gateway or kernel** (a boundary) | "Only a boundary is a control: a narrower scope, or something the agent cannot switch off." |
| 9. The record | The ABP card for this agent: grant, mandate, gap, barriers, a named owner, an expiry | "An Agent Behaviour Policy writes this down, names who accepted it, and says until when." |

Built by the iOS dev agents (account B) on the Presentation engine, with Dinis's review. It joins the playlist between E10 and the Policy Gate.

## The 5-minute ABP, drafted with a visitor

**The aim:** in five minutes, with a visitor at the booth, draft an ABP for one agent they already run, and hand it to them. We keep nothing about them.

| Minute | Step | What the iPad shows |
| --- | --- | --- |
| 1 | **Which agent?** Pick the closest of the 16 template ABP vaults (Claude Code, Claude in the browser with connectors, Gmail connector, M365, Workspace MCP, n8n, GitHub Actions, a scheduled job…) | The grant pre-fills from the template, as numbered dots (E09's picture) |
| 2 | **What is it for?** The visitor taps the capabilities they meant it to have, as chips in the vocabulary (`read.message.account`, `send.message.world`, `write.file.project`…) | The mandate ring forms |
| 3 | **The gap** appears on its own: grant minus mandate. Irreversible rows are marked from the vocabulary's undo classes | E02's grouped dots, live |
| 4 | **What stands in the way?** For each gap row, one tap: none, a rule in prose, a setting, a boundary | E10's four barrier kinds |
| 5 | **Who accepts it, and until when?** A role, not a name, and an interval (30, 90 or 180 days) | The ABP card and a Licence to Operate preview |

**What the visitor takes home, with nothing stored:**
- The card as a **QR code** that holds the whole draft in the link's fragment (the part after `#`, which a browser never sends to a server), opening a riskmandate.ai page that renders it. Or AirDrop the card as a PDF.
- The draft says "**a draft, not reviewed**", with a link to the reviewed level (two sessions, signed by a professional).

**What we keep:**
- By default, nothing.
- If the visitor agrees at the end, an anonymous copy: agent type, mandate rows, gap rows, barrier kinds. No person, no company, no free text. It goes to a team vault lane, so the team learns which agents people actually run and where the gaps are. This is Dinis's call before the summit.
- The play log counts "5-minute ABP completed, template = gmail-connector, 5 rows, 4 min 40 s". No visitor data.

**Built on:** the ABP schema and the capability vocabulary in `SGit-AI__Website__Ruv/abp/` (`verb.object.reach`, 23 primitives, undo classes), the 16 template vaults read by the native sgit reader, and the E02 / E09 / E10 drawing styles redone natively in SwiftUI, because this screen is interactive, not a replay. It works offline. The QR needs no network at the booth.

## Decisions for Dinis

1. **The show's order** above: right, or lead with Angelo's real agent?
2. **The OAuth / MCP explainer:** build it to this script?
3. **The 5-minute ABP:** keep anonymous copies if the visitor agrees, or keep nothing at all?
4. **Is there a riskmandate.ai page** that can render a draft from a QR fragment (try-it?), or should one be added?
