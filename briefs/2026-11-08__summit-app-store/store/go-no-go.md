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

## Run 6: the binary is rc4 d8a5020, the screenshots come from rc5 706b153 (13:05 UTC)

The conductor's decision: the binary is **rc4 d8a5020**. rc5 differs from it only in DEBUG code, test code and the ReaderStore pass-through, which is a no-op in Release. The screenshots are taken from **rc5 706b153**.

| # | Check | State |
| --- | --- | --- |
| M4 | 706b153: the screens test passes `-debug.enabled NO` (the `DebugMode.key` UserDefaults key, read by `@AppStorage`), so there are no toolbar badges and no Debug row. Vault and All websites are `debugOnly: true`, so the same switch hides them. In a Release binary they do not exist at all (`#if DEBUG`). | GO in code; one iPad sidebar image to check when screens run on 706b153 |
| M4 | `-PTSampleData` is ignored by the public app (no sample source), so the images show the real program from promptugal.news, minus the rows that contain "Web Summit" | GO |
| Binary | rc4 d8a5020: runs 2 to 4 GO; no user-visible difference from rc5 | GO in the repository |
| G5 | Run 393 on d8a5020 | **queued at 13:05** (not started) |
| G1, G4 | Processing; a fresh install in airplane mode on the uploaded build | pending |
| M1–M10 | release applies the ASC corrections (content rights, IDFA No, Mac and Vision Pro unticked, texts from store/) | pending: check release's dry-run output |

## Run 7: binary rc4 56a630e, screenshots rc5 3e6cd9f (13:16 UTC)

| # | Check | State |
| --- | --- | --- |
| Binary | `git diff d8a5020 56a630e -- Apps Packages` touches only `PTExploreTests`, `PTWebTests` and the PTExplore **test target's** dependency in `Package.swift`. The product code is byte-identical to d8a5020, so runs 2 to 6 still apply. | GO in the repository |
| G5 | Run 393: every app build and app test green; two package test targets did not compile (fixed in 56a630e). Run 394 (42484035275) on 56a630e: pending at 13:16. | pending |
| Screenshots | rc5 3e6cd9f = 706b153 plus rc4's test fixes | as run 6 |

## Run 8: status at 13:58 UTC

| # | Check | State |
| --- | --- | --- |
| G5 | Run 394 on rc4 56a630e: 22 of 28 jobs green, including the PrompTugal Release build, the Debug build, and the unit tests on iPhone and iPad. PTVaultUI, PTNews, PTAsk, PTWeb and PTAgenda package tests are running; nothing has failed. | in progress |
| ASC plan | release.md on rc5 7766e2a has review's corrections: content rights `USES_THIRD_PARTY_CONTENT`, IDFA No, Mac and Vision Pro availability unticked by hand (15b), texts from store/. | GO (plan) |
| ASC dry run | Not run yet | pending |
| M4 | Screens on rc5: not run yet. release.md plans about 15:40 on dev. | pending (see note) |

Note: screenshots at 15:40 plus about 25 minutes leaves little room before the 16:00 freeze, if an image needs a fix. Run `screens.yml` on rc5 7766e2a now. It has the debug-off fix and the `hide_term` filter, and its product code matches the binary.

## Run 9: screenshots, screens #34 on rc5 7766e2a (14:05 UTC): NO-GO

Artifact `appstore-screens-7766e2a…-promptugal`: 63 images (7 screens, 3 sizes, en-US, pt-PT, pt-BR).

| # | Finding | Owner | State |
| --- | --- | --- | --- |
| S1 | The system alert "PrompTugal Would Like to Send You Notifications" covers 60 of 63 images. Only en-US `01-now` (3 sizes) is clean. | team (product), release (test) | **blocker** |
| S1a | Cause in the product: `MyProgramView.swift:84-86` asks for notification permission in `.task(id: picksOn)` (`picksOn` is true by default) whenever My program is built, with no tap. The TabView builds it at launch. That contradicts the review notes, the privacy page and `askOnceWhenUseful` (ask on the first pick). | team | **fix in the binary**: keep `currentAuthorization()` and `reschedule()`, drop `requestAuthorization()` |
| S1b | Cause in the test: `-PTSeedPicks` fires `askOnceWhenUseful`. ScreensTests must tap the springboard's **Allow** before each screenshot. | release | fix |
| S2 | The en-US 12-hour time column wraps ("11:05 A" / "M") on Now, iPhone and iPad | design | fix: `lineLimit(1)` and a wider column, or 24-hour Lisbon time |
| S3 | iPad sidebar: Now, My program, Explore, News; More: Ask, Settings, Reminders. No Vault, All websites, Debug or badges. | | GO |
| S4 | No "Web Summit" in the clean images | | GO so far (pt not visible) |
| S5 | pt-PT and pt-BR UI language: cannot be checked, because every pt image is covered | | pending the re-run |

Review notes step 4 now says the permission is asked on the first pick or from the Reminders toggle (store/review-notes.txt). testflight copies it again.

## Run 10: submission candidate `split/rc7` 7f961a0 (14:08 UTC): GO in the repository

The delta from rc4 56a630e is the rc5 parts already passed (screenshot filter, debug-off, `debugOnly` rows, ScreensTests alert dismissal), plus:

| # | Check | State |
| --- | --- | --- |
| S1a | `MyProgramView` `.task(id: picksOn)` no longer asks for notification permission; it only reads the authorization and reschedules. Permission is now asked in three places: the "Remind me before each talk" toggle when switched on (a tap), the first pick (`askOnceWhenUseful`, a tap), and the web bridge's native "Turn on reminders?" alert (a tap). That matches review-notes step 4 and the privacy page. | GO |
| S2 | Now's time column is as wide as a hidden "88:88 AM" (`lineLimit(1)`, `fixedSize`), so the time never wraps and the rows line up | GO in code; check in the next screens run (other screens' time columns too) |
| Tests | `@MainActor` on `WebPageHostTests` (test only) | GO |
| G5 | Full run 396 (42487965688) | pending |
| M4 | Screens on rc7, with the alert answered "Allow" | pending, then the full image and persona pass |

rc7 moved to **0279acc** (14:06): the only change from 7f961a0 is `Packages/PTAgenda/Tests/PTAgendaTests/PickTests.swift` (`@MainActor`, test only). Run 10 holds. The full run is now 397 (42488067819).

rc7 moved to **535e9ba** (14:17), the last product change before the freeze. `PTExplore/ExploreScreens.swift` row time: `lineLimit(1)`, `fixedSize()` and `minWidth: 64` replace the fixed 64 pt width. Layout only, so time ranges and 12-hour times no longer wrap. Run 10 holds; check Explore rows in the next screens run. The full run is now 398 (42488960402).

## Run 11: metadata against rc7 535e9ba (14:35 UTC)

| # | Check | State |
| --- | --- | --- |
| M2 | The descriptions promised "Plan my day … walking times" and named "My day". rc7 has no planner in the public app (PlannerView is reachable only from the Team app's MyDayView), and the tab is My program. The three descriptions and the pt What to Test lines now say My program, time order, clashes marked and free time, and search across talks, speakers, companies and places, which matches ExploreScreens' search prompt. | fixed in store/ |
| M1 | `store/listing.json`: the three locales with ASC field names, generated and checked (limits, keyword bytes, no markers, no trademark) | GO, for release |
| G5 | Run 398 on 535e9ba: queued (the runners are busy with screens #36) | pending |
| M4 | Screens #36 on rc7 535e9ba: three size jobs in progress | pending |
| ASC dry run | No output yet in release.md | pending |

## Run 12: release's ASC dry run (run 42490544114, 14:36 UTC)

| # | Finding (from the real record) | Decision | Owner |
| --- | --- | --- | --- |
| A1 | The primary locale is **en-GB**, the record's only localization | Keep en-GB as primary (it holds the existing name). `listing.json` now has **en-GB** with the same English text as en-US ("program" kept, because "programme" pushes the subtitle to 31). Keep en-US too, for the US storefront. Screenshots: en-GB reuses the en-US set. | review (done), release |
| A2 | The App Store version is a stub "1.0" in PREPARE_FOR_SUBMISSION | Set the version string to the binary's marketing version (0.4.x) before attaching the build | release |
| A3 | What's New on a first version | **Drop it**: App Store Connect takes no What's New on the first release. `listing.json` has `whatsNewOnFirstVersion: false`; the text stays for the next version. | release |
| A4 | Review details, categories, screenshots and content rights are not set | As planned: review-notes.txt, News and Business, USES_THIRD_PARTY_CONTENT; screenshots from screens #36 once they pass | release |
| A5 | Age rating exists | Overwrite with [age-rating.md](age-rating.md) (4+), and read it back after saving | release |
| M1 | listing.json diffs cleanly for en-US, pt-PT and pt-BR | GO | |

## Run 13: screens #36 on rc7 535e9ba, the iPhone 6.9" set (14:45 UTC)

21 images (7 screens, en-US, pt-PT, pt-BR).

| # | Image | Finding | State |
| --- | --- | --- | --- |
| S1 | all | No notification alert, no debug badges or rows | GO |
| S2 | 01-now, 02-team.schedule, 03-explore | The time is on one line (12-hour en-US, 24-hour pt) | GO |
| S5 | all pt | The UI is fully localized (pt-PT: Agora, O meu programa, Explorar, Notícias, Definições; pt-BR: Meu programa, Palestrantes, Reportagens). Content stays in English, as the sources publish it. | GO |
| S6 | 04-explore.talk | The Registration item: "bring your ticket QR from the **Web Summit** app". Also the empty state "Connect to load this talk's times". `-PTHideTerm` does not reach PTExplore. | **leave out** |
| S7 | 05-news.home | The lead story's summary: "Brazil's three days at **Web Summit**". The filter checks titles only. | **leave out**, or filter summaries and re-run |
| S8 | 07-explore.graph | The node label "websummit.com/…" is legible | **leave out** (labels are not controlled) |
| S9 | 01, 02, 03, 06 | Clean, native, and they show the core: now and next, my program with a clash, the agenda, people | **GO as the store set** (4 per locale and size) |
| P | 02 (pt-BR) | The date chips truncate ("9 de nov. d…") | polish, next version |
| P | 02 (pt-PT) | "palestra": "sessão" is more European | polish, next version |

The 6.5" and iPad 13" artifacts get the same check when they land.

## Run 14: screens #36, all sizes; ASC metadata applied (14:50 UTC)

| # | Check | State |
| --- | --- | --- |
| M4 | The store set is 01-now, 02-team.schedule, 03-explore and 06-explore.people, for APP_IPHONE_69, APP_IPHONE_65 and APP_IPAD_PRO_3GEN_129, in en-US, pt-PT and pt-BR. All 36 checked: no alert, no debug UI, no "Web Summit", times on one line, iPad sidebar clean, pt localized. iPad images are landscape 2752×2064. en-GB reuses en-US. | **GO**: release may upload |
| M1, M2 | ASC metadata applied (ios-submit 42491156901): en-GB (primary), en-US, pt-PT, pt-BR; name accepted; content rights; categories; review details | GO; check against a dry run |
| M7 | Age rating applied and read back (ios-submit 42491470177): every boolean false (including unrestrictedWebAccess, userGeneratedContent, messagingAndChat, advertising, socialMedia), every content level NONE, kidsAgeBand unset. That matches age-rating.md: 4+. | **GO** |
| M6, M9 | Dinis's hand steps: App Privacy (Other User Content, not linked, no tracking), Mac and Vision Pro unticked, IDFA No | pending |
| G5 | Run 398 | queued |
| G1, G4 | The rc7 build is uploaded and processed; airplane-mode fresh install | pending |

## Run 15: dev = rc7 535e9ba (15:07 UTC)

| # | Check | State |
| --- | --- | --- |
| G5 | Run 398 on 535e9ba: 28 of 28 green; dev is 535e9ba (release v0.4.22) | **GO** |
| M4 | Screenshots applied in ASC: 12 sets (4 locales × 3 sizes) × 4 images (ios-submit 42491790589) | **GO** |
| M8 | `scripts/testflight/review-notes.txt` on dev still has the old step 4 ("asked only then"). Since rc7, the first pick asks too. | **fix**: copy store/review-notes.txt; re-apply the ASC review notes if they were set from the old copy |
| G1, G4 | Build number, processing, version string, airplane-mode fresh install | pending |
| M6, M9 | Dinis: App Privacy, Mac and Vision Pro, IDFA | pending (pinged) |

15:09: the ASC version string is **0.4.22** (ios-submit 42493272621). dev is tagged v0.4.22 = 535e9ba plus the version commit. iOS release #103 (42493212548) is building and uploading. Open: build number and processing, airplane check, review-notes step 4 on dev, Dinis's hand steps.

15:10: **M8**: the ASC App Review notes were applied from store/review-notes.txt at 5d64ad7 (step 4 is new) and confirmed equal at 15:08. testflight 56b60f0 has the recopied file, merged to dev after release #103 uploads, and Beta App Review uses the same file. **GO** once merged. **G4** (airplane-mode fresh install) goes to Dinis on a device. If that cannot happen before 17:30, review accepts it on the code evidence: `AgendaHub.seedAgenda` is set in `PrompTugalApp.init`, `ReaderStore` reads the seed when the cache is empty, and `PrompTugalTests` checks that the bundled seed decodes (more than 150 events).
