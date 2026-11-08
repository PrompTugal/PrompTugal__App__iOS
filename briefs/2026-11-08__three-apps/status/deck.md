# Status · Deck (decks and presenter mode)

> PTDeck is written and pushed on `split/deck`: model, loader (published JSON, with a fallback that reads the site's pages today), disk cache, deck list, reader, iPad presenter and external display. It has not compiled yet; CI run comes next. Two things wait on others: the Xcode package reference (apps) and the external-display scene entry (apps).

Branch: `split/deck` · Last update: 8 Nov, 10:50 UTC · Last CI run: none yet

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
