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

## Do not

- No "Web Summit" text anywhere (audit 1, 2).
- No sign-in, comment or "connect" chrome in this App Store version (already hidden in c2; keep `PersonBadge` behind `placesComments`).
- No full-screen colour behind body text. No light weights for titles.

## Proposals (PTCore only, after the conductor says yes)

1. **`SourceStamp`** (new file `PTCore/Design/SourceStamp.swift`): `enum SourceState { live(Date), saved(Date?), builtIn(String), notLoaded }`, the view above, and `SimulatedTag` (the new badge style). Additive: nothing changes until an owner uses it.
2. **Tokens** in `Theme.swift`: add `Palette.brand`, `Palette.ok`, `Palette.warn` (aliases), soft `Typo.display` semibold. Additive except the display weight.
3. **Later, after a screens run:** soft `Space.radius` 22 → 12 and the softer card shadow. Touches every screen, so only with screenshots.
