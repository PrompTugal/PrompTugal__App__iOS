# Status · Deck (PTDeck, then PTExplore)

> PTDeck merges as is (via design's run). New priority from the conductor: PTExplore (talks, speakers, companies, organisations, places), written and pushed, not yet compiled. Both packages are on `split/deck`; one CI run next.

Branch: `split/deck` · Last update: 8 Nov, 12:00 UTC · Last CI run: none yet

## What the site publishes today
- The decks are HTML pages (`investors/decks/<id>/index.html`, and `.../<lang>/index.html` for pt, fr, es), each with a Markdown twin (`index.md`). There is no deck JSON and no speaker notes. Images are on the page only.
- The list is `investors/decks/index.html` (`investors/<lang>/decks/index.html`): 10 decks, 0 to 9. Covers are `board/team/investors/site/img/covers/<id>.<lang>.jpg`.

## Design
- `DeckSource` (protocol): `catalog()` and `deck(id:language:)`. Injected, so PTSync can plug in later.
- `HTTPDeckSource` reads `api/v1/decks/index.json` and `api/v1/decks/<id>.<lang>.json` (the format the app-first brief asks the site to publish; the model decodes it, see `DeckModel.swift`).
- `SiteDeckSource` reads today's pages: text from the Markdown twin (each `##` is a slide), images from the page's slide blocks.
- `DeckSources.published()` = published JSON first, site pages second, kept on disk (`CachedDeckSource`, Application Support/PTDeck) for offline reading.
- Language: preferred, then English, then the first the deck has.
- Screens: `DeckScreen` (list, language menu, reader with swipe). iPad adds Present. Presenter: current slide, next slide, notes, timer; the external display follows the current slide.

## Needs from others
- **apps:** add `XCLocalSwiftPackageReference` for `Packages/PTDeck` to `Apps/PrompTugal`, then add `"PTDeck"` to the promptugal app's `packages` in `apps.json` (I left it out so `check_apps.py` stays green: it compares the project with the list).
- **apps:** for a true second screen, the Info.plist scene manifest needs a configuration for `UIWindowSceneSessionRoleExternalDisplayNonInteractive` with delegate class `PTDeck.ExternalDisplaySceneDelegate`. Without it iOS mirrors the iPad screen (the console shows on the TV). Needs a real iPad and display to confirm.
- **design:** register screen id `decks`, view `DeckScreen()` (it has its own navigation stack: `ownsNavigation: true`), iPad group "Tools".
- **editor / site:** publish deck JSON and speaker notes when ready (format above). Until then notes are empty.

## Next
1. Dispatch CI on `split/deck` (promptugal, macos-26, quick).
2. Fix compile errors, one run at a time.
3. One full run, then READY.

## PTExplore (summit app, 8 Nov)
- Data: one file, `api/v1/search-docs.json` (talks, speakers, companies, organisations; 468 KB), plus `api/v1/places.json` (labels only). A talk's day, times and place are read from its search line. No ContentSource seam exists on `dev` yet, so `PublishedExploreSource` fetches and caches on disk (injected `ExploreSource` protocol; swap later).
- Detail page: `api/v1/<events|people|companies|organisations|places>/<slug>.json`, read when an entry opens and cached. It shows facts and connections that link to other entries.
- Search: accent and case blind, every word must match, title matches rank first; kind picker (Talks, Speakers, Companies, Organisations, Places); talks grouped by Lisbon day.
- Screen for design: id `explore`, view `ExploreScreen()` (own NavigationStack, `ownsNavigation: true`), `import PTExplore`. apps: package reference and `PTExplore` in the promptugal packages list.
- Strings are plain SwiftUI literals, so i18n's catalogs pick them up.

### Built to ux spec v1 (split/ux cd11e67)
- Segments: Talks, Speakers, Companies, Places (organisations stay in the data and in search). Search at the top finds across all four, grouped. Speakers, companies and places are A to Z with letter sections.
- `ExploreScreen(hooks:)` takes optional views from the app, because they live in packages PTExplore cannot see: `talks` (design passes AgendaView), `talkDetail` (pick star, Add to Calendar), `header` (the graph card, only with 3 or more picks). With no hooks, PTExplore shows its own talks list and detail.
- Talk detail shows speakers from the talk's JSON; offline it says "Connect to load more".
- Not built: EXP-G (design's card, via `header`), the Now / My picks chips (they belong with AgendaView).
- Start destinations for screenshots: `ExploreScreen(hooks:, start:)` with `ExploreStart`: `explore` → `.talks`, `explore.people` → `.speakers`, `explore.talk` → `.talk(ref: nil)` (first talk of 10 Nov, or a given reference), `explore.graph` → `.graph` (pushes `ExploreHooks.graph`).
- Strings (i18n rule): every PTExplore string is `String(localized: "...", bundle: .module)` with the literal as the key; `Resources/Localizable.xcstrings` has the keys (empty, for i18n to fill); package has `defaultLocalization: "en"`. PTDeck is not localised yet (decks are not in the summit build).
