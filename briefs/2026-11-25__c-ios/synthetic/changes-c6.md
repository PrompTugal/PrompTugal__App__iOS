# Changes in candidate c6: all eight personas (c.ios.synthetic, 26 Nov 2026)

> Build: `work/candidate-c6` at `2a58431` (the next version, after c2e). Compared with c2e (`5cbf730`). Code plus the live JSON on 26 Nov ~01:00 UTC; no device. Personas: [personas.md](personas.md); shared findings S1 to S14 are in [walkthroughs.md](walkthroughs.md).

## What c6 changes for everyone

| Change | Where | Effect on the S-list |
| --- | --- | --- |
| **Home tab first**: PrompTugal.news front page, "AI news from Portugal, town by town", a lead, Top stories (one per place first), Latest from the towns, a small map of Portugal | `PTPlaces/PortugalHomeView.swift`; `Destinations.swift:92-93`; `PublicShell.swift` (default tab `home`) | **S2 better**: the masthead now says "AI news", matching what the app is. |
| **Freshness lines** on Home, Places, the map and town pages: "Live from promptugal.news", "From promptugal.news, data dated <day>", "This device's copy, saved <day>", "Not loaded" | `PTPlaces/PlacesOrigin.swift:34-48`, used in `PortugalHomeView.swift:89,140`, `SinceYouLooked.swift:227`, `LocalFrame.swift:84`, `PlaceDetailView.swift:304,443` | **S4 fixed.** |
| "live" hero stat gone from Places | `PlacesHomeView.swift` | **S3 fixed** (Newsroom flow card's "Edit and publish: Live" remains). |
| **Since you last looked** (since.json: 151 items, 45 days, built 26 Nov) with "New" marks, and **From the town up** (town, region, country) | `SinceYouLooked.swift`, `LocalFrame.swift:189-243` | new, good |
| **Town layers**: "What is on" (data.promptugal.news events by place) and the council's open procurement notices (civic) | `PTLocal/Town/TownLayersView.swift`, `TownFeeds.swift:24,90,179` | **S1/S2 partly**: Lagos 86 events, Tavira 34, Faro 12, Lisboa 461, Loulé 0 (all read 21 Nov 09:20 UTC) |
| **Data sources** and **Algarve maps** in More; a Data sources card on Places | `PTLocal/DataSources/*`, `PublicSettingsView.swift`, `PlacesWiring.swift` | new; honest "N of M sites read their data in the last 3 hours" |
| **Now without the summit**: greeting, "Portugal · <day> · <time>", news freshness, your towns, latest news | `Apps/PrompTugal/Shell/NowView.swift:37-60,71-73` | **S6 partly fixed** |
| Explore rebuilt on the newsroom (stories, companies, places, library, videos; about 4,700 lines of bundled JSON) but **not reachable**: no tab, no More row; only dead summit paths call `open("explore")` | `Destinations.swift:104-105` (`listed: false`), `PTExplore/Resources/newsroom-*.json` | see below |

Unchanged: no weather on town pages (S1: the "Now in" card still reads the empty `by-place/<id>/now.json`, `PlaceDetailView.swift:182-186`; weather only in More > Ask and summarise via `ConditionsCard`); no built-in copy for PTPlaces, so a first launch offline shows "The news did not load" on Home (S5); summit widget and Siri (S7); "independent" on the News tab, in AlgarveView and now also in the new civic block, "PrompTugal.news Civic is independent, not a council or government site." (`TownLayersView.swift:96`) (S8); no language switch at all since c2e (S12, worse, see P6); fixed-size mastheads, now also on Home (`PortugalHomeView.swift` masthead 32/44 pt) (S13).

## Per persona: what changed

### P1 · Graça, Loulé, iPhone SE, poor signal
- **Better:** Home opens on a front page with a clear freshness line; "Since you last looked" gives her what is new in two taps.
- **Same, stuck:** offline first launch, Home and Places both fail with no built-in copy (S5). No weather on Loulé's page (S1).
- **New, annoying:** Loulé has **0 events** in the events feed, so "What is on" is hidden on her own town page, while Faro and Tavira have lists. The council block shows procurement notices, not the council news she wanted. Places home is now 13 sections long on a 4.7" screen (map hero, Since you last looked, From the town up, case studies, Data sources, newsroom live, persona, Near me, ...).

### P2 · Rui, Lisbon tech journalist
- **Better:** every block says where its data came from and its date; "Read at <outlet> · <date>" on each item; Data sources lists each site's read time. The masthead says "AI news", which matches the content.
- **Annoying:** Home's lead and top stories come from since.json, where 78 of 151 items have no place and count as "Portugal"; today's lead is "A study of five coding agents" and the next are CrewAI, Intercom, Spotify: industry pieces, not Portuguese news, under "AI news from Portugal". Fix: lead with the newest item that has a place, or label placeless items "Wider AI news".
- **Annoying, wider:** "independent" now appears in three places (News tab, AlgarveView, civic block) against the disclosure's "not independent coverage".
- **Lost:** the rebuilt Explore (companies, library) would suit him, but he cannot reach it.

### P3 · Marta, council officer
- **Better:** her council's page now has a council block: open procurement notices from the Diário da República and the year's contracts, each linked, with "PrompTugal.news Civic ... not a council or government site". That is accurate and sourced.
- **Same, stuck:** still no way to report a mistake from the app (comments hidden).
- **Polish:** "No procurement notice of this council is open today." is shown when empty, phrased fairly.

### P4 · Tiago, Faro startup founder
- **Better:** Faro has 12 events; "From the town up" shows how Faro's stories rise to the Algarve and Portugal.
- **Same:** no way to add his company; Work with us still aims at journalists.
- **Lost:** the newsroom's 115 companies are now in Explore's bundled data, but Explore has no entry point.

### P5 · Hannah, tourist in Lagos
- **Better, was stuck:** Lagos now shows "What is on" (the feed lists 86 events) from the venues' and council's agendas, labelled "A dated list, not a ticket office". Many are long-running exhibitions that started in October; the app keeps events on now or starting soon (`TownFeeds.swift:5-6`), so the visible list is shorter.
- **Same:** no weather or sea (S1); Near me is even deeper on Places (after Data sources and the newsroom); event titles are in Portuguese (fine, they are the venues' own).
- **Polish:** read 21 Nov; the block says so, which she may read as "out of date" on 26 Nov. The collectors need to run again.

### P6 · Sr. Joaquim, Portuguese, Accessibility XL, VoiceOver
- **Worse, stuck:** since c2e there is no language button and `AppCulture.start` ignores the device language (`PTCore/Culture/AppCulture.swift:63-65`), so he gets English everywhere, though the app ships Portuguese catalogues (the new PTExplore one included) and the store will list Portuguese. Fix: follow the device language when it is one of the shipped cultures; add pt-PT to PTPlaces and PTLocal.
- **Better:** Tavira's events (34) are in Portuguese, from the town's own agendas.
- **Same:** fixed-size mastheads and hero numbers (S13), now on Home too.

### P7 · App Store reviewer (if c6 is the next submission)
- **New risk, medium:** Explore and its about 4,700 lines of bundled newsroom JSON ship with no way in. Not a rejection by itself, but if any path reaches it (Now's dead summit buttons are the only callers), a reviewer finds a hidden screen. Either list it ("Explore: stories, companies, places, library") or leave the package out.
- **New, check:** Data sources lists every *.promptugal.news site, including ones whose feeds are a snapshot from 21 Nov; the screen says so plainly. Good for honesty; make sure no row links to the newsroom's admin or status pages.
- **Carried:** E1 (21 languages listed, English only), the summit widget and Siri intent, camera and microphone purpose strings, "independent" (now three places).
- **Listing:** "Local news" positioning now disagrees with the app's own masthead "AI news from Portugal, town by town". Align the subtitle and description with the masthead for the c6 submission.

### P8 · Sofia, investor
- **Better:** Data sources shows the whole system (sites, collectors, cadence, last read) in one screen: the most convincing view of the operation so far. Now no longer looks like a conference app.
- **Annoying:** the collectors' read dates (21 Nov) show the data layer stopped five days ago, in plain sight.
- **Lost:** Explore's companies and library are built but hidden.

## Top fixes for c6, in order

1. **Follow the device language** (or restore the language button) and translate PTPlaces/PTLocal: P6 went from annoying to stuck.
2. **Give Explore an entry** (a More row or a Home link) or drop it from the build: it is the best thing for P2, P4 and P8 and nobody can reach it.
3. **Home lead from placed items**, or label placeless items "Wider AI news" (P2, P1).
4. **Built-in snapshot of since.json and the index** for an offline first launch (P1).
5. **Weather on the town page** from weather.promptugal.news or ConditionsCard (P1, P5), and restart the collectors (events read 21 Nov).
6. **One wording on independence**, now three screens (P2, P7).
7. **Near me higher on Places**, or on Home (P5).
