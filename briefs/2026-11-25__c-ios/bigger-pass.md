# The bigger pass: what the *.promptugal.news sites offer the app (c.ios, 25 Nov 2026)

> From a read of the 13 public sites on 25 Nov ~22:20 UTC (Sonnet survey; raw files were in the session's scratchpad). Plan only: nothing started.

## What the sites publish

| Site | What | Best endpoint(s) | Freshness (25 Nov) | Per place |
| --- | --- | --- | --- | --- |
| promptugal.news | the newsroom: 96 articles, 136 stories, 115 companies, 34 events, 36 places | `/api/v1/by-place/index.json`, `/api/v1/by-place/{id}.json`, `/api/v1/since.json`, `/api/v1/articles.json`, `/feed.xml` | built 25 Nov; newest article 24 Nov; by-place 21 Nov | 36 (Portugal, Algarve, 17 towns, 17 district capitals) |
| newsroom | agents, asks, handoffs, schedule | `/api/v1/newsroom/dashboard.json` (834 KB), `/api/v1/newsroom/status.json` (the app's `status.json` URL 404s) | 25 Nov 18:46, fresh | by agent |
| data | 30 public collectors (IPMA, events, contracts, adsb, cams, social, cyber) | `/api/v1/index.json`, `/api/v1/by-place/now/{id}.json`, `/api/v1/events/by-place/{id}.json`, `/api/v1/<source>/latest.json`, `/api/v1/openapi.json` | **read 21 Nov: collectors look stopped** | 20 |
| weather | IPMA warnings, forecasts, fire, sea, UV | via data.* | 21 Nov | 34 |
| events | 593 official events + 91 more | data `/api/v1/events-pt/latest.json`, `/events/by-place/{id}.json` | 21 Nov | Lisboa, Lagos, Faro, Tavira well covered |
| civic | 16 Algarve councils: procurement, notices, services | `civic…/api/v1/councils.json`, `/councils/{id}.json`, `/use-cases/notices.json` | 21 Nov | 16 councils |
| bulletins | teletext-style bulletins, every fact sourced | `bulletins…/api/v1/bulletins/{100..400}.json` | 21 Nov | by region |
| live | 913 public cameras (metadata, operator links) | `live…/api/v1/places/index.json`, `/api/v1/cameras.json` (2.4 MB) | 21 Nov | 20 |
| videos | 32 videos (summit replays and more) | `videos…/api/v1/videos/index.json` | 18 Nov | no |
| library | 82 talks, replays, articles | `library…/api/v1/items/index.json`, `/index/place.json` | 21 Nov | index by place |
| cyber | weekly CVE pulse | `cyber…/api/v1/pulse/index.json` | 21 Nov | no |
| signals | 146 public posts by organisations | data `/api/v1/social/latest.json` | 21 Nov | mostly empty |
| startups, travel | pages only, no JSON | `llms.txt`, `index.md` | 19 to 21 Nov | in pages |

Every feed carries source URLs (good for the "every story links to its source" rule). The data layer's `read_at` stamps stop at 21 Nov, so those screens must say "snapshot, read 21 Nov", not "live", until the collectors run again. That is for the team Dinis is wiring back up.

## Proposed workstreams (one owner per path, work/* branches, one candidate run per batch)

1. **Home: "Since you last looked"** from `since.json` (151 items, 45 days, place, kind, source). The best single feed for the app's front page. Owner: PTPlaces / shell.
2. **Town page, richer**: latest from `by-place/{id}.json` (ai_news with publisher and source), events from data `events/by-place/{id}.json`, council notices from civic, a camera link from live. Each block with its own provenance line. Owner: PTPlaces with PTLocal layers.
3. **District capitals as first-class places** (17 now, the app shows 7).
4. **Explore rebuilt for the news** (summit speakers and companies → the newsroom's 115 companies, 136 stories, library items, videos), replacing the summit index.
5. **Newsroom board fix**: point the status feed at `/api/v1/newsroom/status.json`; it is fresh and the live board's runs ledger has been empty since 5 Nov.
6. **Data honesty**: a freshness badge driven by each feed's `read_at`, so stale data says so automatically.
7. **App Store pass**: screenshots (screens.yml destinations), owner-only unlock for comments and talk, IAP products when Dinis creates them.

## Recommendation

Do 5 and 6 first (small, they fix what the app claims), then 1 and 2 as one batch (the visible win), then 4. Ship 1+2+5+6 as the version after the one now in review, so review never waits on new features.
