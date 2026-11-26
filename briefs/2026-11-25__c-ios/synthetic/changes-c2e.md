# Changes in candidate c2e: reviewer persona (P7) re-walk (c.ios.synthetic, 26 Nov 2026)

> Build: `work/candidate-c2e` at `5cbf730` (c2d merged to dev as v0.4.124, plus "no Explore tab and no language button"). Listing: `briefs/2026-11-25__c-ios/app-store-submission.md` on `work/c-ios`. Code and live pages only. Changes since [changes-c2d.md](changes-c2d.md).

## Fixed since c2d

| Item | Now |
| --- | --- |
| B1 "Now in" promise | Gone from the pack: no "Now in" bullet, and the screenshot plan asks for "a town page". The listing no longer promises anything the build cannot show. |
| R1 privacy deployed | https://ios.app.promptugal.news/privacy.html is the PrompTugal.news page (checked 26 Nov ~00:50 UTC). |
| R3 support deployed | https://ios.app.promptugal.news/support.html is "Help for PrompTugal.news". |
| Explore (summit Speakers) | No longer a tab or a sidebar row (`Destinations.swift`, `listed: false`, no `phoneTab`). The iPad sidebar is Places, News, Now, then Newsroom, Ask and summarise, More. |

## New in c2e

| # | Severity | What | Where | Fix |
| --- | --- | --- | --- | --- |
| E1 | polish, metadata | **21 languages listed, English only.** With the language button gone, the app always runs in en-GB (`PTCore/Culture/AppCulture.swift:63-65`: the saved choice or English, never the device language). The bundle still declares 21 localisations (`Info.plist` CFBundleLocalizations: pt-PT, ar, zh-Hans, ...), so the App Store page will list them all. A reviewer on a non-English iPad sees English; a Portuguese reader who reads "Português" on the store page cannot get it. | `Apps/PrompTugal/Info.plist:21-44` | Cut CFBundleLocalizations to `en` for this version (and the catalogues' extra languages if Xcode still lists them), or let `AppCulture.start` follow the device's preferred language when it is one of the 21. |
| E2 | polish | **Explore code still reachable from dead paths.** `open("explore")` remains in Now's summit cards, the welcome sheet, My program and Settings (`NowView.swift`, `PublicShell.swift:135`, `TalkScreens.swift:128`, `PublicSettingsView.swift:93`); none is on screen in c2e, so no reviewer path. Noted for c6, where Explore is rebuilt but still unlisted. | as listed | none for this version |

## Still open (not blockers)

- "Independent coverage from Lisbon" on the News tab header (`Packages/PTNews/Sources/PTNews/NewsHomeView.swift:42`) and "PrompTugal.news is independent." on the Algarve page reached from the newsroom board (`Packages/PTLocal/Sources/PTLocal/LocalViews.swift:61`); the disclosure says "not independent coverage".
- The "Now and next" summit widget and the Siri "Next session" intent.
- Camera, microphone and speech purpose strings in `project.pbxproj` while privacy.html says the app uses neither.
- Support's "report a problem" answer leads with TestFlight; privacy and support still say every screen labels its copy and that a copy is built in for first launch; neither is true of Places in c2e.

## Verdict

No blocker left that I can find from code and the live pages. c2e looks submittable. Before pressing submit: confirm the widget is acceptable to ship as is (or drop it), and decide E1, because the store page's language list is the one thing a reviewer can compare in seconds.
