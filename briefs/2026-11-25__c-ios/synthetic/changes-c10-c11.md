# Changes in c10 (TestFlight 693) and c11 (0.4.131): all personas, en-GB and pt-PT (c.ios.synthetic, 27 Nov 2026)

> Builds: c10 = dev `a5c930d` (v0.4.130, TestFlight 693); c11 = dev `f5f3103` (0.4.131, building). Compared with c9 (`01cacd8`): [changes-c9.md](changes-c9.md). Code, the 14 String Catalogs (re-audited by script on c11), and live files on 27 Nov ~02:45 UTC.

## c10: what changed and how it lands

| Change | Where | Verdict |
| --- | --- | --- |
| **Report a mistake** to https://promptugal.news/report/ and **Write for us** to /contribute/, two rows in More | `Apps/PrompTugal/Shell/PublicSettingsView.swift` | c8b **F2 fixed**. P3 and P4 each land on the right page. |
| **Offline fallback** for Home, Places, town pages and our articles from the saved edition (via `placesOfflineData`, set once in the shell); screens then say "This device's offline copy"; the edition now holds every place in the by-place index (about 4 MB) | `PTPlaces/PlacesOffline.swift`, `PlacesStore.swift`, `ArticleView.swift`, `PublicShell.swift:59`, `PTLocal/Offline/OfflineManifest.swift` | c8b **F1 and F6 fixed**, and the screen's text now says exactly that: "The newsletter and the News tab still need a connection". |
| **Story ages** on Home and town items; **Home by date** with "Earlier"; My towns says "No new local stories since <day>" | `PortugalHomeView.swift`, `MyTowns.swift`, `LocalFrame.swift` | Good for P1 and P2: an item from 17 Nov now looks 10 days old, not like today's news. |
| **No green "Live" pill** on town sites; only "Researching" shows | `PlaceVisuals.swift` | S3 finally closed. |
| "Signed with an earlier key of <agent>, still valid, checked on this device" | `ArticleView.swift` | c8b **F3 wording fixed**; the internal id `cl-6.journalist@...` still shows. |
| Alert pacing (new stories batched; first check notes only) | `PTLocal/Alerts/AlertsCenter.swift` | Fine. |

Remaining after c10: offline still needs one manual save, so **a first install with no signal still shows nothing** (S5, P1). An article read offline shows its record but "Signature not checked: the signature file did not load", since the edition carries no `.md`, `.sig` or keys. Accurate, but P2 will ask; consider adding the twin, signature and keys file (642 KB) to the edition.

## c11: what changed and how it lands

| Change | Where | Verdict |
| --- | --- | --- |
| **Location prompt in pt-PT**, and no longer "Algarve town": "O PrompTugal.news usa a sua localização só enquanto usa a app e só quando toca em Perto de mim, para encontrar a terra mais próxima..." | `Info.plist`, `Resources/InfoPlist.xcstrings` | c9 **P1 fixed**. Good European Portuguese. |
| **VoiceOver language marking**: English headlines, sources and untranslated prose use `Text(english:)` (AttributedString `languageIdentifier = "en"`); PTLocal has `Text(content:language:)` for the agendas' Portuguese | `PTPlaces/PlacesTranslation.swift`, `PTLocal/LocalText.swift`; used in Home, Since you last looked, town pages, Places, ArticleView, newsroom, town layers | c9 **P3 fixed** on the Places side. |
| **Article title and summary from the translation memory** with the machine-translation note, else "O artigo está em inglês" | `ArticleView.swift` (`languageNote`) | c9 **P2 partly**: titles in memory for 6 of the 10 articles I checked (the 6 Atomico/COCUS/Reach/Smartex/Priberam pieces); missing for the newest ("ai-use-in-portugal-2026", "five-coding-agents-...") and the summit-era ones. The body stays English with the site link. |
| **Dates in the app's locale** for PTLocal ("21 nov.") | `PTLocal/Freshness.swift` | c9 **P4 fixed**. |
| **Shards**: each fetched once per launch, kept a week, six at a time | `PlacesTranslation.swift` | c9 **P6 fixed** in practice: the second visit costs nothing. |
| **Dynamic Type** for the article title and place hero (`.largeTitle`/`.title` serif) | `ArticleView.swift`, `PlaceDetailView.swift` | c9 **P7 partly**: those grow now. 17 fixed sizes remain, mostly map labels and pins (fine) and the 140 pt decorative numeral on Places (`PlacesHomeView.swift:456`). |
| Catalogue fixes: "Done" is "OK" in PTPlaces/PTLocal and "Concluído" in the app; "Build" is "Compilação"; "você reporta" gone | catalogues | c9 **P5 mostly fixed**. |
| PTLocal follows `AppCulture` (not the bundle's preferred localisation), English via a missing table so the key returns | `PTLocal/LocalText.swift` | Works: PTLocal's catalogue has no English entries or plural variations that the missing table could lose. Keep it that way, or the English path will silently drop them. |

Audit on c11: **0 keys missing pt-PT in all 14 catalogues**; no Brazilian forms; no gerunds; format specifiers only differ by position numbers.

## What is left, by persona

- **P6 Sr. Joaquim (pt, XL, VoiceOver): from annoying to mostly fine.** Portuguese chrome, Portuguese place prose, English headlines read in an English voice, translated titles on most of our articles. Remaining:
  - Headlines on **Now's Latest news** and the **News tab** are plain `Text(story.title)`, not marked English, so VoiceOver still reads them in the Portuguese voice (`Apps/PrompTugal/Shell/NowView.swift:403`, `Packages/PTNews/Sources/PTNews/NewsHomeView.swift:107`). Use `Text(english:)` there too.
  - Headlines on Home are English (marked), while the same story opened in the reader has a Portuguese title from the memory. Using the memory for list headlines too would make it consistent.
  - "Report a mistake" and "Write for us" open English-only pages on the site.
- **P1 Graça (pt or en, SE, poor signal):** ages and "No new local stories since" are honest; offline works after one save on Wi-Fi. First launch offline still empty.
- **P2 Rui (en):** "earlier key, still valid" reads right; the agent id is still the internal `cl-6.journalist@PrompTugal.dinis`. Offline articles say the signature was not checked (above).
- **P3 Marta (pt):** "Reportar um erro" reaches /report/ directly. "Comunicar um erro" would be more natural European Portuguese ("reportar" is an anglicism, though common).
- **P4 Tiago:** "Escreva para nós" reaches /contribute/, which still opens "starting with Web Summit Lisbon": a site fix.
- **P5 Hannah (en):** unchanged for Lagos (events read 21 Nov, no weather on the page).
- **P7 reviewer:** no blocker in c10 or c11. The More header and the iPad sidebar still say `Text(verbatim: "PrompTugal.news · the Algarve")` in both languages (`PublicSettingsView.swift:22`, `PublicShell.swift`), though the app covers all of Portugal. The summit widget remains.
- **P8 Sofia (en):** unchanged.

## Small Portuguese notes on c11

- PTLocal still has "Orange" as "laranja" in lower case (PTPlaces fixed it to "Laranja").
- "Edição offline" is understood, but "Edição para ler sem rede" or "Edição guardada" reads more naturally in pt-PT.
- "Perguntar e resumir" is literal; "Perguntar e resumir com IA" or "Resumos no dispositivo" says what it does.

## Blocking

Nothing blocks TestFlight or an App Store submission of c11 that I can find. Before submitting: decide the widget, and change "PrompTugal.news · the Algarve".

## Follow-up check: work/c-ios `fed761c` (27 Nov ~02:40 UTC)

Verified in the diff: Now's Latest news (`NowView.swift`, `englishHeadline`) and the News tab lead and list (`NewsHomeView.swift`, `newsEnglish`) now mark headlines `languageIdentifier = "en"`; the More header and the iPad sidebar read "PrompTugal.news · Portugal". Those two items are closed. The PTLocal "laranja" fix (`42782c2`) is not re-checked here.
