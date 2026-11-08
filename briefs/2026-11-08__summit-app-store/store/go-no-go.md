# Go / no-go before submission

> Checked by review.B against the exact build number to be submitted, once for the TestFlight public link (Beta App Review) and once for the App Store version. Every line must be **GO**, or the conductor writes down why it is accepted. Release and testflight do not submit until review sends "GO <build>" to the conductor.

**Build:** `0.4.x (n)` · **Commit:** `…` · **Checked at:** `hh:mm UTC` · **Result:** pending

## Binary

| # | Check | How | State |
| --- | --- | --- | --- |
| G1 | The upload passed processing: no ITMS-90683 (purpose strings) and no ITMS-91053 (privacy manifests) | App Store Connect build status "Ready to Submit"; testflight's `tf.py status` | pending |
| G2 | The built Info.plist has NSCameraUsageDescription, NSFaceIDUsageDescription, NSCalendarsWriteOnlyAccessUsageDescription, NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription | `plutil -p` on the archive's Info.plist (release) | pending |
| G3 | Release build: no Debug screen, no debug switch, no launch arguments | `#if DEBUG` in Destinations, PublicSettingsView, PublicShell (checked at 11:30 on dev) | pending |
| G4 | Cold launch with no network: the agenda and My day show content within 10 s; no spinner forever and no raw error text | release, on a simulator in airplane mode | pending |
| G5 | Full CI run green on iPhone and iPad for this commit | the run's link | pending |
| G6 | Ask: a working demo key in the notes, **or** Ask is absent from the Release build (B1) | the screen list in the build, plus the secret set | pending |
| G7 | Vault: absent, **or** a working demo key (B2) | as above | pending |
| G8 | No "Web Summit" on any screen that screenshots show (B3), and no `ShortcutWebSummit` or `web-summit.sgit.ai` in the public app (R1) | `git grep -i "web summit"` in PTAgenda AgendaView, plus the screenshots themselves | pending |
| G9 | The Settings footer shows the non-affiliation note | the `pt.notAffiliated` screenshot or UI test | pending |

## Metadata

| # | Check | State |
| --- | --- | --- |
| M1 | Name "PrompTugal: Lisbon Summit"; subtitle, keywords and promotional text match [listing-en.md](listing-en.md), [listing-pt-PT.md](listing-pt-PT.md) and [listing-pt-BR.md](listing-pt-BR.md) | pending |
| M2 | Every line marked "only if merged" (Ask, Languages, Now, Explore) was removed unless that feature is in this build | pending |
| M3 | The pt-PT and pt-BR listings exist only if the app has those localizations. A Portuguese store page with an English-only app is allowed, but then delete the Languages line. | pending |
| M4 | Screenshots: 6.9", 6.5" and iPad 13". Native screens only, no event name or logo, no status bar with a carrier name, real content (not placeholder) | pending |
| M5 | The support, marketing and privacy URLs answer 200. The privacy page describes the public app (R3), and the support page has a contact method. | pending |
| M6 | The App Privacy answers match [app-privacy.md](app-privacy.md) for this build (with or without Ask), and agree with `PrivacyInfo.xcprivacy`. The [network audit](network-audit.md) recheck finds only promptugal.news and openrouter.ai, with N1 to N3 done. | pending |
| M7 | Age rating answered as in [age-rating.md](age-rating.md) (4+). "Unrestricted web access" is No, and R1 is fixed. | pending |
| M8 | The review notes are [review-notes.md](review-notes.md), with only the paragraphs for this build. Contact name, email and phone are set. | pending |
| M9 | Price free; availability all regions; "Manually release"; Mac and Vision Pro availability unticked | pending |
| M10 | What's new and the TestFlight "what to test" texts are set in all three languages | pending |

## People

| # | Check | State |
| --- | --- | --- |
| P1 | No open finding with severity "stuck" from the persona walk-through of this build ([status/review.md](../../2026-11-08__three-apps/status/review.md)) | pending |
| P2 | The conductor's go recorded for this submission | pending |

## Run 1: summit candidate `split/rc2` 3de45dd (12:40 UTC): NO-GO, two blockers

| # | Check | State |
| --- | --- | --- |
| G2 | All five purpose strings are in the project; pt-PT and pt-BR exist for camera, Face ID and calendar, but not for microphone or speech | GO (risk: pt text missing for 2 strings, i18n) |
| G3 | Vault, All websites and Debug are `#if DEBUG` only | GO |
| G6 | Ask is reachable from the Now card and from Settings > "Ask, with your own AI key"; the review key is in the notes | GO |
| G7 | Vault absent in Release | GO |
| G8 | "Web Summit" appears only in the independence footer (a disclaimer) and in Safari link URLs; WebsitesPublic.json; the ShortcutWebSummit asset is removed | GO |
| M6 | Native hosts are promptugal.news and openrouter.ai; cookies off; PrivacyInfo declares OtherUserContent | **NO-GO**: N4, `WebPage` loads linked sites in the app (team) |
| M8 | Review notes in the build's `scripts/testflight/` | **NO-GO**: rc2 has editor's old notes and the old What to Test ("PrompTugal for Web Summit Lisbon"). Copy store/review-notes.txt and store/what-to-test.txt over them (testflight). |
| N2 | Vault background task still registered | risk (apps) |
| G1, G4, G5, M1–M5, M7, M9, M10, P1, P2 | Need the build, screenshots and App Store Connect | pending |

## Run 2: `split/rc3` 98767dd (12:40 UTC): GO on everything checkable in the repository

| # | Check | State |
| --- | --- | --- |
| M6, N4 | `WebPage` sends other sites to Safari (team ae618cf, with tests); native hosts are promptugal.news and openrouter.ai; cookies off; PrivacyInfo declares OtherUserContent | GO |
| M8 | `scripts/testflight/review-notes.txt` and `what-to-test.txt` are byte-identical to store/ (testflight a11b10f); no "Web Summit" in What to Test | GO |
| G2 | All five purpose strings, each in en, pt-PT and pt-BR (i18n b009f5e); the pt texts read correctly | GO |
| G3, G6, G7, G8 | Same as run 1; the only other code change is `@MainActor` in `TalkScreens.swift` (a fix for the Release build) | GO |
| N2 | Vault background task | accepted for this version |
| G5 | Full run 391 (id 42480839902) on 98767dd | **pending**: queued at 12:33 |
| G1, G4, M1–M5, M7, M9, M10, P1 | The uploaded build's processing, a cold launch offline, screenshots, the App Store Connect entries, the persona pass on the screenshots | pending: on the build and on release's plan |
| P2 | The conductor's go | pending |

**Verdict:** rc3 can be submitted once run 391 is green, the upload passes processing, and release's screenshots pass G8 and M4.

## Run 3: `split/rc4` ce58c5e, the delta from rc3 (12:45 UTC)

| # | Check | State |
| --- | --- | --- |
| G4 | Offline first launch: `agenda-seed.json` (201 items) ships in the synced Resources group, but `AgendaHub.seedAgenda` is never assigned (`AgendaSources.swift:133` default `{ [] }`; `AgendaSeed` in `PrompTugalApp.swift:49` is unused). So the agenda is still empty offline on first launch. | **must-fix** (apps): `AgendaHub.seedAgenda = { AgendaSeed.events() }` in `PrompTugalApp.init()` |
| G8, M4 | Program titles in the seed and the live feed contain "Web Summit" (9 items, for example the Registration row that Now shows first). Allowed in the app, not in screenshots. | risk (release): choose screenshot states without these rows |
| Localization sweep (i18n 5e4ef2b) | `String(localized:bundle: .module)` in AgendaView, ShellParts, PTAgenda and PTNews; catalogs extended | GO |
| Hosts, WebPage, notes, purpose strings | Unchanged since rc3 | GO |
| G5 | Full run 42481029792 on ce58c5e | pending |

## Run 4: `split/rc4` d8a5020 (12:50 UTC): GO on everything checkable in the repository

| # | Check | State |
| --- | --- | --- |
| G4 | `AgendaHub.seedAgenda = { AgendaSeed.events() }` is set in `PrompTugalApp.init()`, before `ReaderStore` is created. The seed's shape (`items` of date, time, title, place, kind, official, page) matches the live `AgendaFeed`, so it decodes the same way. Still needs one airplane-mode fresh install on the build. | GO in code |
| N2 | The vault background task is now `#if DEBUG` only (in rc4) | done |
| Everything else | As in runs 2 and 3 | GO |
| G5 | Full run 393 (42481160021) on d8a5020 | pending (started 12:37) |
| G1, M1–M10, P1, P2 | Processing, screenshots (watch the "Web Summit" program titles), App Store Connect entries, the conductor's go | pending |

## Run 5: `split/rc5` bea15bb, release's screenshot pipeline and App Store Connect plan (13:00 UTC)

rc5 is rc4 plus release's screenshot filter (`-PTHideTerm`, DEBUG only, a no-op in Release, with tests) and a seed decode test. The app code a user runs is the same as rc4 d8a5020.

| # | Check | State |
| --- | --- | --- |
| M4, 2.3.3 | `screens.yml` builds the **Debug** configuration, where `DebugMode.defaultOn` is true (`PTCore/Design/Components.swift:293`). Every screen therefore gets the native, web or hybrid badge in its toolbar (`surfaceKind`, `PublicShell.swift:91`, `:151`, `:228`). The iPad sidebar lists **Debug**, and also **Vault** and **All websites**, because `debugOnlyScreens` exist in every DEBUG build and are not marked `debugOnly`. Store images would show screens and badges that are not in the submitted build. | **must-fix before screenshots**: (1) the screens test adds `-debug.enabled NO` (a UserDefaults launch argument; DebugMode reads that key); (2) design marks Vault and All websites `debugOnly: true`, so the switch hides them too. Then check one iPad image for the sidebar. (release, design) |
| M4 | `-PTHideTerm "Web Summit"` drops program rows and news that contain the term, only in DEBUG. The images show real content minus a few rows, which is acceptable under 2.3.3. | GO |
| Content rights (ASC plan step 10) | The plan says "no third-party content". The app shows the summit's public program (third-party content, republished by our newsroom), and Ask shows answers from third-party AI models. | **change**: answer `USES_THIRD_PARTY_CONTENT` (and that we have the rights to show it) (release) |
| ASC plan steps 5, 6, 13 | They read review's files. The files to read are `store/listing-*.md` (the fenced blocks), `store/review-notes.txt` and `store/what-to-test.txt`. The Ask and Languages lines now stay in all three languages, because Ask ships and the pt-PT and pt-BR strings are in the build. | GO |
| ASC plan step 9 | Answers as in [age-rating.md](age-rating.md). "Unrestricted web access: No" is now true (N4 fixed). | GO |
| ASC plan step 15 | Advertising identifier: **No** (the app reads no IDFA). Any "uses encryption" prompt: no, already in the build. | answer ready |
| Availability | The plan has no step for Mac (Apple silicon) and Vision Pro availability. [age-rating.md](age-rating.md) says untick both. | add a step (by hand if the API has none) (release) |
| G5 | Run 393 on rc4 d8a5020 | check |
