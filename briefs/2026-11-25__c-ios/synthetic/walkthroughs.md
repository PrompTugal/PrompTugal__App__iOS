# Walk-throughs: candidate c2 (c.ios.synthetic, 25 Nov 2026)

> **Build walked:** `work/candidate-c2` at `5404498` (dev `ccddde5`, v0.4.123, plus c2: no Talks in Explore, top-ups hidden, place comments, sign-in and "Connect to the newsroom" hidden). Read from the SwiftUI code and the live JSON on 25 Nov ~23:30 UTC; no device, no screenshots. Personas: [personas.md](personas.md).
>
> **Severity:** **stuck** (cannot do what they came for, or would delete the app) · **annoying** (gets there, loses trust) · **polish**.
>
> `briefs/2026-11-25__c-ios/workers.md` is not on c2 or dev; I worked from the other three briefs.

## What every persona meets (shared findings)

These are referenced from the persona sections as S1 to S14 rather than repeated.

| # | Finding | Where | Severity |
| --- | --- | --- | --- |
| S1 | **No weather anywhere on a town page.** The "Now in <town>" card reads `promptugal.news/api/v1/by-place/<id>/now.json`, which since 18 Nov carries no IPMA data (`"weather": "https://weather.promptugal.news/places/lagos/"`, `"airport": null`, read_at 21 Nov). The card hides itself when empty, so the forecast, warnings, sea and UV promised in the draft description never appear. The weather link the file now gives is not used. | `Packages/PTPlaces/Sources/PTPlaces/PlacesStore.swift:35-40`, `PlaceNow.swift:107`, `PlaceDetailView.swift:151`; https://promptugal.news/api/v1/by-place/lagos/now.json | stuck (P1, P5) |
| S2 | **"Local news" is AI news.** Every town section is "Local AI news" / "AI stories" / "the AI map" with "the PrompTugal test: AI within three steps". Lagos has 3 stories, newest dated 4 Nov **2025**. The News tab's feed.xml is industry AI pieces (CrewAI, Intercom, Spotify, the AI Act). Readers who took "Local news, every fact sourced" at its word find a tech-sector monitor. | `PlaceDetailView.swift:260-261`, `PlacesHomeView.swift` hero stats; https://promptugal.news/api/v1/by-place/lagos.json; https://promptugal.news/feed.xml | stuck (P1, P5, P6) |
| S3 | **"live" means "site published", not live data.** The Algarve hero counts every town as "live" (all of them); every one of the 36 places has `status: "live"` while their `updated` dates run 16 to 21 Nov. | `PlacesHomeView.swift:134`, `PlaceModels.swift:60`; https://promptugal.news/api/v1/by-place/index.json | annoying |
| S4 | **Places home has no freshness line.** The masthead prints today's date (`Text(Date.now ...)`), never the data's `built`/`updated` date, and there is no live / cached / built-in label. Breaks the "every screen says live, cached or built-in" rule. | `PlacesHomeView.swift:79` | annoying |
| S5 | **No offline first launch for Places.** PlacesStore has no bundled snapshot; with no signal the first screen is "Reading the places from promptugal.news" for up to 20 s, then "The places did not load". (PTLocal has a built-in snapshot; PTPlaces does not.) | `PlacesStore.swift`, `PTCore/Feed/RemoteFeed.swift:36`, `PlacesHomeView.swift:91-104` | stuck (P1) |
| S6 | **Summit leftovers in More.** "At the summit: Meet RiskMandate, Thursday 12 November, booth A1-30" with a riskmandate.ai link; "My program" ("The talks you picked at the Summit"); "Venue map"; "Reminders: Before each pick"; a calendar toggle about talks; "Show the welcome again" opens "Your summit, on your phone" with "Choose talks", which now lands on Explore without Talks. | `Apps/PrompTugal/Shell/PublicSettingsView.swift:66,78,128-148`, `Destinations.swift:92-95,112`, `OnboardingView.swift:15,38` | annoying (stuck for P7) |
| S7 | **Summit widget and Siri.** The only widget is "Now and next: the session happening now ... in Lisbon time" (gallery sample "Opening keynote, Centre Stage"); it will say "No sessions coming up" forever. Siri: "What's next in PrompTugal" answers the next summit session. | `Apps/PrompTugal/Widgets/NowNextWidget.swift:21-23,58-59,87`, `Intents/PrompTugalShortcuts.swift:7-8` | annoying |
| S8 | **Independence contradicts itself.** The app says "PrompTugal is independent" (More footer, `SupportLinks.independence`), the News tab "Independent coverage from Lisbon", the Places footer "Independent of Web Summit". The disclosure the app links as "About this coverage" says "This is not independent coverage" and names the commercial interest. | `PTCore/Shell/ShellParts.swift:10`, `PTNews/NewsHomeView.swift:42`, `PlacesHomeView.swift:343`; https://promptugal.news/about/participant.html | stuck (P2) |
| S9 | **Reading credit is a pretend wallet.** Prices in £ on articles ("costText"), a balance that goes "Below zero", "spent", "Where your credit goes" ("Sharing reading revenue ... is planned, not yet in place"). Nothing is charged and nothing can be bought (top-ups hidden in c2), but the screen reads as a paywall. Pounds sterling in a Portuguese news app. | `PTLocal/Credit/CreditViews.swift:127-144,238`, `PlaceDetailView.swift:298`, `CreditBook.swift:19` | annoying (stuck for P7) |
| S10 | **CI status is a developer screen.** "A push to dev deploys the website and uploads the apps to TestFlight", "Open TestFlight to update" (`itms-beta://`), "Not a TestFlight build". Public readers do not know what CI is. | `Destinations.swift:105`, `PTLocal/Status/CIStatusView.swift:15,138-167` | annoying (stuck for P7) |
| S11 | **Near me is buried.** It sits in the Places home accessory below the hero and case studies, and in More > Ask and summarise. Only the 17 Algarve towns are candidates, so a reader in Lisbon is told their "nearest town" is in the Algarve. | `Apps/PrompTugal/Shell/PlacesWiring.swift:29`, `PTLocal/AI/NearMe.swift:38-41,48-50` | annoying (P2, P5) |
| S12 | **Portuguese is mostly missing.** The app starts in English regardless of the device ("default English, never the device's"). The app catalogue has 196 keys, all with Portuguese; PTPlaces and PTLocal ship no string catalogue and their keys ("The case studies", "Local AI news", "Now in %@", "Reading credit") are not in the app's. Places, the town page, Newsroom, Credit, CI status and Ask stay English after choosing Português. 21 cultures are offered. | `PrompTugalApp.swift` (AppCulture.start), `Apps/PrompTugal/Resources/Localizable.xcstrings`, `PTCore/Culture/AppCulture.swift:27-28` | stuck (P6) |
| S13 | **Fixed font sizes.** Masthead 32/44 pt, hero titles 44/64 pt, temperature 64 pt use `.system(size:)` and do not grow with Dynamic Type; 9 such uses in PTPlaces. | `PlacesHomeView.swift` (3), `AgentsPanel.swift` (2), `ConnectedTowns.swift`, `ConnectionsGraph.swift`, `PlaceNow.swift`, `PlaceVisuals.swift` | annoying (P6) |
| S14 | **Internal newsroom text shown to the public.** The Newsroom board shows each agent's `next` and `asks` verbatim from dashboard.json (356 asks), e.g. repo-access reviews, AWS budget per role, account moves, "Decision: For Dinis: ...". Fresh (25 Nov 23:20) and honest, but it is ops chatter, not a reader feature. | `PTLocal/NewsroomCentreView.swift:168-202`; https://promptugal.news/api/v1/newsroom/dashboard.json | annoying (P7), a plus for P8 |

Good things every persona benefits from: every story row opens its source first (`PlaceDetailView.swift:553`, "Read at the source", "read on <date>"); "How this page is made" names the agent, the update date, the signing key and the data URL (`PlaceDetailView.swift:484-495`); "What we do not know yet" shows the gaps on purpose; the one simulated number (Verify step) carries the Simulated badge (`NewsroomCentreView.swift:273`); comments, sign-in and the Connect section are gone from c2 as intended.

---

## P1 · Graça, Loulé, iPhone SE, poor signal

1. **Launch, no signal in the market hall.** Places tab: spinner "Reading the places from promptugal.news", then "The places did not load" with Try again (S5). Now tab works from the saved news copy if she has opened it before. **stuck** on first install.
2. **Outside, one bar.** Places home: the satellite hero of the Algarve, 400 pt tall on a 667 pt screen, then "The case studies: Loulé and Faro". Loulé is first, good. Masthead says today's date, no "read 21 Nov" (S4). **annoying**.
3. **Loulé page.** "Local AI news" (13): the newest is an AI-supported piano recital at the Som Riscado festival (16 Nov). Correct, sourced, dated. No council notices, no general news, no events this week (3 events, the first held 10 Nov at CRIA in Faro). (S2) **stuck**: not what she came for.
4. **Weather.** None on the page (S1). **stuck**.
5. **Small screen.** Four big-number tiles (AI stories, on the AI map, events, sources) and long serif headlines; the hero stats row ("towns, local AI stories, on the AI map, live") at `.title` serif is likely to truncate or wrap on 375 pt width. **polish**, needs the screenshot run to confirm.

Deletes the app: yes, on day one (no weather, no Loulé news beyond AI).

## P2 · Rui, Lisbon tech journalist

1. **News tab.** "The news · Independent coverage from Lisbon" (S8). Latest: "A study of five coding agents" (24 Nov), "AI use in Portugal jumps in 2026" (23 Nov). Dates look right in feed.xml; the future-date bug noted in the wire debrief is covered in the UI by `StoryWhen` (`Apps/PrompTugal/Shell/NowView.swift`) showing the day instead of "in 6 hours", which hides the bug rather than fixing it. **polish**.
2. **More > About this coverage.** Opens https://promptugal.news/about/participant.html: "This is not independent coverage. We may write about companies the team hopes to meet or sell to." Three screens in the app say "independent". **stuck**: he would quote this contradiction.
3. **Town page provenance.** "How this page is made": written by `place.loule@PrompTugal.dinis`, signed with a key id, data URL. Each story: publisher, "Read at the source", "read on". He likes this. One item on Loulé's talent list names a member of the team behind the site (sourced to newsroom.sgit.ai), so the site covers its own people under "talent". **annoying**.
4. **Lisboa.** "Across Portugal" shows Lisboa with 10 stories (updated 17 Nov). Near me from Lisbon picks an Algarve town (S11). `by-place/lisboa/now.json` is 404. **annoying**.
5. **Ask and summarise.** On his 16 Pro, on-device summaries are labelled "Generated on this device by Apple Intelligence ... It can be wrong" with sources. Good.

Deletes the app: not at once, but writes about the independence wording.

## P3 · Marta, council officer, location off by policy

1. Places home: her council is one of the 17 towns in the mosaic. Town page: mandate, "Centre of gravity", AI map, "What we do not know yet" (Loulé has 44 gaps listed). The gaps are frank and occasionally about her council (e.g. "Its AI.EVENT story has no date"). **annoying** for her, but honest.
2. **Corrections.** The disclosure promises corrections "on the same page, dated". In c2 the in-app comment button is gone (by design), so the only route is "Open on promptugal.news" then find a contact on the site. No "Report a mistake" link in the app. **stuck** for her purpose.
3. **Contacts.** Loulé's contacts block prints the council's published phone and the Loulé 24 Horas line with "Published at cm-loule.pt", which follows the contacts rule. Good.
4. **Freshness.** The civic site's council notices are not in the app at all (bigger-pass workstream 2). Nothing claims to be current, so no distrust, just absence.
5. Location off: Near me says "Location is off for PrompTugal. Pick your town instead, or allow it in Settings." (`LocalAIViews.swift:491`). Clean.

## P4 · Tiago, Faro startup founder

1. Faro case study: 28 AI stories, an AI map with kind chips (government, companies, startups, investors, research, communities). Faro has the most coverage. Good.
2. **Not on the map.** No way to suggest an entry in c2: the comment button is hidden; "Work with us" leads to https://promptugal.news/contribute/ (200), which is aimed at journalists and local media ("our agents research, you report"), not companies. **annoying**.
3. **Investors and programmes.** Loulé shows "investors" (Algarve 2030 programme) and "start a company" desks; Lagos shows none (0, 0). Uneven between towns with no note. **polish**.
4. **Explore > Companies.** Explore opens on Speakers ("Speakers, companies and places"), the Web Summit index; companies are summit exhibitors, not the newsroom's 115 companies. A Faro founder searching his town finds summit people. (S6, bigger-pass workstream 4.) **annoying**.

## P5 · Hannah, tourist in Lagos

1. First launch: Places home in English, good for her. Near me is below the fold under the hero, the case studies and the newsroom section (S11). **annoying**.
2. Lagos page: mandate "AI and technology in Lagos, a town of remote workers"; 3 AI stories, newest Nov 2025; 5 events, the first titled "(past)" from 14 Oct. Nothing about tonight. (S2) **stuck**.
3. No weather, no sea (S1). **stuck**.
4. "Algarvio voice (for fun)" toggle on the town page: charming, but in Portuguese dialect for an English reader. **polish**.
5. Reading credit prices in £ on articles: as a Bristolian she is not confused by the currency, but she is by being "charged" in a free app (S9). **annoying**.

Deletes the app: yes; the listing set the wrong expectation.

## P6 · Sr. Joaquim, Português, Accessibility XL, VoiceOver

1. **Language.** The app opens in English on his Portuguese iPhone. He must find the language button (top left on every tab) and pick Português from 21 cultures. **annoying**.
2. After choosing Português: the tab bar, Now and More are Portuguese; Places home, the Tavira page, Newsroom, Credit, CI status and Ask stay English (S12). **stuck**.
3. **Large text.** Body text grows; the masthead, the town names on hero images and the big numbers do not (S13). At Accessibility XL the hero stats row and the four BigNumber tiles likely truncate. **annoying**, needs screenshots at XL to confirm.
4. **VoiceOver.** Icon-only buttons in the shell are labelled ("More", language). The Algarve hero map is `interactive: false` and decorative; RegionMap pins need checking. `.textCase(.uppercase)` kickers are read normally. The Simulated badge reads "Simulated, not real data". **polish** pending a device pass.
5. Tavira: 4 AI stories. Even translated, it is not the Tavira news he wanted (S2).

## P7 · App Store reviewer, iPad 13", location denied

Full list with fixes: [app-review-risk.md](app-review-risk.md). The walk:

1. **Sidebar** (iPad): Places, News, Now, Explore; then "More": My program, Venue map, Newsroom, Reading credit, CI status, Ask and summarise, More, Reminders. Header "PrompTugal.news · the Algarve", version. Two summit screens and a CI screen in the first list a reviewer sees. **stuck** risk (2.1, 4.2).
2. **Places**: loads; no weather although the description promises "Now in a town: the nearest weather station, the forecast and warnings from IPMA, fire risk, UV and the sea" (S1). **stuck** risk (2.3.1).
3. **Now**: "Good evening", "Lisbon · Wednesday 25 November · 23:30", My towns, Latest news. Fine.
4. **Explore**: Speakers of a past conference (S6).
5. **More > Reading credit**: a meter in £ with "spent" and "Below zero"; review notes say "nothing to purchase" (S9). **stuck** risk (3.1.1 / 2.1).
6. **More > CI status**: "Open TestFlight to update" (S10). **stuck** risk (2.2).
7. **More > Ask and summarise**: on iPad with no model: "Apple Intelligence: not available on this device". Near me with location denied: graceful message. Good.
8. **More > Privacy** link: https://ios.app.promptugal.news/privacy.html is the "PrompTugal: Lisbon Summit 0.4.123" policy and says the app "does not use the camera, microphone, Face ID, location" and that promptugal.news "is the only server the app talks to". The app asks for location (Near me) and reads api.ipma.pt and raw.githubusercontent.com. **stuck** risk (5.1.1).
9. **More > Support**: https://ios.app.promptugal.news/support.html is beta-tester help (TestFlight, Websites.json, "the book icon", Web Summit time zones). **stuck** risk (1.5).
10. **More > At the summit**: a booth on 12 November and a link to the developer's company site. **annoying**, reads as an advert for a past event.
11. Widget gallery: "Now and next" sessions widget, empty (S7).

## P8 · Sofia, investor

1. Places home, "The newsroom, live": fresh (dashboard agents last updated 25 Nov 23:20 UTC). "Replay the last 24 hours" scrubber says "Live" when not replaying. Fine; the replay is clearly a replay.
2. More > Newsroom: 86 agents, their `next` and `asks`, "Read-only: from the newsroom dashboard on promptugal.news." The flow card's Verify step is Simulated and badged; Research, Write and Publish are real counts. Exactly what she wanted to see. One nit: "Edit and publish: Live" is the site status (S3).
3. The agents' asks to the human ("Decision: For Dinis: ...") show people deciding. Useful evidence; also exposes that many asks date from 6 Nov and look open (356 asks). **annoying**: reads as a backlog nobody clears.
4. Reading credit: interesting as a model, but "planned, not yet in place" on revenue sharing. **polish** for her.
5. More > At the summit, My program, Venue map, the widget: the app still looks like the Web Summit app it was (S6, S7). **annoying**.
6. CI status: as an investor she likes "push to TestFlight in N minutes", but it is the app's own internals in a consumer product.

---

## Top fixes, by how many personas they unblock

1. **Weather back on town pages** (S1): read `weather.promptugal.news` or the PTLocal IPMA conditions layer (`ConditionsStore`), with its read_at, or drop the weather claims from the listing. Unblocks P1, P5, P7.
2. **Say what the app is** (S2): either the listing says "local AI and tech news, town by town", or town pages gain general local news, events and council notices (bigger-pass 2). Unblocks P1, P5, P6, P7.
3. **Remove summit leftovers** (S6, S7): At the summit, My program, Venue map, Reminders, the calendar toggle, the welcome sheet, the widget and the Siri intent. P7, P8.
4. **Hide Reading credit and CI status** in the App Store build (S9, S10), as c2 did for comments. P7, and less confusion for everyone.
5. **One independence line** matching the disclosure (S8). P2.
6. **Rewrite privacy.html and support.html** for PrompTugal.news (see the risk page). P7.
7. **Portuguese for PTPlaces and PTLocal**, and start in the device language when supported (S12). P6.
8. **Freshness on Places home** from `built` / `updated`, and "published" instead of "live" (S3, S4). P1, P2, P3.
