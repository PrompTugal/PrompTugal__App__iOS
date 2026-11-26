# Changes in c7 / TestFlight 683: all eight personas (c.ios.synthetic, 26 Nov 2026)

> Build: dev `2403d92` (v0.4.127, TestFlight 683, = candidate c7). Compared with c6 (`2a58431`): [changes-c6.md](changes-c6.md). Code plus live JSON on 26 Nov ~03:15 UTC; no device. c7 changes only PTPlaces (Home, Places, colours) and three PTLocal strings.

## What changed versus c6

| Change | Where | Effect |
| --- | --- | --- |
| **Local-first Home.** The lead and top stories are "local" items only: an item with a place, or whose title names one of the 36 places (with Lisbon, Oporto, Portuguese, Algarvian). Placeless industry pieces move to a lower "Also in the news" strip; anything about Web Summit is dropped. Masthead: "Portugal's AI news, town by town". | `PTPlaces/PortugalHomeView.swift` (`isLocal`, `localNewestFirst`, `alsoInTheNews`, `isAboutWebSummit`) | c6 fix 3 done. Today's lead by that rule is "AI use in Portugal jumps in 2026" (23 Nov, title match); the newest item with its own place is 17 Nov. |
| **Places home shortened**: map hero, Since you last looked, From the town up, the accessory (Data sources, newsroom, persona, Near me), towns, capitals, latest, footer. Case studies, the national edition, Everything is connected, Work with us and the agents strip are gone. | `PTPlaces/PlacesHomeView.swift:25-45` | Shorter page for P1 on the SE; Near me moves up by five sections (still after Data sources and the newsroom). |
| **No more "independent"** in AlgarveView, the civic block and the on-device summary prompt. | `PTLocal/LocalViews.swift:61`, `Town/TownLayersView.swift:96`, `AI/LocalPrompts.swift:14` | Two of the three screens fixed. |
| Town accent colours darkened to at most 45% lightness in light mode. | `PTPlaces/PlaceVisuals.swift` | Better contrast for P6; dark mode unchanged. |

## Per persona

- **P1 Graça (Loulé, SE):** Places is now about half as long. Still stuck offline on first launch (no built-in copy in PTPlaces). Still no weather: `by-place/loule/now.json` was re-read at 01:12 UTC today but still has no weather or airport data, so the card stays hidden. Loulé still has no events.
- **P2 Rui (journalist):** the front page no longer leads with Spotify, CrewAI and Intercom; they sit under "Also in the news". Two nits: (1) title matching counts any headline naming "Portugal" or "Portuguese" as local, so national AI-policy pieces lead; acceptable, but say "Portugal" in the kicker so it does not read as a town story; (2) **the News tab header still says "Independent coverage from Lisbon"** (`PTNews/NewsHomeView.swift:42`), now the last "independent" in the app, against the disclosure.
- **P3 Marta (council):** the civic block now reads "PrompTugal.news Civic is not a council or government site. Every figure links to its source." Clear. Still no way to report a mistake.
- **P4 Tiago (Faro founder):** **regression**: "Work with us" (the only contribute link) left Places home, so there is now no route from the app to promptugal.news/contribute/. Explore (companies) is still unreachable.
- **P5 Hannah (Lagos):** Near me is higher on Places, but still below Data sources and the newsroom. Lagos events unchanged (feed read 21 Nov 09:20 UTC). No weather.
- **P6 Sr. Joaquim (Português, XL, VoiceOver):** still stuck: no language button and no device-language fallback. Darker town colours help legibility. Fixed-size mastheads unchanged.
- **P7 reviewer (if 0.4.127 is submitted):** no new risk. Carried from c6: 21 declared languages with English only; Explore and its bundled JSON with no entry point; summit widget and Siri intent; camera and microphone purpose strings; "Independent" on the News tab. None is a blocker on its own; the language list is the quickest for a reviewer to spot.
- **P8 Sofia (investor):** the agents strip and case studies left Places home; the newsroom now shows only through the live section and More > Newsroom. Fine, but the "agents newsroom" story is less visible from the front.

## Blocking

Nothing blocks a TestFlight round. For an App Store submission of this version: decide the language list (E1) and the News tab's "Independent" line; the rest is polish.

## Top fixes after c7

1. Device language (or the button back) and PTPlaces/PTLocal Portuguese (P6, stuck since c2e).
2. A contribute / "report a mistake" link somewhere (P3, P4: both now have no route).
3. Explore: an entry point or out of the build.
4. News tab: drop "Independent coverage from Lisbon".
5. Built-in snapshot for an offline first launch (P1).
6. Weather on town pages, and the data collectors running again (events still read 21 Nov).
