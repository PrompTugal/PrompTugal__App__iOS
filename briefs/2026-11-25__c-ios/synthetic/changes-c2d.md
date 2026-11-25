# Changes in candidate c2d: reviewer persona (P7) re-walk (c.ios.synthetic, 26 Nov 2026)

> Build: `work/candidate-c2d` at `a3db74f` (c2c `962e8f9` plus 2b55bdd). Listing: `briefs/2026-11-25__c-ios/app-store-submission.md` on `work/c-ios`. Code and live JSON only, no device. Only what changed since [changes-c2c.md](changes-c2c.md).

## Fixed

| Risk | Now |
| --- | --- |
| R5 price chips | `PlacesCredit.costText` returns nil (`Apps/PrompTugal/Shell/PlacesWiring.swift:16-17`); no prices anywhere a reviewer can reach. `charge` still records reads in the on-device ledger, invisible, which the privacy page covers. |
| Explore talk path | `talkActions: TalkActions()` (`Apps/PrompTugal/Shell/ExploreView.swift:41`), and `TalkDetail.swift:124` shows the Pick / calendar row only when an action exists. No reminders or calendar prompt from Explore. |
| R3 support | Beta install steps and Websites.json are gone; the page now describes PrompTugal.news on the App Store. |
| R2 weather in the listing | Weather and IPMA are out of the description, keywords and review notes. |
| R8, More and Places | The More footer and the Places footer no longer say "independent". |

## Remaining

| # | Severity | What | Where | Fix |
| --- | --- | --- | --- | --- |
| B1 | **blocker** | **"Now in" is still promised but never shown.** Description line 29: "'Now in' a town: what the newsroom's live data says about the place right now, with its source and read time". The card reads `by-place/<id>/now.json`, which today has `"airport": null` and only a link for weather (Lagos, Loulé, Faro read 21 Nov 07:16 UTC; Lisboa 404), so `PlaceNow.isEmpty` is true and the card never appears (`PTPlaces/PlaceDetailView.swift:151`). The screenshot plan (line 90) still asks for "a town with 'Now in'", which cannot be shot. | https://promptugal.news/api/v1/by-place/lagos/now.json; listing lines 29, 90 | Drop the "Now in" bullet and the screenshot, or put data in now.json (or wire PTLocal's conditions) before submitting. |
| B2 | annoying, reviewer may ask | **"Independent" is still on two screens.** The News tab header, a main tab: "Independent coverage from Lisbon: the latest, the newsletter and the stories being made." (`Packages/PTNews/Sources/PTNews/NewsHomeView.swift:42`, translated in PTNews' catalogue). The Algarve page opened from the newsroom board: "PrompTugal.news is independent." (`Packages/PTLocal/Sources/PTLocal/LocalViews.swift:61`, AlgarveView, reached from `Live/NewsroomLiveView.swift:165`). The linked disclosure still says "This is not independent coverage". | as listed | e.g. "Coverage from Portugal: the latest, the newsletter and the stories being made." and "Every fact here links to where it was read." |
| B3 | polish | Support page answers "Where do I report a problem?" with "Use Send Beta Feedback in TestFlight" first; App Store users have no TestFlight. The contact line after it is fine. | `website/pages/support.html` | Lead with the contact address and GitHub issues; keep TestFlight under "Testers". |
| B4 | polish | Privacy and support both say "A copy is also built into the app for the first launch, and every screen says which copy it shows". Places has neither (walk-throughs S4, S5). Not a rejection risk, but untrue. | `website/pages/privacy.html`, `support.html` | "the app shows the last copy it saved" until c.ios.local's freshness work lands. |
| B5 | polish | Submission pack line 77 still describes c1 (raw.githubusercontent.com for CI status, api.ipma.pt for weather). Notes only, but it is what Dinis types App Privacy from. | `app-store-submission.md:77` | Update to c2d: promptugal.news and data sites, ios.app.promptugal.news; IPMA only if PTLocal's Ask still reads it. |
| known | polish | Summit "Now and next" widget and Siri intent; camera, microphone and speech purpose strings (`project.pbxproj:620-623`); privacy.html live only after the dev push. | | as before |

## Verdict

One blocker left: B1, the "Now in" promise. Fix that in the listing (cheapest) and c2d is, on my reading, submittable; B2 is the next thing a careful reviewer or journalist would notice. After the dev push, re-check https://ios.app.promptugal.news/privacy.html and support.html are the new pages.
