# App-first: what moves from the websites to the three apps

> Now that a change reaches the team's iPhones and iPads through TestFlight in about 20–30 minutes, the apps become a real place to deploy to. This pack maps every website section to the app it belongs in (PrompTugal, Team or RiskMandate), sets the rule for what stays on the web, and designs the offline data flow: sites publish data, apps download it, verify it and render it locally.

**Pack date:** 8 November 2026 · **Author:** conductor@ios.PrompTugal.dinis · **Status:** first draft, for discussion with Dinis

## The idea in five lines

1. **The websites become publishers; the apps become where people use them.** Every site already turns its content into data files. The apps download those files, keep them, and draw native screens from them.
2. **Content moves at website speed, capability at app speed.** A new story, session or agent policy is a data change, so it appears in the app on the next sync, with no new build. A new kind of screen needs a TestFlight build, which now takes about 20–30 minutes.
3. **Offline first.** Each app starts from data it already has (packed into the build, then refreshed), works on the venue's poor Wi-Fi, and syncs only what changed.
4. **The iPad is the professional surface; the iPhone is the pocket.** The iPad gets dashboards, the graph, decks and demos. The iPhone gets what's next, reminders, messages, quick capture and stats at a glance.
5. **The web stays for what only the web does well:** public links, search engines, agents reading llms.txt, payments, sign-in and long-tail pages. Some pages become app-first, with the web version linking into the app.

## What the websites hold today (counted from their sitemaps on 8 Nov)

| Site | Pages | Main sections (page count) | Data feed |
| --- | --- | --- | --- |
| promptugal.news | 1,403 | people 272 · organisations 251 · events 246 · investors 184 (decks 41, pt/fr/es 36 each) · newsroom 134 · companies 121 · places 84 · articles 39 · topics 18 · brief 11 · graph 9 · days 8 · account 5 · my-day · offline · ask · search | **`api/v1/manifest.json`: 2,330 files, 20.1 MB, each with a SHA-256.** Graph 11.5 MB, newsroom 2.0 MB, search index 1.3 MB, events 1.0 MB, companies 0.8 MB |
| web-summit.sgit.ai (team) | 703 | meetings 188 · companies 111 · abp 90 · reports 65 · people 63 · xray 42 · team 22 · investors 15 · videos 10 · observability(-pack) 17 · meet 8 · pki 7 · stickers 5 · plan, print, procurement, crm, comms-protocol, keys, vaults, inbox, command-centre, pulse, board-health, briefs for each person | `me.json` (38 KB), `people/<id>/app/data.json`; **no manifest** |
| riskmandate.ai | 164 | rules 26 · business cases 21 · abp-vault policies 16 · stories 10 · owasp 8 · articles 8 · labs 7 · demos 6 · paid tiers 4 · for-startups/founders/corporate · how-it-works · insurance · licence-to-operate · summit-booth · try-it | `.well-known/agent-content.json` (40 KB), `versions/index.json`, `vaults/index.json`, `stories/board.json` and `cast.json`, `team/*.json` |

The app today has 30 screens: 17 native, 3 hybrid, 10 web pages (the team site's command centre, wakes, reports, pulse and board health; observability (web); the two website shortcuts).

## The map

```
                         WEBSITES  (publish: pages + JSON + manifest)
   ┌───────────────────────┬──────────────────────────┬──────────────────────────┐
   │ promptugal.news       │ web-summit.sgit.ai       │ riskmandate.ai           │
   │ 1,403 pages · 20 MB   │ 703 pages · team data    │ 164 pages · ABPs, demos  │
   └──────────┬────────────┴────────────┬─────────────┴────────────┬─────────────┘
              │ manifest delta sync     │ manifest (to add)        │ manifest (to add)
              ▼                         ▼                          ▼
   ┌───────────────────────┐ ┌──────────────────────────┐ ┌──────────────────────────┐
   │ PROMPTUGAL  (public)  │ │ TEAM  (internal)         │ │ RISKMANDATE  (demos)     │
   │ news.promptugal.reader│ │ news.promptugal.team     │ │ ai.riskmandate.app       │
   ├───────────────────────┤ ├──────────────────────────┤ ├──────────────────────────┤
   │ NATIVE NOW            │ │ NATIVE NOW               │ │ NATIVE NOW               │
   │ agenda · my day       │ │ team home · people       │ │ (empty app)              │
   │ planner · reminders   │ │ messages (lanes)         │ │                          │
   │ news · graph · ask    │ │ where is everyone · wall │ │                          │
   │ vault · widget · Siri │ │ agents · briefed · obs.  │ │                          │
   ├───────────────────────┤ ├──────────────────────────┤ ├──────────────────────────┤
   │ MOVE TO NATIVE NEXT   │ │ MOVE TO NATIVE NEXT      │ │ MOVE TO NATIVE NEXT      │
   │ ★ decks / presenter   │ │ ★ stand-ups (meetings)   │ │ ★ ABP explorer: our 100+ │
   │   (investors 41 + 3   │ │ ★ command centre (today  │ │   agents' policies       │
   │   languages)          │ │   a web page)            │ │   (team site abp/ 90)    │
   │ ★ offline search      │ │ ★ reports · wakes ·      │ │ ★ demos (6) and labs (7) │
   │   (index already      │ │   pulse · board health   │ │   as native interactive  │
   │   published)          │ │ ★ logistics: plan, print │ │ ★ rules (26) · OWASP (8) │
   │ events · people ·     │ │   order, stickers, cards,│ │   + risk graph (reuses   │
   │ orgs · companies ·    │ │   nights, procurement    │ │   the news graph engine) │
   │ places (venue map)    │ │ ★ CRM: companies 111 ·   │ │ stories (10) · articles  │
   │ stories · articles ·  │ │   xray 42 · investors 15 │ │ business cases (21)      │
   │ the brief · newsletter│ │ observability (17 pages) │ │ ★ booth mode: iPad on a  │
   │ topics · days         │ │ personal briefs · inbox  │ │   stand, attract loop,   │
   │                       │ │ keys · pki · vaults      │ │   guided demo, videos    │
   ├───────────────────────┤ ├──────────────────────────┤ ├──────────────────────────┤
   │ STAYS ON THE WEB      │ │ STAYS ON THE WEB         │ │ STAYS ON THE WEB         │
   │ account · billing ·   │ │ admin · site review ·    │ │ pricing · paid tiers ·   │
   │ sign-in · how we      │ │ design · onboarding      │ │ early access · legal ·   │
   │ publish · newsroom    │ │ guide (link from app)    │ │ contact forms            │
   │ long tail · SEO pages │ │                          │ │                          │
   └───────────────────────┘ └──────────────────────────┘ └──────────────────────────┘
        iPhone: now/next, picks,      iPhone: messages, check-ins,   iPhone: share a demo,
        reminders, widget, Siri       capture notes, alerts, stats   ABP lookup
        iPad:   decks, graph, news    iPad:   wall, dashboards,      iPad:   booth, demos,
                desk, search                  stand-ups, CRM                 graph, videos
   ─────────────────────────────────────────────────────────────────────────────────────
   SHARED PACKAGES:  PTCore · PTWeb · PTAgenda · PTNews · PTAsk · PTLanes · PTVaultUI
                     + new: PTSync (manifest sync)  · PTDeck (presenter)  · PTGraph
   PRIVATE DATA:     sgit vaults (keys, picks, notes, team plans) · Keychain behind Face ID
```

★ = highest value for the summit week.

## Offline: download, verify, render locally

```
   site build ──► api/v1/manifest.json  { path, bytes, sha256 }  ×2,330
                         │
   app launch / background refresh / pull-to-refresh
                         │
                         ▼
        PTSync: fetch manifest (small) ──► diff against the local store
                         │
              changed files only, in priority order
              (core pack first, then full, media only on Wi-Fi)
                         │
                         ▼
        verify SHA-256 ──► write to a new generation ──► atomic switch
                         │                                (a half-done sync never shows)
                         ▼
        native screens read the local store, always; show "synced 3 min ago"
```

- **Packs.**
  - **core**, always: agenda, days, people and story indexes, newsletter, the team's me.json and my command centre. About 1–2 MB.
  - **full**, on Wi-Fi or by choice: graph, entity pages, search index, newsroom. About 20 MB.
  - **media**, opt-in: deck images and videos.
- **A seed in every build.** CI downloads the core pack (and, for PrompTugal, full) when it builds, and puts it inside the app. The first launch at the venue works with no network at all.
- **Hashes give integrity for free.** A file whose hash doesn't match the manifest is refused and fetched again.
- **Writes queue offline.** Messages, notes to the newsroom, picks and check-ins go into an outbox and are sent when the network is back. Lanes are append-only, so retries are safe.
- **To add on the sites:** a `manifest.json` in the same format on web-summit.sgit.ai and riskmandate.ai. PrompTugal already has one, and riskmandate.ai's `agent-content.json` is close.
- **Private data never goes in a public manifest.** It stays in sgit vaults, encrypted, which the apps already read and write.
- **Later:** device-to-device sync between teammates over Bluetooth or local Wi-Fi when the venue network fails.

## What the web keeps, and what exists to serve the apps

- **Keeps:** public links people share, search engines, llms.txt and the page API for agents, payments and Stripe, sign-in, and long-tail pages nobody needs offline.
- **Exists to serve the apps:** `api/v1/*` and the manifest (already there), deck data (slides as JSON plus images instead of deck.js), the packs, and the team and RiskMandate manifests.
- **App-first pages:** where the app is better (decks, the graph, the agenda), the web page stays but shows "Open in the app" through universal links. That needs the AASA file on each domain, the step we removed for now.

## Releases: two speeds

| Change | Path | Time to devices |
| --- | --- | --- |
| Content: a story, session, deck slide, agent policy, team report | site build, then manifest, then app sync | minutes (next sync) |
| Capability: a new screen or native feature | merge to dev, CI, TestFlight internal group | about 20–30 min |
| Public release (after the summit) | tag, then external TestFlight or the App Store review | about a day |

The Macs: the TestFlight groups have "Test iPhone and iPad apps on Apple Silicon Macs" switched on, so the team's M-series Macs and a Mac mini can install the same apps from TestFlight and run them natively. The simulator is only for development.

## Proposed order of work (after the split lands)

1. **PTSync**: manifest delta sync, packs and the build seed, first in PrompTugal against the existing manifest.
2. **Decks and presenter mode** in PrompTugal: the investor decks in 4 languages, readable offline, presented from an iPad, with an external-display view.
3. **Team: stand-ups, command centre, reports and pulse native**, plus a manifest on web-summit.sgit.ai.
4. **RiskMandate: ABP explorer and booth mode**, plus a manifest on riskmandate.ai.
5. **Offline search** in PrompTugal, using the published index.
6. **Logistics and CRM** in Team.

## Questions for Dinis

1. **Decks:** which ones first? The investor decks (41 pages, in pt/fr/es too), or also the team's and RiskMandate's?
2. **Booth:** will the RiskMandate iPad stand unattended at a booth? If so, use Guided Access with an attract loop.
3. **Team data on the iPhone:** which stats matter at a glance? These could become widgets, or Live Activities for builds and stand-ups.
4. **Team site manifest:** should the team site's builder publish one tonight, or after the summit?
