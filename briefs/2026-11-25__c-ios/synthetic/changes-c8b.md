# Changes in c8b / TestFlight 688: personas, journalist and reviewer first (c.ios.synthetic, 27 Nov 2026)

> Build: dev `6cc9ae2` (v0.4.128, TestFlight 688, = candidate c8b). Compared with 683 (`2403d92`): [changes-c7.md](changes-c7.md). Code plus live files on 27 Nov ~01:00 UTC. I re-ran the phone's signature check outside the app (same form-2 normalisation, P-256, fingerprints worked out from each key) on 14 live articles, and hash-checked 12 offline-edition files against the manifest.

## What changed versus 683

| Change | Where |
| --- | --- |
| **Article reader**: our own articles open in the app (title, date, author, summary, every cited source as a link, "How this was made", the signature checked on the phone); anything else still opens at its source | `PTPlaces/ArticleView.swift`, `ArticleModels.swift`, `StoryOpen` used on Home, Places, Since you last looked, town pages |
| **More > Offline edition**: saves the manifest's subset (articles, since.json, by-place index and the 19 Algarve/Portugal place files, newsletter), SHA-256 checked, Wi-Fi only after the first manual save | `PTLocal/Offline/*`, `Destinations.swift`, `PublicSettingsView.swift` |
| **More > Contribute or report a mistake** (a link to promptugal.news/contribute/) | `PublicSettingsView.swift` |
| News: no Interviews segment; header now "The latest from PrompTugal.news, the newsletter and the stories being made, every one with its sources." | `PTNews/NewsHomeView.swift:42` |

With this, **"independent" is gone from every screen** (only the unused `SupportLinks.independence` string remains in PTCore).

## What I verified live

- **Signatures check out.** 14 of 14 sampled articles verify (8 newest, 6 oldest in since.json). Every *recent* one is signed with `cl-6.journalist@PrompTugal.dinis`, whose key is `superseded`, so the phone will say "Signed with a key since handed over (cl-6.journalist@PrompTugal.dinis), checked on this device" on every new article. The older summit-era ones show "Signed by journalist@PrompTugal.dinis".
- **Offline hashes match.** 12 of 12 sampled files match the manifest (v0.1.2356); the edition is 161 files, about 3.6 MB.
- keys.json is 642 KB with 275 keys; the reader caches it for an hour (`ArticleView.swift:12-15`). Fine on Wi-Fi, heavy for P1 on poor signal at the first article.

## Findings

| # | Severity | Who | What | Where | Fix |
| --- | --- | --- | --- | --- | --- |
| F1 | **annoying, could be a reviewer question** | P1, P7 | **The offline edition promises more than the app reads.** The screen says "Save the last edition to read the articles, the towns and the newsletter with no connection", but only PTLocal's `LocalStore` reads the saved files (`LocalStore.swift:137-138`: town files for Ask, the Algarve maps, the newsroom). Home, Places, the article reader and News load from the network and their own caches; none asks `EditionFiles`. A reader who saves an edition, goes offline and taps an article gets "The article did not load". | `PTLocal/Offline/OfflineEditionView.swift` (line ~56 of the view's text), `PTPlaces/ArticleView.swift`, `PTPlaces/PlacesStore.swift` | Wire PTPlaces' feeds (since, index, place files, article records) to fall back to the edition through a hook set in `PlacesWiring`, or reword to what it does today ("the town pages for Ask and the maps"). |
| F2 | annoying | P3, P4, P7 | **"Contribute or report a mistake" lands on the wrong page.** promptugal.news/contribute/ is "Write for PrompTugal.news ... starting with Web Summit Lisbon, 10 to 12 November 2026": a call for contributors, summit-framed, with "Report a mistake" only as a footer link. The page for mistakes exists: https://promptugal.news/report/ ("Report a mistake or a concern ... in public, in private and encrypted, or by email ... the log of every correction"). | `Apps/PrompTugal/Shell/PublicSettingsView.swift` (the Link) | Two rows: "Report a mistake" to /report/, "Write for us" to /contribute/. Ask the site to drop the summit line from /contribute/. |
| F3 | annoying | P2, P8 | **"Handed over" on every new article, with an internal id.** True, but a journalist reads "signed with a key since handed over" on today's story as "something changed"; and `cl-6.journalist@...` exposes the account lane. | `ArticleView.swift:283` | Either the site re-signs current articles with an active key, or the wording says when: "Signed by cl-6.journalist (key superseded on <date>), checked on this device". Consider a display name in keys.json. |
| F4 | polish | P2 | Key status `current` (bulletins.b's key) falls to "the key is marked current in the key list" and reads as *not checked*. No article uses it today. | `ArticleModels.swift` (`check`, status switch) | Treat `current` like `active`. |
| F5 | polish | P2 | The panel says plainly that the key list comes from the same site as the article. Good and honest; the journalist will still want a second anchor (keys pinned in the app, or published elsewhere). | `ArticleView.swift:242` | Later: ship the active fingerprints in the bundle and say "matches the key built into the app". |
| F6 | polish | P5, P2 | Offline edition takes only the 19 Algarve and Portugal place files (`PlaceDirectory.all`), not the 17 district capitals Places now shows. Lisbon offline: empty. | `OfflineManifest.swift:28-33` | Use the by-place index's ids. |

## Per persona, briefly

- **P1 Graça:** can save an edition, but Home and Loulé's page still need the network (F1); first article costs a 642 KB key file on one bar.
- **P2 Rui:** the big win. Our articles open with their sources and a real on-device check that I could reproduce. Wants F3 and F5.
- **P3 Marta:** finally a route back, but it lands on a contributor page (F2).
- **P4 Tiago:** the contribute page is the right place for him; it still says "starting with Web Summit".
- **P5 Hannah:** no change for her town (events read 21 Nov, no weather).
- **P6 Sr. Joaquim:** still English only; c9 is the Portuguese one.
- **P7 reviewer:** no blocker. F1 is the most testable gap (turn on airplane mode after saving); F2 is a summit-flavoured page behind a support-style link.
- **P8 Sofia:** signed articles with "How this was made" are the clearest proof of the agents newsroom yet; F3 muddies it.

## Blocking

Nothing blocks TestFlight. Before an App Store submission of this version: F1 (reword or wire) and F2 (point at /report/).
