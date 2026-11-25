# Design direction: PrompTugal.news, local news town by town (c.ios.design, 25 Nov 2026)

> One page. The aim: the app looks like the newspaper on promptugal.news, says plainly where each fact came from, and lets each town have its own colour without turning into a paint box.

## The idea in one line

**A calm local paper on paper-coloured stock: ink type, one brand blue for actions, each town's colour as its flag, and a small, always-present stamp saying where the page came from.**

## Type

- **Story headlines: serif** (`Typo.story`, `storyTitle`, `storyDisplay`). Unchanged. It is what makes News and a town read like a paper.
- **Chrome: SF**, as now. No bundled fonts this release (the site's IBM Plex Sans is close enough to SF at app sizes).
- `Typo.display` in the soft look goes from **light to semibold**. Light at 34 pt on paper colour reads as a placeholder.
- Masthead "PrompTugal.news" stays black serif, but **28 pt on compact width**, 44 on regular, with "by place" dropping to its own line when it does not fit (`ViewThatFits`).
- Numbers: `Typo.number` (rounded, even digits). Town numbers use the same, not a separate black serif.
- Dynamic Type everywhere: no fixed `size:` fonts except the masthead and town name, and those carry `minimumScaleFactor` *and* `lineLimit(2)`.

## Colour

| Role | Token | Light | Dark | Use |
| --- | --- | --- | --- | --- |
| Paper, card, ink, muted, rule | as now | | | the page |
| **Brand** (new) | `Palette.brand` | `#1B4597` | `#93B1FF` | links, buttons, "open source" (the site's `--brand`) |
| Kicker / live | `Palette.red` | `#AD222B` | `#FF868A` | kickers, the "live" dot only |
| OK | `Palette.ok` = green | `#0B6B1E` | `#6FCF7F` | live data |
| Warn | `Palette.warn` = amber | `#8A5A00` | `#F2C14E` | saved copy, stale |
| Town colour | from the town file | clamped | clamped | the town's flag: a 4 pt rule, its pins, its cover |

Rules:
- **One accent per screen.** On a town page the town colour; everywhere else red for kickers and blue for actions.
- **Town colours are clamped** so white type on them passes 4.5:1 (lightness at most 45 % in light mode, at least 60 % in dark). Done once in `PlaceTheme.accent`.
- Agents on the newsroom board get a **tint** of their stable colour (12 % background, ink text), never the full colour, so they never compete with the towns.
- Purple is retired as a meaning. It is now only a series colour in charts.

## Cards

- Corner radius in the soft look: **22 → 12 pt**. Still iOS; much closer to the site's 3 px newspaper edges. One token (`Space.radius`).
- Hairline rule border (0.5 pt) stays; the soft shadow drops to 0.03 opacity. The site's cards are flat.
- A town card: town colour as a **4 pt top rule** (already on `PlacesHomeView.swift:540`), card background stays `Palette.card`. No full-bleed colour behind text except the town cover.
- Story row: kicker (town, in its colour) · serif headline · one-line summary · **source line** (publisher, "read 24 Nov") in muted, tappable, brand blue link icon.

## Place identity

Each town has three marks, used the same way on every screen:

1. **Its colour**: the 4 pt rule on its cards, its pin on the maps, its cover gradient.
2. **Its name in serif**, black weight, on its cover.
3. **Its landmark line** under the name (from the town file, "Photo: …" credit beneath).

The map colours towns by how much news they have (the listing says so). Use **one ramp in brand blue** for that, not the town colours, so "how much" and "which town" never mix.

## Provenance: honest but calm

One component, `SourceStamp` (PTCore, proposal 1), used at the top of every data screen and under every block that has its own source.

| State | Icon | Text | Colour |
| --- | --- | --- | --- |
| Live | filled dot | **Live** · promptugal.news · 2 min ago | ok green dot, muted text |
| Saved copy | `arrow.down.circle` | **Saved copy** · read 24 Nov, 18:40 | warn amber icon, muted text |
| Built-in | `shippingbox` | **Built-in** · read 21 Nov | warn amber icon, muted text |
| Not loaded | `wifi.slash` | **Not loaded** · Try again | warn amber |

- Only the *icon* carries the colour; the text stays muted. Amber text all over a screen feels like an alarm; an amber icon is a calm, honest note.
- Always a date: "read <date>". Relative ("2 min ago") only when under a day; else the date.
- Same words everywhere: **Live, Saved copy, Built-in**. Retire "Offline: the last copy this device read" and "Built-in copy of … : connect to update" (both too long for SE).
- VoiceOver reads the whole line: "Saved copy, read 24 November at 18:40".
- For the data feeds stuck at 21 Nov (bigger-pass.md): a feed with `read_at` older than a day shows **Built-in/Saved copy**, never "Live", whatever the fetch did.

## The "Simulated" badge

- Outlined capsule, **ink-muted text and border**, icon `play.rectangle` (a replay), text **Simulated**. No purple, no magic wand.
- The simulated block itself gets a **dashed 1 pt border** in `rule` colour, so the whole area reads as "not real", not only the row with the badge.
- Badge sits top-trailing of the block and never scrolls away from its block. It is not removable by any setting.
- VoiceOver: "Simulated: a replay, not live data".

## Locality first (Dinis, 25 Nov ~23:35, via c.ios)

The frame for everything: **you are somewhere**. The towns, then the Algarve, then Portugal. News starts in a town and bubbles up. The summit is gone from the app's identity entirely.

### Places home, led by the map

The map *is* the front page, not a hero above it.

1. **Masthead**, one line: "PrompTugal.news" and today's date. The source stamp sits under the rule.
2. **The map, full width, 60 % of the screen height** (`containerRelativeFrame(.vertical) { $0 * 0.6 }`, at least 320 pt, iPad up to 640). It is interactive (pan, pinch) and every town is a pin in its own colour. The pin size grows with that town's stories this week (three sizes, not a continuous scale). A pin with news in the last 24 hours gets a soft ring pulse, once on load, never looping. Tap a pin: a small sheet with the town's name, its latest headline and "Open Faro".
3. **Level switch over the map**, a segmented control: **Towns · Algarve · Portugal**. Same map, the camera moves. Towns shows the 17 Algarve pins. Algarve shows the region's outline with its total. Portugal shows the district capitals plus the Algarve as one cluster.
4. **"Bubbling up" strip** directly under the map (see below).
5. Then the stories, town by town: one card per town with news, ordered by newest story, each with the 4 pt town colour rule.
6. **Data sources** card (see below), then the footer.

Moves *out* of the first screen: the case studies, the national edition block, "work with us", the agents strip. They go below the stories or into the Newsroom. On iPad: map left (60 % of the width), bubbling-up and stories in a column on the right.

### The bubbling-up visual

How one town's story becomes regional, then national news. Three stacked rows, read bottom to top, as a quiet diagram rather than a chart:

```
  Portugal    ●───────────────  2 stories reached national news
     ▲
  Algarve     ● ● ●───────────  5 stories across the region
     ▲
  Towns       ● ● ● ● ● ● ● ●  23 stories in 11 towns
```

- Each dot is a story, filled in **its town's colour**. A dot that has risen a level appears again in the row above, joined to its original by a thin rule-coloured line. So you can follow Faro's story up to Portugal by colour.
- Rows are labelled in `Typo.kicker`, counts in `Typo.data`. The rows have no background, only hairline rules between them.
- Tap a dot: the story. VoiceOver reads each row as a sentence ("Algarve: 5 stories across the region, from Faro, Loulé and Lagos").
- On a town page, the same component, but cut down: that town's row only, with its risen stories marked "also in Algarve" / "also national" as small chips.
- Data: a story's level comes from the by-place feeds (the story appears in the town's, the Algarve's or Portugal's `by-place/{id}.json`). **No inferred levels**: if the feeds do not say it, the dot stays in its town row.
- Component: `BubbleUpView` in PTCore, taking `[Level: [Dot(id, colour, risesTo)]]`, so PTPlaces only supplies the data. (A future proposal for c.ios, after SourceStamp lands.)

### Data sources card

The sites and feeds behind a page (promptugal.news, data, weather/IPMA, events, civic, bulletins, live cameras, library), shown as a **card style**, the same on the home page, a town page and in the Newsroom.

```
┌───────────────────────────────────────────┐
│ Data sources · 8                          │
│                                           │
│ ● promptugal.news   news by place         │
│   Live · 2 min ago                        │
│ ● IPMA              weather, warnings     │
│   Saved copy · read 24 Nov, 18:40         │
│ ● civic             council notices       │
│   Built-in · read 21 Nov                  │
│ …                                         │
│ See all 30 public collectors  →           │
└───────────────────────────────────────────┘
```

- Plain `Card`. Kicker "Data sources" with a count.
- One row per source: the dot in the **status colour** (ok, warn) as in `SourceStamp`, the source's name in `Typo.headline` weight at body size, what it gives in muted, and its `SourceStamp` line underneath. Tap a row: the source's public page (brand blue link icon trailing).
- At most 5 rows on iPhone, then "See all". On iPad, two columns.
- Media sources (`Source.isMedia`: press, radio, blogs) are listed separately as **"Local media we send you to"**, so the reader can tell our data feeds from the reporting we link out to.
- It is honest by construction: a source that is stale shows amber, even on the home page. With the data collectors stopped at 21 Nov (bigger-pass.md), this card will show that today, and it should.
- Component: `DataSourcesCard` in PTCore, taking `[DataSource(name, gives, url, state: SourceState)]`. Uses `SourceStamp`.

## Do not

- No "Web Summit" text anywhere. The More note is reworded in PTCore (869a8c9 onwards); the Places home footer is ios.places's to change.
- No sign-in, comment or "connect" chrome in this App Store version (already hidden in c2; keep `PersonBadge` behind `placesComments`).
- No full-screen colour behind body text. No light weights for titles.

## Proposals (PTCore only, after the conductor says yes)

1. **`SourceStamp`** (new file `PTCore/Design/SourceStamp.swift`): `enum SourceState { live(Date), saved(Date?), builtIn(String), notLoaded }`, the view above, and `SimulatedTag` (the new badge style). Additive: nothing changes until an owner uses it.
2. **Tokens** in `Theme.swift`: add `Palette.brand`, `Palette.ok`, `Palette.warn` (aliases), soft `Typo.display` semibold. Additive except the display weight.
3. **Later, after a screens run:** soft `Space.radius` 22 → 12 and the softer card shadow. Touches every screen, so only with screenshots.
