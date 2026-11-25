# Changes in candidate c2c: reviewer persona (P7) re-walk (c.ios.synthetic, 25 Nov 2026)

> Build: `work/candidate-c2c` at `962e8f9` (c2 `5404498` plus c2b thumbs hidden and da5f7de). Same method as [walkthroughs.md](walkthroughs.md): code and live JSON, no device. Only what changed, against [app-review-risk.md](app-review-risk.md).

## Fixed

| Risk | Now |
| --- | --- |
| R4 CI status | Not in More or the iPad sidebar (`Destinations.swift`, `listed: false`; row removed from `PublicSettingsView.swift`). Still opens from `promptugal://open/local.ci-status`, which a reviewer will not try. |
| R6 (More part) | My program, Venue map, Reminders, the calendar toggle, "Show the welcome again" and the RiskMandate booth card are gone from More and the sidebar. |
| R10 developer link | Gone with the booth card. |
| R11 iPad | The sidebar is now Places, News, Now, Explore, then Newsroom, Ask and summarise, More. Clean. |
| Thumbs | Hidden with comments (`PTPlaces/Comments.swift`, ThumbsBar), so nothing leaves the device. |

## Better, not done

| Risk | What remains | Fix |
| --- | --- | --- |
| R1 privacy | `website/pages/privacy.html` in c2c is right: location for Near me on device, IPMA, data sites, Apple Intelligence on device, no camera or microphone. **Not live yet**: https://ios.app.promptugal.news/privacy.html still serves "PrompTugal: Lisbon Summit ... only downloads the public agenda and news from promptugal.news" until a dev push deploys the site. Two claims are not true of the app: "A copy is also built into the app for the first launch, and every screen says which copy it shows" (Places has no built-in copy and no freshness line, S4, S5 in the walk-throughs). | Deploy before submitting and check the live page. Soften the two claims to "the last copy you saw" until PTPlaces has a snapshot and freshness labels (c.ios.local's freshness task). |
| R5 Reading credit | The More row is gone, but `PlacesWiring.start()` still sets `PlacesCredit.costText`, so story and article rows on town pages still show a price (`PTPlaces/PlaceDetailView.swift:298`) with nowhere to learn what it means. A reviewer sees prices in a free app with "nothing to purchase". | Leave `PlacesCredit.costText` (and `charge`) unset in this version (`Apps/PrompTugal/Shell/PlacesWiring.swift:13-18`). |
| R8 independence | More's footer and the Places footer now say "PrompTugal.news is an independent newsroom". The disclosure the app links as "About this coverage" still says "This is not independent coverage" (https://promptugal.news/about/participant.html, checked 23:40 UTC). The News tab still says "Independent coverage from Lisbon" (`PTNews/NewsHomeView.swift:42`); the draft description still ends "PrompTugal.news is independent." | Either the disclosure changes on the site, or the app and listing drop "independent" (e.g. "Not affiliated with Web Summit. See our disclosure."). |

## Still open (blockers marked)

| Risk | State in c2c |
| --- | --- |
| **R2 weather (blocker)** | No change in the app: town pages still show no weather. The listing draft in c2c still promises it in five places: description bullet "Now in a town: ... IPMA ..." (line 29), keywords "weather,IPMA", What's new "'Now in' each place", review notes "public weather data from IPMA", screenshots "a town with 'Now in'" (`briefs/2026-11-25__c-ios/app-store-submission.md`). All five must go if "Now in" stays empty. |
| **R3 support (blocker)** | `website/pages/support.html` in c2c keeps its first half: "Help for testers of the iPhone and iPad beta", "Get the beta", TestFlight install steps, "The App Store comes later", and "Edit the website shortcuts" with Websites.json (a DEBUG-only screen). The new Q&A at the end is good. | 
| R6 rest | The "Now and next" sessions widget and the Siri "What's next in PrompTugal" intent (known). Explore still opens on summit Speakers. New, likely: a speaker's "Connections" (`PTExplore/ExploreScreens.swift`, ExploreDetailView, NavigationLink per link) can still lead to a talk, whose `TalkDetailView` carries the pick actions; a pick can raise "Turn on reminders? PrompTugal reminds you before the sessions you pick." (`Apps/PrompTugal/Shell/PublicFeatures.swift:105-112`) and the write-only calendar prompt. Needs a device tap to confirm. Fix: in Explore, drop event links from Connections when `showsTalks` is false, or hand `TalkActions()` empty. |
| R7 purpose strings | Camera, microphone and speech strings unchanged in `project.pbxproj:620-623`; the privacy page now says the app does not use the camera or microphone, so the Info.plist and the policy disagree on paper. |
| R9 positioning | Unchanged. |

## Verdict

Submit after: R2 (listing edits), R3 (support page first half), R1 deployed, R5 price chips off. R8 and the Explore talk path are the next most likely questions from a reviewer.
