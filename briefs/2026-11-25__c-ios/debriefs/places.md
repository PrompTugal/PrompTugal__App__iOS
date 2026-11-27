# Debrief: c.ios.places (25 Nov 2026, ~23:45 UTC)

> Worker for c.ios on account C. Owns `Packages/PTPlaces` and its tests only. Branch `work/c-places`, based on
> `work/candidate-c2` (5404498, which contains dev ccddde5). Nothing compiled here: no Swift in the container, CI is
> the compiler. No secrets in this file.

## Done (all in PTPlaces, no shell, PTLocal, apps.json or xcodeproj change)

| Sha | What |
| --- | --- |
| 9c5847a | **Since you last looked** on the Places home (first section, under the masthead), from `api/v1/since.json`. Newest 8 (12 on iPad), "Show all". Each row: New mark, place name, "Our article" or "Story", day, title, "Read at <outlet>"; a tap opens the source. The device keeps the newest day shown and that day's item ids (`UserDefaults` key `places.since.seen`); the marker read at launch holds for the session. First run says "Your first look". |
| 9c5847a | `PlacesOrigin` + `PlacesOriginLabel` (internal, so no clash with PTLocal's `ProvenanceLabel`): live / this device's copy / built-in snapshot / data dated <day> when the data's own date is more than a day old / loading / not loaded. |
| 29c7e31 | **Across Portugal** shows every capital the index has (17 today) as a grid, with a count and an origin line. `PlacesStore.places` now adds places only `places.json` has after the index's own, so a stale saved index cannot hide capitals. Algarve numbers unchanged (`algarveTowns`). Masthead counts towns and capitals. |
| 7253eba, 7ccd4d7 | **Town page**: news newest first (lead = newest), only stories with an http(s) source link; events latest date first, unreadable dates ("date not shown") last; both end with "Read at <outlet>" and the read day; outlet falls back to provenance publisher, then the link host; event link falls back to `provenance.source_url`. Both sections carry the origin line. `newsByWeight` kept (tests use it). |

Tests added in `PlacesTests.swift`: SinceTests (decode, order, prefix ids `vila-real` / `vila-real-de-santo-antonio`,
marker, UserDefaults), OriginTests, RegionSplitTests.allCapitals, TownPageTests.

## Why "only 7 capitals"

The live index has all 17 and the old code had no limit: the likely cause is an index saved on the device before
16 Nov plus the side-scrolling strip. The union with places.json and the grid cover both. Confirm on a device.

## Open, for the conductor

1. **Rights holds:** every Algarve town's `ai_news` item (faro 28/28, loule 13/13, olhao 11/11) carries
   `"hold": "held under R12 ... not to be published or shown until it is"`, yet promptugal.news shows them on the town
   pages and in since.json. The app follows the site and shows them. If Dinis wants holds honoured, it is a one-line
   filter in `PlaceFile.newsNewestFirst` (and `latestAcrossTowns`); the Algarve town pages would then have no news.
2. by-place files are dated 16 to 17 Nov, so town pages will say "data dated 16 Nov 2026", not live. That is the rule
   working.
3. Not compiled yet: first CI run on a candidate will tell. Watch for type-checker time in `SinceYouLookedSection`.

## Update: rights holds honoured (c.ios, 25 Nov ~23:30, until Dinis decides)

`NewsItem.hold` / `isHeld` decoded from ai_news. A held item shows only its headline, outlet, date and source link,
with "Read it at <outlet>": no summary, AI path, steps badge or provenance block, on the town page (lead and tiles),
the case-study cards and "Latest from the towns". since.json rows already show only those fields. PTLocal also
renders by-place stories (LocalStore, Live views): not mine, the conductor may want the same rule there.

**Revised (Dinis via c.ios, ~23:35):** held items show headline, summary, outlet, date and the source link ("Read it at
<outlet>"); the AI path, steps badge and provenance block stay hidden. "Independent of Web Summit." removed from the
home footer: no Web Summit anywhere in PTPlaces.

## Map first, locality as the frame (Dinis via c.ios, ~23:35)

- **PlacesMapHero** (`LocalFrame.swift`), right under the masthead: a 420 pt (560 on iPad) map, segmented
  "The Algarve" (17 towns) / "Portugal" (17 capitals plus the Algarve), every pin a NavigationLink to its place, a chip
  row under it doing the same, and the origin line. It replaces the old satellite region hero.
- **From the town up** (`BubblingUpSection`): the featured town (first followed town with a story, else the town of the
  newest town story), a three-step ladder Portugal / its region / the town with how many since.json items reach each
  ring, then the town's newest stories each with its trail (town › region › country, each a link to that place).
- Home order: masthead, map, Since you last looked, From the town up, case studies, then the rest.
- Ring matching is exact (`rings.contains(id)`), tested with `vila-real` against `vila-real-de-santo-antonio`.

## Anchors (spec S5) and iPhone SE (26 Nov, after c4 run 573: 43 PTPlaces tests green)

- Public API for the shell: `PlacesDeepLink("place:loule#lead")` (id + `PlaceAnchor` `.now` / `.lead`), set once with
  `.placesDeepLink(link)` high in the tree (like the other hooks), or `PlaceDetailView(id:anchor:)`. Only the page whose
  id matches scrolls, so places pushed from it open at the top. It scrolls once, when that section has data (the
  "Now in" card needs now.json; the lead needs a story with a source link).
- iPhone SE: the home map is at most 55% of the visible height (260 pt minimum, 420 phone / 560 iPad maximum); the
  masthead drops the date and wraps when the line does not fit.

## The news home and Places on Portugal (Dinis via c.ios, 26 Nov ~00:40, after build 675)

- **`PortugalHomeView(openPlaces: (() -> Void)? = nil)`** (public, `PortugalHomeView.swift`; `NewsHomeView` is taken by
  PTNews). Put it in a NavigationStack; it registers its own `PlaceRoute` destination. Sections: masthead with the
  since.json origin line; the lead (our newest article, else the newest item) with its trail; "Top stories" (newest,
  one per place before any place repeats) each with title, "Read at <outlet>", date and its town › region › country
  trail; "Latest from the towns" from the place files (held items follow the hold rule); a still map strip of the
  capitals and the Algarve, each pin opening its place, and an "All places" button when `openPlaces` is given.
- The data sites (data., civic., events.) are not read yet: their collectors stopped on 21 Nov (bigger pass).
- **Places opens on Portugal**: the home map's first and default tab is Portugal; the Algarve is the second.
- **Home is local (Dinis via c.ios, ~00:49):** lead and top stories come only from local items: an item with its own
  place, or one whose title names a feed place (Portugal included; accent- and case-blind, whole words). Placeless
  items (industry news) go to a lower "Also in the news" strip. Masthead: "Portugal's news, town by town".
  English names count too (Lisbon, Oporto, Portuguese, Algarvian), and items whose title names Web Summit stay off
  Home. On since.json of 26 Nov: 89 local items (lead "AI use in Portugal jumps in 2026"), 37 in "Also in the news".

## Design review c5/c6 (c.ios.design via c.ios, 26 Nov ~01:25)

- A: `RingTrail` wraps (WrapLayout), sentence case; only the town is in its colour.
- B: `LadderStep` is one row when the name fits beside an 80 pt bar, else the name above the bar.
- C: Places keeps map, Since you last looked, From the town up, the shell's accessory, the town mosaic, the capitals,
  Latest from the towns and the footer. Case studies, national edition, connected towns, work with us and the agents
  strip are no longer on the page (their code stays, for town pages or the Newsroom).
- D: `PlaceTheme.accent` darkens any town colour to at most 45% HSL lightness in light mode (same hue); dark mode
  unchanged. Tested.
- E: the ladder's region and country bars are ink at 0.6; only the town has its colour.
- Home's map strip is smaller (150 pt, 200 on iPad) and stays last.
- Home tagline is now "Portugal's AI news, town by town", matching the App Store subtitle (Dinis, 26 Nov ~02:10); the local-first ranking stays.

## The article reader (next version item 1, Dinis via c.ios, 26 Nov ~02:45)

- **`ArticleView(id:)`** (public) and `ArticleRoute`. Home's lead and top stories, Since you last looked, From the town
  up and a town page's "Our articles" open our own articles (`promptugal.news/articles/<id>.html`) in the reader;
  third-party items still open their source. PortugalHomeView and PlacesHomeView register the `ArticleRoute`
  destination.
- The reader: title, date, author agent, summary, origin line, "Read the full article on promptugal.news", every
  source from `api/v1/articles/<id>.json` as a link (host and text), the signature panel, and "How this was made"
  (level, type, origin, research, the P0 to P5 ladder) from `api/v1/articles/provenance.json`.
- **Signature, checked on the phone.** Confirmed from the site's source (PrompTugal__News__Website
  `newsroom/build/signed-form.cjs`, read-only) and against the live article ai-use-in-portugal-2026 (verified in Python):
  ECDSA P-256 with SHA-256, raw r||s, over the twin with `· site vX.Y.Z ·` and `version: vX.Y.Z` written as `VERSION`
  and the last line-start `built by: ...` written as `built by: BUILDER` (form 2; replaced, not removed). Key
  fingerprint = "sha256:" + first 16 hex of SHA-256 over the SPKI DER, worked out on the phone for every key in
  `board/keys.json` (575 KB, cached an hour). States: "Signed by <agent>, checked on this phone" / "Signature does not
  match" / "Signature not checked: <reason>" (no key with that fingerprint, an older form, unreadable file, text or
  keys not loaded). Form 1 (legacy) is reported as not checked rather than verified.
- Tests: a throwaway P-256 key (public half only in the test) signs a small twin in form 2; good, version-bumped,
  changed, missing-key, old-form and junk cases; the real reviewer key's fingerprint; lenient decoders; link parsing.
- Aligned with c.ios.explore's spec (work/c-explore 261edbd, s. 2): states "Signed by <agent>, checked on this
  device", "Signed with a key since handed over (<agent>)" (status superseded), "Signed in an older form that cannot
  be checked" (no form or form 1, never "invalid"), "The signature does not match this text", "Not signed" (.sig 404),
  "Signature not checked: <reason>" (withdrawn, more than one "built by" line, a key marked other than active or
  superseded, files not loaded). The trust limit is said under the verdict, with links to the signed text, the
  signature and the key list. The .sig is fetched directly so a 404 reads as "Not signed".
- Offline edition (c.ios.local's EditionFiles): not wired; a `placesOfflineData` hook can come later if wanted.

## English and Portuguese (Portugal) (Dinis via c.ios, 26 Nov ~23:40)

- **Catalogue:** every `String(localized:)` in PTPlaces (241 calls, 229 keys) now has `bundle: .module`;
  `Sources/PTPlaces/Resources/Localizable.xcstrings` holds en and pt-PT for all of them (European Portuguese:
  "dispositivo", "concelho", "capitais de distrito", "Início"). `Package.swift` processes
  `Resources`. Interpolated keys use `%@` / `%lld` (`%%` for a literal percent); pt-PT reorders with `%1$…`.
  Three call sites with nested quotes were rewritten so every key is a plain literal. Dates follow the app's
  language (`PlacesLanguage.locale`: pt_PT or en_GB); IPMA warning colours and "Researching" are translated.
- **Place prose from the site's memory** (`PlacesTranslation`, `TMKey`, `TMShard`): when the app runs in pt-PT, a town
  page's mandate, centre of gravity and story summaries come from `data/i18n/tm/pt-PT/<2 hex>.json` (key = first 16
  hex of SHA-256 over the site's normalised English; shards fetched as needed and kept a day on the device). Each
  section says "Tradução automática, não revista · ver em inglês" (or "verificada" for `ok: true`); a tap shows the
  English ("Em inglês, como publicado · ver a tradução"). Headlines, articles and since.json titles stay as published;
  the reader says "Os artigos estão em inglês". Nothing is translated on the device; a missing entry stays English.
- Tests: keys against values computed with the site's normalisation (NFC, NBSP, CRLF, blank lines), a lenient shard,
  English untouched, the compiled pt-PT catalogue (with a positional format), and which prose is translated.
- c9 fix: Xcode's symbol generation rejected keys differing only in case. Merged events/Events, sources/Sources (BigNumber uppercases anyway) and the two "signature does not match" keys; reworded Open %@ → Visit %@, signature %@ → signature is %@, The towns → Its towns, so no two keys share a symbol once case, punctuation and format specifiers are dropped. 226 keys.
