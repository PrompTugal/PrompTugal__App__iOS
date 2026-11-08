# Visualisations, animations and demos: riskmandate.ai and PrompTugal.news

> riskmandate.ai's pages, animations and vault-backed demos, the PrompTugal.news visuals, and the deck format: what plays offline as is, and what needs the native vault reader.

Inventory for the RiskMandate iPad/iPhone app (offline playback in WKWebView or native rebuild).
Read on 2026-11-08. riskmandate.ai is site v1.40.3 (versions/index.json, latest release 2026-11-04).
News repo: PrompTugal/PrompTugal__News__Website at 9e46152 (2026-11-08 03:11 UTC), cloned to
/home/user/promptugal/promptugal__news__website. Downloaded copies of the riskmandate pages:
/tmp/claude-0/-home-user-PrompTugal--App--iOS/133e047f-9b0b-5b77-ad81-2e60e69c181f/scratchpad/rm/
(news pages: .../scratchpad/pt/).

Note: every riskmandate.ai page footer links https://github.com/Risk-Mandate/riskmandate.ai as its source. Not
cloned here (the brief says the repo was not found in this account); everything below is from the live site.

## 0. Facts that apply to every riskmandate.ai page

- Each page is ONE self-contained HTML file (40-280 KB): all CSS inline, all JS inline (a ~20 KB shared bundle:
  `RM` namespace, `<rm-menu>`, `nav.js`, `dom.js`, plus page-specific components). No `<script src>` and no
  stylesheet `<link>` except the homepage's `assets/anim/embed.css|js`.
- No CDN scripts, no Google Fonts, no analytics found. Fonts: the homepage self-hosts Geist / Geist Mono
  (`assets/fonts/geist-*.woff2`); other pages use system stacks (`--sans`, `--mono`).
- No d3, three.js, Cytoscape or canvas libraries. The keyword hits for "canvas"/"three"/"d3" were prose / CSS, not
  libraries. Diagrams are inline SVG (static or built by vanilla JS); animations are a small in-house slide engine.
- Every page has a `.md` twin (e.g. `demos.md`) and is listed in `llms.txt`; `.well-known/agent-content.json`
  holds concepts, pricing and a page list (40 KB, site metadata, no visual content).
- Navigation is `<a href>` relative links (v1.0.0+), so a mirrored folder works as a mini-site. Stories use
  root-absolute image paths (`/stories/images/...`) - these break under `file://` and need a rewrite or a custom
  URL scheme rooted at the bundle.
- Outbound links to store.sgit.ai, abp.sgit.ai, customers.riskmandate.ai, vendor docs: harmless offline but should
  be intercepted (WKNavigationDelegate -> SFSafariViewController or "needs network" note).

## 1. Vault-backed live demos (demos.html + demo-*.html)

`demos.html` (`<rm-vault-demos>`) shows all six; each `demo-*.html` is the same template (`<rm-vault-hero>`, ~75 KB)
for one vault. Mechanism (registry.js inside the page): an `<iframe sandbox="allow-scripts allow-same-origin
allow-popups allow-forms">` of `https://dev.vault.sgraph.ai/en-gb/app/?embed=1`; the parent sends the read key by
postMessage handshake (`vault-embed-ready` -> `vault-open {key, mode:'auto'}` -> `vault-ready {vaultName, fileCount,
hasApp}`). The vault's own app runs in the SG/Vault host. Offline: the frame never loads; status stays
"Connecting..." then "Not loading here? Open it in its own tab" after 20 s. **None of these run offline from the
page.** There is no static copy on riskmandate.ai (`vaults/risk-graph-explorer/` and `vaults/licence-to-operate/`
return 404).

All read keys are published IN THE PAGE SOURCE (the registry in every demo page and demos.html). They are NOT in
vaults/index.json (that file only covers the ABP vaults). Key formats: bare `<64hex>:<vid>` or `sgit_rk1_<64hex>:<vid>`.

| Demo | Page | Vault id | Key in page | Size / files | Concept | Notes |
|---|---|---|---|---|---|---|
| Licence to Operate | demo-licence-to-operate.html | posrhzp3 | bare `d990a52e...4da29:posrhzp3` | 13 MB, 121 files (loads on click) | grant vs mandate vs delta, as an insurance policy; change agent scope and watch uncovered delta move | "best" flag. Simulated policy over invented estate |
| RiskGraph Explorer | demo-risk-graph-explorer.html | 3simlnqe | `sgit_rk1_1c1b95f5...7e5638:3simlnqe` | not stated | answer -> fact -> risk -> role -> board; 7 views; presets typical/governed/exposed; no orphan risk | "best" flag |
| Agentic Browser Isolation | demo-agentic-browser-isolation.html | 0610gsp9 | `sgit_rk1_92cad4ce...04f6e:0610gsp9` | not stated | logged-in sessions vs isolated identity; 17 entry points; page per altitude IT->CISO->CFO->CEO->Board; acceptance-gated escalation, no deny | app requests no write capability |
| RiskMandate field demo | demo-risk-mandate-field.html | 4zf6pf2z | `sgit_rk1_a702fba8...5c0ae:4zf6pf2z` | not stated | 8 questions -> risk register, operator/CISO/board reading levels | "built to be handed to a stranger on an iPad"; page says it runs offline once loaded; AI-explanation feature uses an LLM via a key sealed in the vault (needs network; not verified how) |
| File security | demo-file-security.html | wu365g94 | `sgit_rk1_e8a1e664...1dc77:wu365g94` | 2.7 MB, 71 files | 11-step risk-acceptance walk, finding -> owned, expiring decision; no deny button | SQLite in the browser (presumably sql.js/wasm inside the vault; not verified) |
| Agent permission games | demo-agent-permission-games.html | 4evnlwrj | bare `f94c8b1d...8e111118:4evnlwrj` | 2.6 MB, 68 files | guess what an agent can reach (40 questions), scored; "what can it do" + mandates games | `phonesHome: true` - sends scores to a leaderboard (would fail offline; game itself not verified offline) |
| AIUC-1 conformance layer | (commented out) | 2wzct4k7 | NOT published (held: `sgit_private_read_` prefix) | 43 MB, 649 files | standard as graph, conformance computed | do not use until owner confirms |

**Native sgit reader route:** each has vault id + published read key, so the app's sgit reader can open them
directly. What is not verified: (a) what the vault app's entry file is and whether it needs the SG/Vault host's
`window.sg` bridge (the `vault-ready` message reports `hasApp`, so each vault carries an app); (b) whether the
apps fetch anything from other origins. Recommended path: pull the vault tree once (online, at build or first run),
store decrypted files in the app bundle/cache, serve them through a `WKURLSchemeHandler` and, if the app calls
`window.sg.vfs.readText`, inject a shim answering from the local files (riskmandate's own ABP pages already contain
such a shim: `SHIM` in `abp/abp-vaults.js`, a postMessage `readText` bridge - reusable as a template).

## 2. Agent Behaviour Policy vaults (agent-behaviour-policy.html, abp-vault-*.html, agent-behaviour-policy-next.html)

- `agent-behaviour-policy.html` (277 KB): the directory, `<rm-abp-library>` + `<rm-abp-mini>` tiles with four live
  counts per vault, 37 inline SVG logos.
- 16 `abp-vault-<slug>.html` pages (~176 KB each, 106 KB inline JS). Each reads its vault LIVE: derives the ref id
  from the read key with HMAC-SHA256, fetches ciphertext from `https://dev.send.sgraph.ai/api/vault/read/<vid>/<path>`
  (plain GETs, CORS), decrypts with WebCrypto AES-GCM, walks ref -> commit -> tree -> blob. Renders grant, mandate,
  delta, validity, history, capability/barrier/undo vocab, scenarios. Also mounts the vault's own app in a
  `srcdoc` sandboxed frame (`<rm-abp-app>`, served reads over postMessage) and an optional embed of the official
  vault UI from `dev.vault.sgraph.ai` (`<rm-abp-host>`).
- **Offline fallback exists:** if the vault cannot be reached the page fetches the plaintext snapshot served from
  `vaults/<slug>/` on riskmandate.ai and says so in its status chip. Snapshot paths (verified for claude-code-web):
  `vault.json`, `data/grant.json`, `data/mandate.json`, `data/delta.json`, `data/validity.json`, `history/index.json`,
  `data/vocabulary/{capabilities,barriers,undo-classes,evidence-tiers}.json`, optional `data/scenarios.json`,
  `index.html` (a 7 KB loader). The renderer is `vaults/_app/index.html` (80 KB, one file, "nothing external",
  reads via `window.sg` or same-origin fetch). The live-only parts (`<rm-abp-app>` "runs from the live vault
  only", `<rm-abp-host>`) do not work offline.
- Concepts: grant vs mandate, the gap/delta, barriers (setting vs boundary), confirmations on vs off ("one setting
  moves one barrier and not one number changes"), OAuth connectors vs MCP servers vs local CLI, irreversibility (undo
  classes), evidence tiers.
- Keys: published in BOTH `vaults/index.json` (key field, 64 hex; full key = `<key>:<vid>`) and inline in every
  abp-vault page. App vault (the renderer): `vbhmlulo`, key `ae52f01b...82b84caf`, entry `index.html`, v5 (old v4 app
  vault `fl3i7lu4` still serves vaults not re-pushed). Endpoint: `https://dev.send.sgraph.ai`.

| slug | vault id | application |
|---|---|---|
| claude-code-web | ruj286tr | Claude Code on the web |
| claude-code-cli | amicdz0h | Claude Code on your machine (confirmations on) |
| claude-code-cli-confirmations-off | ahly2cho | Claude Code, confirmations off ("allow all") |
| claude-desktop | ty3axtmo | Claude Desktop, local tools |
| claude-web-connectors | wkm5owfl | Claude in the browser, connectors on |
| chatgpt-web | dd1teu9n | ChatGPT in the browser (baseline, no excess) |
| browser-extension | exsaxrfr | Browser extension, broad host permissions |
| github-actions | 0hpdpj80 | GitHub Actions runner |
| scheduled-job | kd7zeimj | Scheduled job under a service account |
| google-workspace-mcp | pq7ct02p | Google Workspace MCP servers |
| claude-gmail-connector | oc433z3m | Claude's Gmail connector (measured) |
| gmail-readonly | l2zlv3ng | Gmail, read-only scope |
| google-drive-readonly | vz03p8it | Google Drive, read-only scope |
| claude-m365-connector | dgx3nvu4 | Microsoft 365 connector |
| dropbox-mcp | 9eqa7e4p | Dropbox MCP server |
| n8n-owner-api-key | l8opgcug | n8n, owner API key (measured) |

**Native sgit reader:** yes - vid + key from vaults/index.json is exactly what it needs. Simplest offline port:
mirror `vaults/<slug>/` snapshots + `vaults/_app/index.html` (all plaintext JSON, small: grant.json 10.6 KB,
history 0.4 KB) and serve them under one origin; or render the JSON natively (grant/mandate/delta lists are a good
native SwiftUI candidate). The full per-vault file list is not verified (the live page lists the vault tree).
`agent-behaviour-policy-next.html` (179 KB) is the request queue (asked_for + functions in vaults/index.json):
text cards and a contact form, low visual value.

## 3. Self-contained interactive pages (run offline as single files)

| # | Page | Title / element | What it shows, concept | Tech | Offline | Touch | Size |
|---|---|---|---|---|---|---|---|
| A | article-who-owns-what-in-ai.html | Risk propagation visualiser (3 figures; Figure A "the blast radius") | One sales rep connects an assistant to mail/CRM/calendar: 9 capabilities, 4 asked for; the other 5 become risks that travel up an org chart of roles to the board; connect/disconnect, add a control, red travels up, green replaces it; plus a six-week timeline. Blast radius, grant vs mandate, insider risk, role ownership | vanilla JS building SVG, requestAnimationFrame; "nothing is loaded from anywhere, nothing is sent" | yes, single file | click-driven, has touch handling (keyword present; not tested on device) | 177 KB (53 KB script) |
| B | grant-gap.html | `<rm-risk-queue>` "interactive hero terminal" | A queue of agent risks (e.g. "Payments agent production access": owner, blast radius $1.4M/quarter, expiry 29 days); accept / ask-for-info transitions; "no third door" (no deny) | vanilla JS (pure core + component), CSS terminal | yes | buttons | 74 KB |
| C | scenarios.html | `<rm-scenarios>` + `<rm-scenarios-record>` "How long will you accept this risk?" | 10 branching cards (OAuth token, company card, customers' passwords, every email, calendar, private messages, all repos, production DB, unlocked laptop, one customer reaching another); 4 beats hook -> escape hatch -> reveal -> interval; your taps stamp a timestamped acceptance record | vanilla JS, data inlined | yes, nothing stored or sent | tap-first design | 59 KB |
| D | statics.html | `<rm-statics>` | Same scenario bank laid out as 600x750 artboards for LinkedIn posts; "clean view" | vanilla JS | yes | buttons | 53 KB |
| E | ramm.html | `<rm-ramm-pyramid>` | RAMM maturity level COMPUTED from edges on a RiskAcceptanceDecision node; toggle edges / presets / agentic overlay, level recomputes | vanilla JS, in-memory | yes (the `<rm-ramm-figure>` infographic `assets/ramm/ramm-model.webp` is 404 live, so it stays hidden) | buttons | 72 KB |
| F | insurance.html | `<rm-index-card>` (score counts up), `<rm-index-ladder>` (6 levels L0 Unmapped -> Underwritten) | Insurability Index, 5 weighted dimensions | vanilla JS, rAF count-up | yes | buttons | 77 KB |
| G | rules/index.html + 24 rules/*.html + rules/method.html | "Do you want your agent to ...?" | One rule per capability (start other agents, change its own permissions, read other sessions, touch your secrets, send as you, run anything, spend money...): the one line to paste, expectation vs setting vs boundary, row across 3 published ABPs with barrier, and "Before and after" (same request without/with the line; run on 4 of 24, e.g. read-other-sessions, others say "Not run yet") | static HTML + copy buttons | yes | fine | 52-79 KB each |
| H | index.html | Homepage SVGs + E11 animation | SVG: agent at centre, green ring of 6 authorised capabilities, dashed reach boundary with 9 more in the gap (grant vs mandate / reach); SVG: ABP -> PBP -> launcher -> kernel with five doors; `<figure class="anim">` E11 | inline SVG, iframe slide | yes if `assets/anim/**` copied | Replay button | 161 KB + anim |
| I | owasp-graph.html | "OWASP, as a graph" | OWASP projects -> documents -> items, 5 zoom levels, Agentic Top 10 joined to the register | static HTML/CSS grid + `<details>`; not a drawn graph; data `business-case/owasp/graph.json` (48 KB) linked | yes | fine | 119 KB |
| J | how-it-works.html, abp.html, licence-to-operate.html, lab*.html | Explainers | Six steps prompt -> graph with provenance; four ABP objects; licence = authority/instrument/licensee; Lab 01-07 findings (connector grants user-shaped, network reach, commit author, shape collector) | static HTML, few/no figures | yes | fine | 43-115 KB |

## 4. Animations (homepage + secure-harness.html)

Self-hosted under `assets/anim/` (README: copied 2026-11-03 from the-ultimate-insider.presentation.sgit.ai; CC BY 4.0
Dinis Cruz; engine Apache-2.0). Each is a 1280x720 slide on `assets/anim/talk/engine/slide.js` (9 KB) +
`slide.css` (2 KB, `@import ../../assets/tokens.css` = `assets/anim/assets/tokens.css`, 2.4 KB). Player:
`assets/anim/embed.js` (2.5 KB) plays on scroll-into-view, Replay, chapter buttons; postMessage `{slide:'seek'|'play'
|'pause'}`; `window.RUV_STEPS` gives named stops; `?ruvpaused`, `?t=`, `?static`, `?theme=light` params.

| Piece | Path | Steps | Data fetched | Concept |
|---|---|---|---|---|
| E09 mandate against grant | assets/anim/studio/lab/e09/v1/index.html (12 KB) | the ABP, mandate, grant, gap, barrier, chat example | `studio/data/abp-examples.json` (37 KB), `capabilities.json` (20 KB) | grant vs mandate, the gap |
| Policy gate (Ruflo default vs ABP enforce) | assets/anim/studio-ports/lab/policy-gate/index.html (16 KB) | - | `studio-ports/data/report.json` (2.7 KB) | with/without a behaviour policy: 11 actions, 4 denied, 2 held |
| E11 the kernel was told first | assets/anim/studio/lab/e11/v1/index.html (10 KB) | excess row, write/hash/enforce, six probes, six of six held, designed | `studio/data/harness.json` (20 KB) | boundary enforcement |
| E12 blast radius contained | assets/anim/studio/lab/e12/v1/index.html (18 KB) | 12 of 12 lit, measured in a child, walls close, what stays lit, boundary for the child | abp-examples, capabilities, harness | blast radius, child processes (agents spawning) |

Offline: yes, total ~150 KB. Blocker: the slides use `fetch()` of relative JSON, which fails under `file://` in
WKWebView -> serve via `WKURLSchemeHandler` (or inline the JSON). Copy the whole `assets/anim/` subtree keeping
relative paths. Touch: no pointer handlers in the engine; playback is automatic, controls are buttons in the host page.

## 5. Stories (stories/)

- `stories/index.html` (85 KB): cast + storyboards. `cast.json` (4.9 KB): 9 characters (Maya the requester, Rowan,
  Imani, Dev, Ruth, Leo, The Caretaker agent, The Boundary...) with `stands_for`, `look`; drawn sheet
  `images/meet-the-cast.webp` (1086x1448, 280 KB). `board.json` (8.7 KB): the production kanban of the agents that
  make the stories (requested/open/blocked/done) - process data, not reader content.
- Story pages (62-88 KB): an-approval-prompt ("Always allow"), an-edited-meeting-does-not-come-back, just-a-draft,
  just-a-little-research, silence-goes-up, the-pilot-worked, the-short-answer (10-scene film outline), the-ultimate-insider
  (2 panels), while-i-was-there. Drawn panels (webp, 225-311 KB each): just-a-draft, just-a-little-research,
  the-ultimate-insider-1/-2, while-i-was-there, meet-the-cast (~1.6 MB total). Other stories are text storyboards.
- Concepts: "allow all"/approval prompts, excess reach, insider risk, silence as escalation, pilots growing scope.
- Offline: yes; rewrite `/stories/images/` root-absolute paths. Native: good candidate for a paged comic viewer.
- `article-risk-propagation-visualiser.html` (93 KB): guide to item 3A with 34 screenshots under
  `assets/articles/risk-propagation/*.webp` (sizes not measured).

## 6. PrompTugal.news (repo + live)

Site is built by `node newsroom/build/build.mjs` (no deps); output not committed - live pages at promptugal.news.
Pages share a heavy shell (~15 CSS + ~8 JS: chat, login, meter, search, tool API) that is not needed for the visuals.
The site already has an offline service worker (`/sw.js`, `assets/offline/`), which WKWebView ignores for file URLs.

| Item | URL / source | What | Tech | Data | Offline |
|---|---|---|---|---|---|
| RiskMandate's ring | /graph/riskmandate/ ; assets/graph/riskmandate.js (6 KB) ; content/graph/riskmandate.md | reach / mandate / gap at the centre, every summit company on an outer ring by field; tap a company; Replay; Save PNG; explicitly no relationships | plain canvas, no deps | api/v1/graph/explorer.json (906 KB) | yes with the JSON; strings in `data-ui` JSON from the md front matter |
| Graph explorer | /graph/ ; assets/graph/explorer.js + engine.js | whole newsroom knowledge graph, presets, focus, path queries | Cytoscape.js 3.30.2 vendored (assets/vendor/cytoscape, 373 KB) | explorer.json + industry/people/summit/whole.json, ontology.json | yes, big; summit-company content, not agent-risk |
| Gravity / industry / world / past summits / cloud centres | /graph/gravity/ etc.; assets/graph/*.js (5-9 KB each) | companies orbiting fields, radial industry tree, world bubbles, attendance bars | plain canvas | explorer.json, world.json, vendor/world-atlas, past-summits.json, cloud-centres.json | yes; low relevance to agent risk |
| Agents live map | /newsroom/live/ ; assets/newsroom/live.js (27 KB) ; build feature agents-live.mjs | hexagon of hubs (people/agents), a line per exchange travelling at its real moment, from git commit trailers - agents talking to agents | plain canvas, rAF | api/v1/newsroom/live.json (133 KB) + live-details.json (1.35 MB, on tap) | yes with a snapshot; "live" follows wall clock minus a few minutes and polls every 60 s, so offline needs a replay/time mode (phase-2 time controls mentioned; not verified) |
| Newsroom agents views | /newsroom/ (agents, runs, timeline swim lanes) ; newsroom-draw.mjs | text pictures (64 cols) and SVG charts drawn at build, no script | static SVG | built in | yes as static HTML |

### The deck format (investor decks)

- Source: `board/team/investors/decks/` - `src/<deck>.tpl` (HTML layout, `.deck > .slide` sections, each slide a
  1920x1080 box; text elements empty with `data-i18n="<key>"`), `i18n/<deck>/<lang>.json` (en, pt, es, fr; values may
  hold inline HTML), `deck.css` (12 KB, @font-face to `../../../../assets/fonts/` Newsreader + IBM Plex, 284 KB),
  `deck.js` (9 KB player, identical copy in board/team/dev/decks), `img/` (2.7 MB), `shots/` (11 MB screenshots),
  PDFs per deck per language (1.5-2.2 MB each, real files, 40 total). `tools/decks.mjs build <deck> <lang>` merges
  template + words into HTML.
- Ten decks: 0-the-map (14 slides), 1-the-investment-case (15), 2-the-industry (16), 3-the-platform (18), 4-the-algarve
  (15), 5-the-investment (16), 6-the-technology (16; "Twenty agents for every person, and every one in its lane" -
  most agent content, 97 mentions), 7-join-us (14), 8-do-it-yourself (18), 9-the-tour (17; the only one with CSS
  keyframe animations triggered by `.slide.active`).
- Served: `/investors/decks/<name>/` (en) and `/<name>/<lang>/`, with `api/v1/decks/deck.css|js` (byte-identical to
  repo), images from `board/team/investors/decks/img|shots/` (relative `../../../board/...`), plus
  `api/v1/investors/persona.js` (decrypts personalised versions from `#pk=` links; not needed offline).
- Player: `#deck-player[data-player]` JSON (`name, lang, langs{}, decks[{name,href}], index, pdf`) turns on present mode
  with a toolbar; without it, all slides stack (so a built HTML opened as a file stacks). Keys, tap right/left half,
  swipe (40 px), `#N` deep link, `F` full screen (Fullscreen API not available in iOS WKWebView for documents -
  hide that button), `S` stack.
- Offline on iPad: (1) simplest: bundle the PDFs and show with PDFKit (one slide per page, fidelity verified by
  their Playwright render, 60 MB for all 40). (2) interactive/animated: run `decks.mjs build` per deck/lang at app-build
  time, keep deck.css/deck.js/img/shots/fonts at the same relative layout, inject a `data-player` mount (or a native
  toolbar driving `location.hash`), load via a scheme handler. ~14 MB of images shared by all decks.

## 7. Common offline blockers and fixes

1. Live vault reads (dev.vault.sgraph.ai embed, dev.send.sgraph.ai API): pre-fetch with the native sgit reader
   (vid + published key) or use riskmandate's plaintext `vaults/<slug>/` snapshots; provide a `window.sg` shim.
2. `fetch()` of local JSON under `file://` (anim slides, news graphs, ABP snapshot fallback): serve the bundle through
   a `WKURLSchemeHandler` (e.g. `rmapp://riskmandate.ai/...`), which also keeps same-origin postMessage checks working
   (embed.js posts to `location.origin`).
3. Root-absolute paths (`/stories/images/...`): the scheme handler with the bundle as root fixes it; else rewrite.
4. Sandboxed iframes / srcdoc with postMessage: works in WKWebView; origin checks compare to
   `https://dev.vault.sgraph.ai`, so a local port must adjust or replace that code.
5. External links (store, abp.sgit.ai, contact forms, leaderboard of permission games, field demo's LLM explain):
   intercept and show "needs a connection".
6. Fullscreen API buttons (deck player, anim "Full screen" links open new tabs): hide or route natively.
7. Shared nav (`<rm-menu>`) links to ~100 site pages: either mirror the whole site (pages are small) or strip the menu
   and use the app's own switcher.

## 8. Top 10 for the app (impact x ease of offline porting)

1. Risk propagation visualiser (article-who-owns-what-in-ai.html, 177 KB, one file): blast radius up the org chart. Copy the file as-is.
2. The four animations (assets/anim/, ~150 KB): E09 grant vs mandate, policy gate with/without ABP, E11, E12 blast radius. Copy the subtree; needs a scheme handler for fetch().
3. scenarios.html "How long will you accept this risk?" (59 KB): 10 tap-through cards with an acceptance record. Copy as-is.
4. ABP vault pages, from snapshots (16 vaults): grant/mandate/delta per real product (Claude Code confirmations on/off, connectors, MCP, OAuth read-only). Mirror vaults/<slug>/ + vaults/_app/index.html, or open with the native sgit reader; consider a native SwiftUI view of the JSON.
5. grant-gap.html risk-queue terminal (74 KB): accept / ask, no deny. Copy as-is.
6. Homepage reach-vs-mandate SVG + E11 (index.html): copy page + assets/anim + assets/fonts/geist-*.
7. RiskGraph Explorer (vault 3simlnqe) and the field demo (vault 4zf6pf2z): highest-impact demos, but they only work after a native sgit pull of the vault and a window.sg check (not verified).
8. Stories with drawn panels and cast (~1.6 MB of webp + 9 pages): native paged viewer or the pages with path rewrite.
9. ramm.html maturity pyramid (72 KB) and insurance.html ladder (77 KB): copy as-is.
10. rules/ (26 pages, ~1.5 MB): "Do you want your agent to...?" with before/after on 4 rules; copy as-is or render natively from the .md twins.
Decks (news site): bundle the PDFs first; HTML player second (section 6).
