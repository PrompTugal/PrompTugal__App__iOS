# Changes in c9 / TestFlight 692: Portuguese and alerts (c.ios.synthetic, 27 Nov 2026)

> Build: dev `01cacd8` (v0.4.129, TestFlight 692, = candidate c9). Compared with 688 (`6cc9ae2`): [changes-c8b.md](changes-c8b.md). Walked in pt-PT and en from the code, the 14 String Catalogs the app links, and the live translation memory. Method: a script checked every catalogue for missing pt-PT, untranslated values, Brazilian forms, gerunds and format specifiers, and that every UI literal in PTPlaces, PTLocal and PTNews reaches a catalogue through `bundle: .module`; I then read about 70 random pairs and computed the translation-memory keys (the app's normalisation, SHA-256, first 16 hex) for Tavira, Loulé, Lagos and Faro.

## What changed versus 688

| Change | Where |
| --- | --- |
| **The app follows the device**: any pt* preferred language gives pt-PT, else en-GB; only en, en-GB and pt-PT are declared (so the store will list two languages; E1 closed) | `PTCore/Culture/AppCulture.swift:30-90`, `Info.plist` CFBundleLocalizations |
| **Portuguese catalogues** for PTPlaces (226 keys) and PTLocal (565), and the app, PTNews, PTCore, PTAgenda, PTExplore, PTWeb, widget and intents: **0 keys missing pt-PT** in all 14 | `*/Resources/Localizable.xcstrings` |
| **Place prose in Portuguese** (mandate, centre of gravity, story summaries) from the site's translation memory, marked as machine translation with the English one tap away; headlines and articles stay as published | `PTPlaces/PlacesTranslation.swift`, `PlaceDetailView.swift:130,211,249,310,615` |
| **More > Alerts**: opt-in local notifications (new stories in followed towns; IPMA yellow/orange/red warnings for their districts); permission asked when a switch is turned on; first check only notes what is there | `PTLocal/Alerts/*` |
| Privacy page covers alerts, the offline edition and language | https://ios.app.promptugal.news/privacy.html |

## The Portuguese, checked

**Good.** It is European Portuguese throughout: ficheiro, ligação, registo, fotografia, ecrã-free phrasing, "está a ler", "câmara", "terra a terra" for "town by town", AO90 spelling (setor, atividade). No "tela", "celular", "arquivo", "usuário" or gerund forms anywhere. IPMA warning levels are translated before they go into alerts ("IPMA: aviso amarelo, distrito de Faro"). Every PTPlaces/PTLocal/PTNews literal reaches its own catalogue (only "PrompTugal.news", "Portugal" and "24 h" are untranslated, rightly). Translation memory coverage is complete for the four towns I computed: **Tavira 6/6, Loulé 15/15, Lagos 5/5, Faro 30/30** segments, and the Portuguese reads naturally.

| # | Severity | What | Where | Fix |
| --- | --- | --- | --- | --- |
| P1 | **annoying (P6)** | **The location prompt is in English.** `NSLocationWhenInUseUsageDescription` is a literal in Info.plist and is not in `InfoPlist.xcstrings`, which holds only CFBundleDisplayName and the calendar string. A Portuguese reader tapping Near me gets the one system dialog of the app in English, and it still says "the nearest Algarve town". | `Apps/PrompTugal/Info.plist`, `Apps/PrompTugal/Resources/InfoPlist.xcstrings` | Add the key with pt-PT (e.g. "O PrompTugal usa a sua localização, só enquanto usa a app e só quando toca em Perto de mim, para encontrar a localidade mais próxima e mostrar primeiro as suas notícias. A localização fica neste dispositivo."); drop "Algarve" now that Places covers the capitals. Remove the unused camera, microphone and speech strings at the same time. |
| P2 | **annoying (P6)** | **Headlines and articles stay English**, by design. On Home and Places every title is English under Portuguese chrome; the article reader shows the English article though the site publishes Portuguese versions of some (`article-i18n`, 21 files in the manifest). | `PlacesTranslation.swift` header comment; `ArticleView.swift` | Use the site's article translations when present (with the same machine-translation note), and run headlines through the memory like summaries. |
| P3 | annoying (P6, VoiceOver) | **English text is spoken with the Portuguese voice.** Nothing marks English headlines, the "see the English" text or untranslated prose with a speech language, so VoiceOver in pt-PT reads English with Portuguese phonetics. | no `accessibilitySpeechLanguage` / `languageIdentifier` in PTPlaces, PTLocal, PTNews | Build those Texts from an AttributedString with `languageIdentifier = "en"` (or `.accessibilitySpeechLanguage`). |
| P4 | polish | PTLocal's freshness lines format dates with `en_GB`: "Instantâneo, lido a 21 Nov" instead of "21 nov.". PTPlaces does it right (`PlacesLanguage.locale`). | `PTLocal/Freshness.swift:49,60` | Use the app's locale. |
| P5 | polish | "Done" is "Feito"; iOS in pt-PT says "OK" (or "Concluído"). "Build" and "Version" both become "Versão". "Orange" becomes "laranja" in lower case while the other picker values are capitalised. "você reporta" in "Work with us" (now off Places home, still in the catalogue) reads Brazilian; pt-PT omits the pronoun. | PTLocal and app catalogues | Small catalogue edits. |
| P6 | polish (P1 on poor signal) | The memory is fetched one 2-hex shard per segment, about 2.4 KB each: Faro's page asks for about 26 shards, Loulé's 13. On one bar the prose shows in English first and switches. | `PlacesTranslation.swift:91-122` | Prefetch the shards for followed towns with the offline edition, or have the site publish a per-place pt-PT file. |
| P7 | polish | Fixed-size titles still ignore Dynamic Type, now also the article title (`ArticleView.swift:139`, 28/40 pt) and the place hero (`PlaceDetailView.swift:160`, 56/84 pt). At Accessibility XL these are the only text that does not grow. | 14 `.system(size:)` in PTPlaces | `.font(.system(.largeTitle, design: .serif, weight: .black))` with `.minimumScaleFactor` where space is tight. |

## Per persona

- **P6 Sr. Joaquim (pt, XL, VoiceOver): from stuck to annoying.** The app now opens in Portuguese on his phone with no setting to find; the Tavira page's mandate, centre of gravity and story summaries are in good Portuguese, marked as machine translation; events were already Portuguese. What remains: English headlines and articles (P2) read in a Portuguese voice (P3), the English location prompt (P1), and titles that do not grow (P7).
- **P1 Graça:** Portuguese UI if her phone is Portuguese. Alerts for Loulé would suit her, but IPMA warnings are by district (Faro) and new-story alerts depend on since.json, whose newest Loulé item is from 21 Nov. Translation shards add round trips on poor signal (P6).
- **P2 Rui (en):** no change in English. Privacy page now describes alerts and language accurately.
- **P3 Marta (pt):** her council's page reads in Portuguese, with the machine-translation note: good for checking what is said about her council; the report-a-mistake link (F2 in c8b) still goes to /contribute/.
- **P4, P8 (en):** unchanged.
- **P5 Hannah (en, Lagos):** IPMA warning alerts are useful to a tourist; Lagos is in the Faro district, so she gets Algarve-wide warnings. Fine.
- **P7 reviewer:** E1 closed (two languages declared and both work). Alerts ask for notification permission only on a switch, and privacy.html says so. Two things a reviewer in Portugal could notice: the English location prompt (P1), and the summit widget, which is now in Portuguese ("Sem sessões a seguir") but still about sessions. c8b's F1 (offline edition wording) and F2 (mistake link) are not in 692.

## Blocking

Nothing blocks TestFlight. For an App Store submission of this version: P1 (location prompt) and c8b's F1 and F2.
