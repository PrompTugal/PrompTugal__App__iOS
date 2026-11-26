# Debrief: c.ios.explore, Explore rebuilt around the newsroom (25 Nov 2026)

> Worker of c.ios. Branch `work/c-explore`, based on `work/candidate-c2` (dev v0.4.123 plus the no-Talks change). Not compiled: there is no Mac here, so CI is the first compiler.

## What changed

- **New source** `NewsroomExploreSource` (`Packages/PTExplore/Sources/PTExplore/NewsroomSource.swift`) reads five files, all checked with curl on 25 Nov:
  - `promptugal.news/api/v1/articles.json` (96 articles: id, title, date, author, town, sources count, page) → **Stories**
  - `promptugal.news/api/v1/companies.json` (115) and `/places.json` (107) → **Companies**, **Places**
  - `library.promptugal.news/api/v1/items/index.json` (82) and `videos.promptugal.news/api/v1/videos/index.json` (32) → **Library**. A library item that is the same YouTube video as a videos-site entry shows once, as the video: 51 + 32 = 83 entries. The videos index has no `url`, so the YouTube address is made from the id (`yt-<id>`).
  - `stories.json` (136) was not used: those are desk records with `page: null`; the 96 articles are the published stories with pages and sources.
- **Decoding** is lenient (`JSONSerialization`, an entry without id or title is skipped, a broken file gives no entries).
- **Provenance**: each file is read live, else this device's copy, else the built-in copy (the same five files, taken 25 Nov, in `Resources/newsroom-*.json`, about 160 KB). The worst of the five sets the line under the segments: "Live from PrompTugal.news", "Offline: the last copy this device read" or "Built-in copy of 25 Nov 2026: connect to update". Detail screens carry the same line (the summit source now reports its origin too). An error page never replaces a good copy.
- **Detail**: a story opens its record (`api/v1/articles/<id>.json`): summary, date, by, town, and a **Sources** section with every source link, plus "Open on promptugal.news". Companies and places use the existing graph records (companies now also list their sources). Library items and videos need no fetch: facts from the list, "Watch on YouTube" or "Open the original", and "Open on library.promptugal.news" / "videos.promptugal.news".
- **Summit gone** (Dinis, 25 Nov ~23:35, "move away"): no summit row, no summit index, no `ExploreStart.summit`; company details no longer show "At the summit as". Each list ends with "The newsroom's graph" (PTNews `GraphExplorerView`, the whole newsroom graph). `TalkDetailView`, `TalkRef`, `TalkActions` and the older `search-docs.json` reader stay in the package only because the shell's My program and Now open the shared talk detail; Explore no longer uses them.
- **ExploreView** (shell): uses `ExploreStore.newsroom()`, `showsGraphRow: true`; the "Explore the summit graph" card, the Talks agenda hook, the talk actions and the talk sheet are gone.
- `ExploreStart` gained `.stories` and `.library`. Starts that point at kinds the newsroom does not have (`.speakers`, `.talk`) open on Stories.
- Strings: 27 new keys, English and pt-PT only; the other 14 languages fall back to English.

## Tests

`NewsroomTests.swift`: decoders per file, dedupe, leniency, article record and sources, newest-first order, search across kinds, the newsroom store and hidden empty segments, live / cached / built-in / mixed origins, error page, the bundled copy decodes, library detail without fetch. The existing summit tests are unchanged.

## Open items for the conductor

1. **Destinations.swift** (conductor, at merge): `"explore"` → `.stories`, plus `"explore.stories"` and `"explore.library"`. `"explore.talk"` and `"explore.people"` now just open Stories.
2. Third-party titles and publishers stay as their sources publish them (conductor, 25 Nov: quoting, with the source link).
3. Translations for the other 14 languages (English and pt-PT are enough for now).
4. The built-in copy is dated 25 Nov; refresh the five files before a release if it matters.
