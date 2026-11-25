# Visual audit: PrompTugal.news iOS (c.ios.design, 25 Nov 2026)

> Read from the SwiftUI code on `work/candidate-c2` (5404498) and the live promptugal.news (25 Nov). No screenshots yet: every finding below is from code, so sizes on iPhone SE and iPad are estimates until one `screens.yml` run confirms them. The app runs `Look.soft` (`Apps/PrompTugal/PrompTugalApp.swift:19`).

Ranked by what a reviewer or a first-time reader would notice first. **R** = breaks a hard rule. Owner in brackets.

## 1. Must fix before the screenshots

| # | Screen | What is wrong | File | Fix |
| --- | --- | --- | --- | --- |
| 1 **R** | Places home footer | "Independent of Web Summit." is on the first screen of the app | `PTPlaces/PlacesHomeView.swift:343` | Drop the sentence. Footer: "Every fact on these pages comes from promptugal.news, with its source and the date it was read." (ios.places) |
| 2 **R** (done in PTCore, work/c-design) | More | Independence note named "Web Summit" (and its 15 translations) | `PTCore/Shell/ShellParts.swift:10`, `Localizable.xcstrings:1890` | "PrompTugal.news is independent. It is not affiliated with, endorsed by or sponsored by any event or organisation it covers." Needs re-translation (c.ios) |
| 3 **R** | Places home | No live / saved copy / built-in line anywhere on the tab the app opens on | `PTPlaces/PlacesHomeView.swift` masthead (l. 63) | Put a `SourceStamp` (proposal 1 in `direction.md`) under the masthead rule, driven by `PlacesStore`'s RemoteFeed state (ios.places) |
| 4 **R** | Explore | No provenance line; the error copy still says "The summit data loads once online" | `PTExplore/ExploreScreens.swift:169` | `SourceStamp` under the segment picker; copy: "Explore loads once online, then works offline." (c.ios.explore) |
| 5 **R** | Now | The freshness line follows the *agenda*, a finished summit; with no agenda Now shows "The agenda could not be loaded" | `Apps/PrompTugal/Shell/NowView.swift:102`, `:52` | After the summit (`.after`): freshness from the towns and news only; never show `agendaMissing`. Kicker "Lisbon ·" becomes the followed town or "Portugal" (c.ios) |
| 6 | More | Summit leftovers in a news app: "My program", "Venue map", "Reminders: Before each pick", and "CI status" (a team tool) | `Apps/PrompTugal/Shell/Destinations.swift:91-113` | Hide all four in Release; keep in DEBUG. More reads: Newsroom, Ask and summarise, Reading credit (if shown), About (c.ios) |
| 7 | Tab summaries | "Speakers, companies and places" (Explore) and "local AI news" (Places) | `Destinations.swift:74,81` | "Companies, stories and places"; "Portugal, the Algarve and its towns: local news, each story sourced" |
| 8 | Places home masthead | "PrompTugal.news" at 32 pt black serif + "by place" + Sign-in badge in one row: about 290 + 75 pt on SE's 343 pt; truncates or squeezes | `PlacesHomeView.swift:64-74` | `ViewThatFits`: one row when it fits, else "by place" on a second line. 28 pt on compact width |
| 9 | Places hero | Four uppercase stats in one `HStack` ("local AI stories", "on the AI map") overflow on SE and in large Dynamic Type | `PlacesHomeView.swift:133-138` | Two stats on compact (towns, stories) or a 2x2 `Grid`, as the town page already does at `PlaceDetailView.swift:194` |

## 2. Inconsistent with the website

| # | What | Where | Fix |
| --- | --- | --- | --- |
| 10 | Corners. Site cards: 3 px; app soft cards: 22 pt. The app reads as a different product (rounder, softer) next to the site's newspaper edges | `PTCore/Design/Theme.swift` `Space.radius` | Soft radius 22 → 12 (still iOS, closer to print). One token, all screens: needs a screens run before merge |
| 11 | Brand colour. Site: blue `#1b4597` / dark `#93b1ff` for links and actions, red only for "live". App: red is kicker, link and accent at once | `Theme.swift` `Palette` | Add `Palette.brand` (site blue) for links and buttons; keep red for kickers and "live" |
| 12 | Status colours. Site: ok `#2b6a3c`, warn `#8a5200`, live `#b42318`. App: green `#0B6B1E`, amber `#8A5A00`, red `#AD222B` | `Theme.swift` | Close enough to keep; name them by meaning (`Palette.ok/warn/live`) so provenance uses meaning, not hue |
| 13 | Headlines. Site: IBM Plex Sans 600, tight tracking, serif kept for story titles in the older pages. App soft: SF light large titles, serif masthead and story heads | `Theme.swift` `Typo` | Keep SF (no font bundling for one release). Story heads stay serif. Make `Typo.display` semibold, not light: light at 34 pt looks unfinished on paper colour |
| 14 | Copy. Site titles say "local AI stories, on the AI map"; the App Store now says "local news". The app says both | town numbers `PlaceDetailView.swift:189`, hero, tab summary | Follow the listing in the app chrome ("stories", "on the map"); keep "AI" where the number really counts AI stories. Ask Dinis whether the site moves too |

## 3. Three ways of saying where data came from

| Component | Package | Look |
| --- | --- | --- |
| `ProvenanceLabel` (live / offline / built-in copy) | PTLocal `LocalViews.swift:231` | caption, amber unless live |
| `ConditionsProvenance.label` drawn inline | PTLocal `ConditionsStore.swift:6` | own strings ("Live from IPMA") |
| `ProvenanceLine` (read by, signed) | PTPlaces `PlaceDetailView.swift:678` | caption2, seal icon |
| `FreshnessLabel` ("Updated 4 min ago") | PTCore `Components.swift` | caption, amber when stale |

Same idea, four words for it ("Offline", "Built-in copy", "Updated", "read"). Fix: one PTCore `SourceStamp` with three states and one wording (see `direction.md`). Owners adopt it screen by screen; the old types can wrap it.

## 4. Empty on iPad 13"

| # | Screen | Why | Fix |
| --- | --- | --- | --- |
| 15 | Now | `Page(maxWidth: Space.readable)` = 680 pt column in a 1032 pt (portrait) to 1376 pt (landscape) window | `NowView.swift:47` | `Columns`: towns left, latest news right, on regular width |
| 16 | Newsroom | One list on a 13" page | `PTLocal/NewsroomCentreView.swift` | `LazyVGrid` of agent cards, `.adaptive(minimum: 320)` |
| 17 | Town page | Hero 520 pt, then a 680 pt text column | `PlaceDetailView.swift` | "Now in" card beside the mandate on regular width |

## 5. Cramped on iPhone SE (375 x 667)

| # | Screen | Why | Fix |
| --- | --- | --- | --- |
| 18 | Town page | 440 pt hero = two thirds of the screen before any story | `PlaceDetailView.swift:143` | `min(440, height * 0.5)` via `containerRelativeFrame` |
| 19 | Places hero | 400 pt map hero, same problem | `PlacesHomeView.swift:116` | as 18 |
| 20 | Town name | 56 pt black serif, `minimumScaleFactor(0.5)`: "Vila Real de Santo António" drops to about 28 pt on one line | `PlaceDetailView.swift:123` | `lineLimit(2)`, 44 pt on compact |
| 21 | Explore | Segmented picker with three segments plus search field | `ExploreScreens.swift:144` | Fine at three; check at XXL Dynamic Type in the screens run |

## 6. Unfinished looking

| # | What | File | Fix |
| --- | --- | --- | --- |
| 22 | Town colour from the town file is used for white type on a mesh gradient with a white highlight point: a light town colour (yellow, sand) fails contrast | `PTPlaces/PlaceVisuals.swift:73` (`AccentCover`), `PlaceTheme.accent` | Clamp the accent's lightness in `PlaceTheme.accent` (HSL L ≤ 45 % light, ≥ 60 % dark), and drop the `Color.white.opacity(0.35)` mesh point |
| 23 | `SimulatedBadge` is purple (`series(4)`) with a magic-wand icon: reads as a feature, not a caveat | `PTLocal/LocalViews.swift:268` | See `direction.md`: outlined, ink-muted, "Simulated" plus a dashed border on the simulated block |
| 24 | PTPlaces has its own `Kicker`, `SectionHead`, `BigNumber`, so two kicker styles live side by side | `PlaceVisuals.swift:137-215` | Fold into PTCore once proposal 1 lands (the wire debrief's type-name clash list) |
| 25 | Purple, teal and brown series colours appear on the newsroom board next to the town colours: two colour systems on one screen | `Theme.swift` `series`, newsroom | Agents get `Palette.stable` *muted* (tint 0.12 background, ink text); towns keep the full colour |

## What I need to confirm this

One `screens.yml` run (iPhone 6.9", iPhone SE, iPad 13", en-US only) of: `places`, `now`, `news.home`, `explore`, `settings`, `local.newsroom`. Asked through the conductor, once, after c.ios.ux has the list.

A town page and the Algarve maps (`PTLocal/Live/AlgarveMapStyles.swift:471`, `AlgarveMapsView`) have no destination id, so `-PTDestination` cannot open them today. The screenshot set needs both: see `screenshots.md`.
