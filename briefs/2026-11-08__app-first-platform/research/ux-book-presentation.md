# Visualisation inventory: SGit-AI UX, Book, Presentation, Cold-Read (The Ultimate Insider)

> Every animation, explainer and infographic in the UX, Book, Presentation and Cold-Read repos of The Ultimate Insider: what each shows, how it is built and what to copy so it plays offline in the app.

Research date 2026-11-08. Read-only shallow clones under `/home/user/sgit-ai/`:

| Repo | Clone dir | HEAD | Site |
|---|---|---|---|
| SGit-AI__Website__UX | `sgit-ai__website__ux` | 6f54e67 (2026-10-25) | ux.sgit.ai (CNAME) |
| SGit-AI__Website__Book__The-Ultimate-Insider | `sgit-ai__website__book__the-ultimate-insider` | a41a104 (2026-11-05) | the-ultimate-insider.book.sgit.ai |
| SGit-AI__Website__Presentation__The-Ultimate-Insider | `sgit-ai__website__presentation__the-ultimate-insider` | 424b67a (2026-10-30) | the-ultimate-insider.presentation.sgit.ai |
| SGit-AI__Website__Cold-Read__The-Ultimate-Insider | `sgit-ai__website__cold-read__the-ultimate-insider` | 14d6cfd (2026-10-30) | the-ultimate-insider.cold-read.sgit.ai |

All four LICENSE files: Apache License 2.0. UX README adds "Content CC BY 4.0. Code Apache 2.0." Presentation `studio-ports/` pieces are Apache-2.0 ports from SGit-AI__Website__Ruv (ruv.sgit.ai) at 47b4475, with `studio-ports/LICENSE-ruv-sgit.txt` kept beside them; their data credits Ruflo ("MIT"). The book is also sold on Leanpub; whether the manuscript text/images carry terms beyond the repo's Apache LICENSE: not verified.

**Verification method.** Every presentation piece listed as "renders" below was opened in headless Chrome at 1280x720 from a local static server (`python3 -m http.server` over `src/static/`, no build), screenshots in `/tmp/claude-0/-home-user-PrompTugal--App--iOS/133e047f-9b0b-5b77-ad81-2e60e69c181f/scratchpad/viz/shots/` (sheet1.png, sheet2.png, sheet3.png, plus single shots). The same piece opened via `file://` (e09file.png) rendered only its headline: the data-driven pieces need `fetch()` of local JSON, which `file://` blocks. Not tested on a real iPad/iPhone or in WKWebView.

---

## Headline finding

- **The animations are all in the Presentation repo** (`src/static/{motion,studio,studio-ports,talk}`): about 50 clock-driven 1280x720 animated "pieces" on one tiny in-house slide engine (`talk/engine/slide.js` 9.1 KB + `slide.css` 2 KB + `assets/tokens.css` 2.4 KB), plain JS + inline SVG (two use `<canvas>`), **zero CDN scripts, zero web fonts, no WebGL/three.js/d3**. The whole static tree (motion+studio+studio-ports+talk+tokens) is about **3.2 MB**.
- **The Book repo has no live animations.** It shows the talk's animations as screenshots/frames (JPGs, lab PDF experiments that freeze M01 etc. with Playwright) plus clean static print infographics and Wardley maps. "Old JavaScript-based animations" matches the presentation repo's engine, not the book (the book cites them).
- **The UX repo (ux.sgit.ai) has no visualisations or animations.** It is a register of 63 UX findings, principles and a "Newsroom Design Lab" (screenshots + links to vaults). Only JS: a 3.7 KB list filter. Nothing about agents/mandates beyond prose. "uv.sgit.ai" as named by Dinis: not verified to exist; ux.sgit.ai is the CNAME here.
- **The Cold-Read repo has one text-only deck** (16 slides from `deck.json`, no animation) and the same CSS-animated Venn on its home page as the other sites.

Counts (interactive/animated items):

| Repo | Animated / interactive pieces | Static figures worth reusing |
|---|---|---|
| UX | 0 | 0 relevant (UX screenshots only) |
| Book | 0 animated; 1 inline-SVG chart page (`review/read/graph.html`); page-by-page reader | 28 infographics (JPG), 16 Wardley maps (PNG), 70 chapter images (screenshots of talk/site) |
| Presentation | 3 motion (M01-M03) + 22 studio E-pieces/versions + 10 SHarness pieces + 9 B01 frames/indexes + 11 studio-ports + 27 deck slides + 5 map slides + 7 live-iframe slides; plus the player, the viewer, home-page Venn | 4 Wardley map SVGs |
| Cold-Read | 1 deck (text, 16 slides), 1 CSS Venn | 0 |

---

## Shared engine facts (Presentation) — apply to every "engine" row below

- **Format of a piece/slide**: one self-contained `index.html` with a `<div id="cv" data-end="N">` 1280x720 canvas, declarative reveals in `data-in/-out/-on/-count/-grow/-draw` attributes, optional `window.SLIDE_RENDER(t,S)` per-frame JS, optional `window.RUV_STEPS=[{t,label}]` stops. Loads `slide.css` (which `@import`s `../../assets/tokens.css`) and `slide.js` by relative path. Fonts: system-ui / Georgia / ui-monospace only.
- **Clock API** (`window.RuvClock`: `pause() play() setRate() seek(s) elapsed()`; URL `?t=4.5` freeze, `?static`/`?review` show end, `?theme=light`, `?ruvt=`, `?ruvpaused`). A native app can drive every piece with `evaluateJavaScript("RuvClock.seek(12)")` or by postMessage like the player does.
- **Interaction standalone**: auto-plays once (typically 30-56 s) and holds the last frame. No on-page controls, no touch handlers in `slide.js`; keydown is forwarded to a parent frame. **Stepping/scrubbing comes from the host**: `talk/player.html` (tap = next step, swipe = next slide, buttons for every key; touch-action CSS present) or `talk/engine/view.html` (play/pause/replay/scrub bar with stops, prev/next piece).
- **`prefers-reduced-motion: reduce` freezes every piece at its end frame** (`slide.js` line ~103). On iOS with Reduce Motion on, the app would show only end frames unless the host passes `?ruvt=0`-style override or patches this line.
- **Layout**: fixed 1280x720, scaled to fit and letterboxed (`fit()`); `body{position:fixed}` added specifically for iPad. iPad landscape: excellent (verified visually at 1280x720). iPhone portrait: scales to ~0.30, 14-20 px text becomes ~4-6 px, unreadable (verified at 390x844, e09phone.png). iPhone landscape: ~0.66 scale, small but usable (not verified on device).
- **Offline blockers in the engine family**: (1) pieces that `fetch()` JSON (`studio/data/*.json`, `studio-ports/data/*.json`, `motion/.../team-in-numbers.json`) render blank from `file://` (verified in Chrome); (2) the player and viewer `fetch()` `talk.json`, `pieces.json`, `fingerprints.json`, `engine/locked/locks.json` (the last three are build outputs of `admin/build/build.py`, not in git); (3) `assets/pane.js` (loaded by player/view) POSTs comments to a vault append API and can call `openrouter.ai` — strip it; (4) the player registers `../sw.js` service worker; (5) `talk/slides/live/*` iframe remote sites. Static showcases embed a JPG (`shot.jpg`) and draw a QR of a public URL locally (`qrcode.js`, 52 KB) — offline-safe, links just won't open offline.

Served URL = `https://the-ultimate-insider.presentation.sgit.ai/` + path under `src/static/`.

---

## Presentation repo: animated pieces

Data dep column: "none" = HTML + engine (+tokens.css) only; otherwise the JSON files it fetches (all local, relative). Size = the piece's own HTML. All rows: tech = plain JS on slide.js + inline SVG unless noted; external deps = none; auto-plays, steppable via RUV_STEPS in player/view; iPad landscape good, iPhone portrait unreadable. "Rendered" = verified screenshot.

### Motion (motion@, "the story" animations)

| ID | Path (`src/static/…`) | Title | Shows (own words) / concept | Dur | Data dep | Notes |
|---|---|---|---|---|---|---|
| M01 | `motion/lab/the-building/v1/index.html` (11.4 KB) | The building | "A building. One way in. A corridor that splits. Most turned left… People stop at a room. Agents don't stop." 22 people vs 36 agents walking a floor plan, turning red when doing damage; "A pattern, not a count." **Insider risk: humans self-limit, agents keep going; blast radius** | 43 s | none | Rendered. Most cinematic piece; used as beat `building`; book lab froze it in 3 frames. Very strong. |
| M02 | `motion/lab/could-have-been-worse/v1/index.html` (3.7 KB) | It could have been much worse | Midnight Blizzard at Microsoft and the Amazon Q extension: what was possible vs what happened. **Near misses** | 32 s | none | Rendered; simple, mostly text boxes; middle looks sparse. |
| M03 | `motion/lab/meet-the-team/v1/index.html` (7.5 KB) | Meet the team | "Nine agents. One editor. Every hour, each wakes at its own minute." Ring of agents around the editor, counters (510 commits, 164 releases, 0 holds), board/mail vaults, a key each, five-step wake. **Governed agent team; orchestration as the capability** | 40 s | `team-in-numbers.json` (3.8 KB) | Rendered. Mentions vaults as text only; no vault read. |

### Studio experiments (studio@/ruv.sgit@ "E" programme; questions from `studio/data/programme.json`)

| ID | Path | Title | Shows / concept | Dur | Data dep | Notes |
|---|---|---|---|---|---|---|
| E01 v2 | `studio/lab/e01/v2/index.html` (7.9 KB) | What an agent is, reach in motion | Chat model → one tool → more tools → loop → accounts → "Agents calling agents" (step 6 of 6), reach rings grow. **Agents spawning agents; reach growth** | 52 s | none | Uses `<canvas>` + SVG. Rendered. In talk (`s-e01`). |
| E01 v1 | `studio/lab/e01/v1/index.html` (5.4 KB) | the rings of reach | Same idea as rings | 48 s | none | Superseded by v2. |
| E02 v3 | `studio/lab/e02/v3/index.html` (12.2 KB) | The blast radius, by what it touches | "The blast radius is everything its grant reaches." Mandate (4) at centre, 12 excess rows grouped credentials/files/network/records/schedule, barrier shapes. **Blast radius; grant vs mandate** (Claude Code, confirmations on) | 56 s | `studio/data/abp-examples.json` (37 KB), `capabilities.json` (20 KB) | Rendered. Excellent; in talk (`s-e02`). |
| E02 v2 / v1 | `studio/lab/e02/v2/…`, `v1/…` | dot by dot / from the grant rows | Earlier versions | 56 / 54 s | abp-examples (+capabilities) | Superseded. |
| E03 | `studio/lab/e03/v1/index.html` (8.6 KB) | Every source is a way in | 16 ways words reach one agent (sent to it, it browses, it builds with, other agents) with real cases. **Prompt injection surface** | 48 s | `injection-sources.json` (24 KB) | Rendered. |
| E04 v2 | `studio/lab/e04/v2/index.html` (9.2 KB) | The over-enthusiastic agent, four paths | Replit, Cursor on Railway, Gemini CLI, AWS Kiro: goal / meant to stop it / what it did / loss. **Non-malicious insider; "allow all" harm** | 44 s | `over-enthusiastic.json` (39 KB) | Rendered. v1 (`e04/v1`, 50 s) superseded. |
| E05 | `studio/lab/e05/v1/index.html` (8.7 KB) | Pivoting, one system to the next | Nx s1ngularity and AI-orchestrated espionage, hop by hop. **Lateral movement / token reuse** | 44 s | `incidents.json`, `injection-sources.json` | Rendered. |
| E06 | `studio/lab/e06/v1/index.html` (9.0 KB) | Hard outside, soft inside | Perimeter holds; an agent already inside lights up admin page, service account, internal API, DB. **Insider inside the perimeter** | 50 s | none | Rendered; illustrative. |
| E07 | `studio/lab/e07/v1/index.html` (11.3 KB) | A typical deployment, mapped | CI job on hosted runner and a browser extension: one box vs everything it reaches. **OAuth/MCP/extension permissions; user vs host vs tenant reach** | 46 s | abp-examples, capabilities | Rendered. |
| E08 | `studio/lab/e08/v1/index.html` (10.2 KB) | The lethal trifecta, made visible | Three switches: private data, untrusted content, a way out; turn one off and the path closes. **Trifecta; exfiltration** | 48 s | none | Rendered. Very clear. |
| E09 | `studio/lab/e09/v1/index.html` (12.2 KB) | Mandate against grant | ABP's four objects: mandate (elicited), grant (measured, 16), delta (excess 12, shortfall 1), barrier per row. **Grant vs mandate; ABP in one picture** | 54 s | abp-examples, capabilities | Rendered; also verified blank from file://. |
| E10 | `studio/lab/e10/v1/index.html` (14.5 KB) | Four barriers / Only a boundary is a control | none / expectation / setting / boundary; Claude Code confirmations off: "One barrier moved, and not one number did." **"Allow all" / settings are not controls** | 52 s | abp-examples, capabilities | Rendered. |
| E11 | `studio/lab/e11/v1/index.html` (9.5 KB) | The kernel was told first | SHarness: policy hashed and given to the kernel before the tool starts; six probes held. **Enforced boundary (with a behaviour policy)** | 50 s | `harness.json` (20 KB) | Rendered. |
| E12 | `studio/lab/e12/v1/index.html` (17.7 KB) | The blast radius, contained | E02's rings with boundaries: today 12 of 12 unbounded, designed 8 of 12. **With vs without a behaviour policy; blast radius** | 52 s | abp-examples, capabilities, harness | Rendered. |
| E13 | `studio/lab/e13/v1/index.html` (13.1 KB) | Five published examples, one chart each | Small multiples of abp.sgit.ai examples (grant, mandate, excess, barrier). **Comparing agents' mandates** | 48 s | abp-examples, capabilities | Rendered; dense small text. |
| E14 | `studio/lab/e14/v1/index.html` (12.4 KB) | Earning autonomy | Licence to operate; levels 1-4 unlocked on evidence; "designed, not shipped" suspension. **Licence to operate; graduated autonomy** | 52 s | none | Rendered. |

Each E-piece has a prose companion "explainer" (frame-by-frame table, the one sentence) at `src/pages/ruv-sgit/<slug>/explainer.html` (built to `/ruv-sgit/<slug>/explainer.html`), e.g. `mandate-and-grant`, `blast-radius`, `four-barriers`, `lethal-trifecta`. These are site-template pages (need the build); their text is good material for in-app captions.

### SHarness series (`studio/lab/sharness/*/v1/`)

| Path | Title | Concept | Dur | Data dep |
|---|---|---|---|---|
| `one-idea/v1` | SHarness: the one idea | Harness enforces policy below the agent | 36 s | none |
| `os-of-one-process/v1` | the OS of one process | Process-level allow/deny (e.g. `403 PUT .sg_vault/key`) | 36 s | none |
| `components/v1` | what exists and what is coming | Roadmap | 50 s | harness.json |
| `live-demo/v1` | the live demo, stage by stage | Demo walkthrough | 54 s | harness.json |
| `kernel-in-a-tab/v1` | the kernel in a tab | Recorded animation of Linux-in-browser (no WASM loaded) | 40 s | none |
| `last-metre/v1` | the last metre | Gap between policy and agent | 34 s | none |
| `without-with/v2` | without and with, measured | Same wget four ways: no policy / allowlist / P1 / P5. **With vs without a behaviour policy** | 40 s | none (fetch match is prose) |
| `without-with/v1` | without and with | earlier | 46 s | harness.json |
| `moving-parts/v1` | the moving parts | Components | 40 s | none |
| `run-pipeline/v1` | the run pipeline | Pipeline | 40 s | none |

Only without-with v2 rendered/checked visually; others: structure scanned, render not verified. Product-specific (SHarness); lower priority for RiskMandate.

### B01 "the overlap" (the talk's opening/turn/close frames)

| Path | Title | Concept | Dur |
|---|---|---|---|
| `studio/lab/b01/v2/three/` | three problems, one overlap | Venn: the insider (agents) x infrastructure x decision (risk mgmt on spreadsheets) | 36 s |
| `studio/lab/b01/v2/opener/` | an act opens | act title card | 4 s |
| `studio/lab/b01/v2/collision/` | the collision | the three combined | 36 s |
| `studio/lab/b01/v2/way-out/` | the way out | four moves: measure reach, write down barriers, licence, earn autonomy | 15 s |
| `studio/lab/b01/v2/brakes/` | the close | "We put brakes in cars so that we can go faster." | 31 s |
| `studio/lab/b01/v1/{three,collision,way-out,brakes}/` | v1 stills | same, 1 s stills | 1 s |
| `studio/lab/b01/v{1,2}/index.html`, `storyboard/` | index pages | iframes of the above; link to a generated brief page | — |

All share `b01/v{1,2}/frames.js` (5 KB). v2/three rendered.

### Studio-ports (ported from ruv.sgit.ai, Apache-2.0)

| Path (`studio-ports/lab/…`) | Title | Shows / concept | Dur | Data dep | Notes |
|---|---|---|---|---|---|
| `policy-gate/` (15.5 KB) | The policy gate (studio v4) | POC1's 11 actions through Ruflo default (all allowed), then the same 11 through the ABP in enforce mode (4 denied, 2 sent to a human), hash-chained receipts. **With vs without a behaviour policy; human approval** | 36 s | `studio-ports/data/report.json` | `<canvas>`; rendered. Top candidate. |
| `journey/` (10.6 KB) | One action's journey | Three actions: request → ABP row → policy engine → receipt: allowed, denied, to a human | 34 s | abp.json, report.json, state-abp.json | Rendered. |
| `abp/` (13.8 KB) | What an Agent Behaviour Policy is | Coder's mandate card compiled into 36 rules; POC1's 11 actions with receipts | 26 s | abp.json, rules.json, report.json | Rendered. |
| `abp-review/` | The editor approves an agent's policy | Showcase (screenshot `shot.jpg` + crops + callouts + QR) | 16 s | none (shot.jpg) | showcase.js + qrcode.js |
| `abp-prose/` | An agent's behaviour policy, in prose and as policy.json | Showcase. **Mandate written twice** | — | shot.jpg | |
| `abp-enforcement/` | How a policy is held, wake by wake | Showcase | — | shot.jpg | |
| `pki/` | How the register of people works | Showcase of pki.sgit.ai | 15 s | shot.jpg | Rendered. Off-topic for agent risk. |
| `fork/`, `invest/`, `open-source/` | Fork next door / where to invest / open source strategy | Showcases of articles | — | shot.jpg | Off-topic (business). |

`studio-ports/data` is 80 KB (with .sha256 files). Each shot.jpg is 100-330 KB; studio-ports total 1.9 MB.

### Deck slides (`talk/slides/*/index.html`, 1.1-4.2 KB each, all engine, all `data` none, end 3-14 s)

| Slide | Title | Concept |
|---|---|---|
| `title/` | The ultimate insider | title (SVG) |
| `three/` | The perfect storm we are brewing | Venn of three problems |
| `definition/` | A threat is anything that causes business impact | Insider one human / two code / three agent. **Insider risk** |
| `loop/` | A reasoning engine in a loop, with tools | Agent loop + lethal trifecta (SVG) |
| `outages/` | It falls over on its own | AWS/Cloudflare outages |
| `building/` | They turned left. Agents turn right. | SolarWinds/Storm-0558 counts (text twin of M01) |
| `incidents/` | Five public incidents, three of them not attacks | EchoLeak, Replit, … |
| `identities/` | 82 machine identities for every human | NHI scale (counters/bars) |
| `permissions/` | The grant is everything the role accumulated | granted 100% vs used <5% / <2%. **Grant vs use; over-permission** (rendered) |
| `infrastructure/` | Built for code that stays where you put it | Recovery/identity/logging gaps |
| `integrity/` | Integrity: the original, changed | Agents change originals |
| `collision/` | The collision | three combined |
| `unreported/` | Why we do not see more of it | NASA ASRS near-miss reporting vs cyber. **Near misses** |
| `team/` | This team, as the example | Agent team with mandates |
| `spreadsheets/` | Risk management at the speed of spreadsheets | Risk register can't see reach |
| `way-out/` | The way out | Four moves |
| `abp/` | Reach, mandate, the gap, and what stands in it | **Grant/mandate/gap; 4 barrier kinds** (rendered) |
| `licence/` | A licence to operate, that can be suspended | Licence + autonomy L1-L5, SUSPENDED (rendered) |
| `demos/` | Live demos, all open source | list of demos |
| `brakes/` | Brakes are what let a car go fast | close |
| `maps/{inside,explorer,evolution,next-companies}/` + `maps/index.html` | Wardley maps | each wraps a 3.5-4.7 KB SVG; static |
| `live/{abp,sgit-demos,sharness-linux,sharness-playground,vault-risk-mandate,what-can-it-do}/` + `live/index.html` | Live slides | **iframe remote sites**: abp.sgit.ai, sgit.ai/demos, sharness.ai/code/browser/demo (Linux in tab), sharness.ai/code/playground, sgit.ai/demos/vaults/risk-mandate (opens a vault live), what-can-it-do.games.sgit.ai. **Not offline-capable**; would need those sites mirrored. |

### Hosts / engines

| Path | What | Interaction | Offline |
|---|---|---|---|
| `talk/player.html` (97 KB) | The talk player (ported from ruv.sgit.ai): 58 beats from `talk.json`, acts, presenter view (`P`), overview, review mode, build mode, notes, timer | Touch-ready: tap slide = next step, swipe = next slide, on-screen buttons for all keys; keyboard optional | Needs `talk.json` (has `window.TALK` fallback), optional build outputs; loads `pane.js` (network: vault append + openrouter.ai) and service worker. Rendered unbuilt (shows `{{version}}` placeholders). |
| `talk/engine/view.html` (21 KB) | "The viewer: one piece at a time": play/pause/replay, scrub bar with stops, speed, prev/next piece, `?src=` | Touch-friendly buttons | Needs `pieces.json` (build output) or `?src=`; loads `pane.js`. Good model for the app's per-piece screen. |
| `talk/talk.json` (in git) | The 58-beat running order with `say` script and `cue` per beat | — | Ideal source for the app's menu + captions. |
| `src/pages/index.html` (home) | Animated CSS Venn (agent/infra/risk), `@keyframes v1-v3` in `assets/site.css` | auto | Site template page; needs build. |

---

## Book repo

No animated or interactive visualisations. Inventory of reusable visuals:

| Item | Path | Served at | Tech | Concept | Offline |
|---|---|---|---|---|---|
| 28 infographics | `manuscript/resources/images/infographics/ig*.jpg` (5.6 MB; e.g. 3200x1400) | `/book/resources/images/infographics/…` | static JPG | ig08 accidental limits vs designed stand-ins (**insider**), ig09 one mandate written twice (ROLE.md vs policy.json), ig10 reach/mandate/gap, ig30 two brakes, ig32 barrier ladder (**only a boundary is a control**), ig35 one-way valve, ig14 five-step wake, ig12 key per session, … | Yes, copy files. Clean print style (light background), viewed. |
| 16 Wardley maps | `manuscript/resources/images/maps/*.png` | same tree | static PNG | 08 protection stack, 09 outside/inside, 11 two brakes, 12 controls on one map | Yes |
| 70 chapter images | `manuscript/resources/images/*.jpg` (~5 MB) | `/book/resources/images/…` | screenshots of the talk/site (e.g. 02-the-building.jpg, 03-abp.jpg, 03-mandate-and-boundary.jpg, 01-brakes.jpg) | Yes; but they are stills of the presentation pieces, which are better ported live. |
| "Whose work each chapter rests on" | `src/pages/review/read/graph.html` | `/review/read/graph.html` | inline SVG, hover `<title>` tooltips | book provenance, not agent risk | Needs site build |
| Page-by-page reader + reviewer's pen | `src/static/review/pages.js`, `pen.js` | review pages | plain JS, buttons/arrow keys, localStorage | n/a | low value |
| PDF lab | `lab/experiments/*` (77 folders), `lab/pdf/the-ultimate-insider-lab.pdf` (23 MB dir) | `/lab/` | Playwright/Chromium captures of talk animations into frames/long images (e.g. exp 01 M01 three frames, exp 02 M01 one long image `long.svg`, 20 locks that never closed, 21 mandate map, 27 ten controls, 66 two brakes) | print | static |
| Live vault board | `src/static/assets/board.js` + `vendor/vault-embed.js` | admin pages | decrypts a public vault in-browser with a published read key | team board, not a viz | **Vault read at runtime**; out of scope |

## UX repo

| Item | Path | Served at | Tech | Notes |
|---|---|---|---|---|
| Findings register (63) | `findings/UX-0NN.html`, `data/findings.json` | `/findings/…` | static HTML, `assets/findings.js` filter (3.7 KB) | UX failures of sgit.ai sites; not agent-risk |
| Newsroom Design Lab | `lab/index.html`, `lab/shots/` (2.5 MB), `data/lab.json` | `/lab/` | screenshots + published read keys/links to `dev.vault.sgraph.ai` (prototype vaults `m1m66ace`, `vdcj8hpl`, …). Content lives in vaults; page only links. | Not visualisations |
| Principles, method, reviews, exemplars | `principles/`, `method/`, `reviews/`, `exemplars/EX-001..002` | — | static | EX-001 is about Safari on iPad toolbars (possibly useful UX reference for the app) |

No canvas, keyframes, SVG animation, CDN scripts. 0 candidates.

## Cold-Read repo

| Item | Path | Served at | Tech | Interaction | Notes |
|---|---|---|---|---|---|
| The conductor's debrief deck | `src/static/debrief/index.html` + `deck.json` (11 KB, 16 slides) + `cold-read-debrief.pdf` | `/debrief/` | plain JS renders JSON slides (title, lead, table, points, cites), 16:9 card | prev/next buttons + arrow keys; no swipe | `fetch('deck.json')` (file:// blocker). Text only, about the cold-read process; not agent-risk viz. |
| Home Venn | `src/pages/index.html` + `assets/site.css` | `/` | CSS keyframes | auto | same as others |

---

## Deck/slide engines found

1. **Presentation slide engine** (`talk/engine/slide.js`/`slide.css`): one 1280x720 HTML file per slide, declarative `data-*` reveals + `SLIDE_RENDER`, virtual clock `RuvClock`, `RUV_STEPS`. Running order in `talk/talk.json` (`beats[]`: id, act, dur, title, slide.src, say, cue, sources, part). Hosts: `player.html`, `engine/view.html`. Showcase variant (`showcase.js`) = JSON in `<script id="showcase">` + `shot.jpg`.
2. **Cold-Read JSON deck** (`debrief/index.html` + `deck.json`, schema `cold-read.the-ultimate-insider/deck/v1`).
3. Book `review/static/pages.js`: shows/hides `[data-pg]` sections (a paged reader, not a slide engine).
4. Origin: the player and ports come from SGit-AI__Website__Ruv (ruv.sgit.ai) — not cloned, not verified; may hold more pieces (studio v1-v4 etc.).

---

## Offline bundle recipe (for the iOS app)

Copy, preserving relative paths, from `src/static/`:
- `talk/engine/slide.js`, `talk/engine/slide.css`, `assets/tokens.css` (13.5 KB total) — required by every piece.
- The chosen piece folders under `motion/lab/`, `studio/lab/`, `studio-ports/lab/`, `talk/slides/`.
- `studio/data/` (241 KB) and/or `studio-ports/data/` (49 KB) for data-driven pieces; `motion/lab/meet-the-team/v1/team-in-numbers.json`; `studio/lab/b01/v2/frames.js` for B01.
- For showcases also `talk/engine/showcase.js`, `showcase.css`, `qrcode.js` and each `shot.jpg`.
- Optional host: `talk/engine/view.html` (strip `assets/pane.js`) or a native SwiftUI menu driving `RuvClock`.
Everything above ≈ 3.2 MB for the entire set; ~0.6 MB for a top-15 selection with data.

Fixes:
- **fetch() under file://**: serve the bundle through a `WKURLSchemeHandler` (e.g. `app://viz/…`) so relative `fetch` works, or inline the JSON at build time (`<script>window.__DATA__=…`) and shim `fetch`. Verified that file:// breaks these pieces in Chrome; WKWebView behaviour not verified on device but the same restriction is expected.
- **Reduced Motion**: decide whether to honour it; slide.js freezes at end when it is on.
- **iPhone portrait**: lock the viewer to landscape or show "rotate" prompt; the 1280x720 canvas is unreadable at 390 pt wide.
- **Remove network code**: `assets/pane.js` (vault append + openrouter.ai), service worker registration in player, `talk/slides/live/*` iframes.
- **Build placeholders**: `{{version}}`/`{{root}}` in player/site pages; run the repo's stdlib Python build or substitute at bundle time.
- **No vault content is needed** for any animated piece: the "vault" words in M03/SHarness pieces are on-screen labels only. Vault reads exist only in book/presentation admin pages (`board.js`, `vault-embed.js`) and the remote `live/vault-risk-mandate` slide.
