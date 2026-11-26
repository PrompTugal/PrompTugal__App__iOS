# Review of candidate c5 (4cdd444), from code (c.ios.design, 26 Nov 2026)

> The screens.yml run 45727939914 artifacts (15075966897 iPhone, 15075633678 iPad) return 404 to this session as well as to c.ios, so this is a code read, not a picture read. Next candidate c6 (Home tab first, Places on Portugal, Explore off the tabs) will change the Places notes below; they are written so they still apply to `PortugalHomeView`.

## Closed since the audit

| Audit # | What | Now |
| --- | --- | --- |
| 1 | "Independent of Web Summit." on Places home | gone (work/c-places) |
| 2 | Independence note in More | reworded in PTCore on work/c-design (ce0e2ba), waits for the PTCore batch |
| 3 | No provenance on Places home | `PlacesOriginLabel` under the map, with an honest "data dated" state |
| 4 | Explore provenance and summit copy | fixed (work/c-explore) |
| 5 | Now follows the summit agenda | agenda states and agenda freshness gone (c.ios) |
| 8, 9, 19 | Masthead/hero cramped, 400 pt hero | the map hero is `min(420, max(260, 55 % of height))`: about 300 pt on SE |

The map-led home and the "From the town up" ladder (`PTPlaces/LocalFrame.swift`) follow `direction.md` closely. Good work.

## New findings on c5 (owner: ios.places unless said)

| # | Rank | What | File | Fix |
| --- | --- | --- | --- | --- |
| A | high | `RingTrail` puts uppercase heavy chips in one `HStack` with no wrap: "VILA REAL DE SANTO ANTÓNIO › ALGARVE › PORTUGAL" runs off an SE screen and every large Dynamic Type size | `LocalFrame.swift:287` | Use the package's own `WrapLayout` (`PlaceDetailView.swift`), sentence case instead of uppercase |
| B | high | `LadderStep` gives the place name a fixed 130 pt: long names and XL type truncate ("Vila Real de S…") | `LocalFrame.swift:269` | `ViewThatFits`: name, bar and count on one row when it fits, else name above the bar |
| C | medium | Below the map, bubbling-up and "since you looked", the old home still follows: case studies, national edition, town mosaic, across Portugal, connected, latest, work with us, agents strip (8 more sections). The page is very long and the summit-era sections dilute "locality first" | `PlacesHomeView.swift` body | Keep: map, since you looked, from the town up, town mosaic, latest, data sources link, footer. Move case studies, connected, work with us and agents strip to the Newsroom or the town pages |
| D | medium | Map pins use the raw town colour; a light town colour fails on the standard map's pale land, and white pin glyphs fail on it too (audit 22) | `LocalFrame.swift:146`, `PlaceTheme.accent` | Clamp lightness once in `PlaceTheme.accent` (≤ 45 % L in light mode) |
| E | low | The ladder bar uses each place's own colour, so Portugal's bar gets a hash colour (`Palette.stable("portugal")`) that means nothing | `LocalFrame.swift:232` | Town: its colour. Algarve and Portugal: `Palette.ink` at 0.6. Only towns own colours |
| F | low | Pin size does not show how much news a town has; the chips below do (count). Fine for now; `direction.md` asks for three pin sizes later | `LocalFrame.swift` `TownPin` | Later |
| G | info | Five provenance vocabularies now: PTPlaces `PlacesOrigin` ("Built-in snapshot, not live", "This device's copy, saved …", "data dated …"), PTLocal `ProvenanceLabel`, `ConditionsProvenance`, PTCore `FreshnessLabel`, and the PTExplore label | several | PTCore `SourceStamp` now has a `.dated` state matching PlacesOrigin's rule, so each package can map onto it when the PTCore batch ships. One set of words: Live, Saved copy, Built-in, Data dated |

## For the screenshot set

With c6's Home tab, shot 1 becomes the Home tab (map and "From the town up" in frame, the origin line under the map). The rest of `screenshots.md` stands. c.ios.ux owns the list.
