# The three core journeys, against the code (c.ios.ux, 25 Nov 2026)

> Read from the SwiftUI source at candidate c2 (`5404498`), no device or simulator run. Line numbers are at that commit. Each finding: what the reader meets, the file, the fix, and the owner it goes to through the conductor. Ranked inside each journey; the cross-journey top ten is at the end.
>
> Update ~23:45 (c.ios): J1-04 fixed (thumbs hidden with comments); J3-05 resolved by fixing the listing wording (the replay is real activity). Summit screens are removed entirely (shell-spec.md), which closes J1-05 and J1-06 once done.
>
> Kinds: **DE** dead end · **EM** empty state · **JG** jargon · **SRC** unlabelled data source · **RULE** breaks a hard rule.

## J1. First open

What happens today: no welcome (summit onboarding is suppressed, `PublicShell.swift:93`), the app lands on Places, `PlacesStore.load()` fetches the index, the list, the dashboard and then all 36 place files.

| # | Kind | What the reader meets | File | Fix | Owner |
| --- | --- | --- | --- | --- | --- |
| J1-01 | DE, SRC | **First open offline: "The places did not load" and a Try again button, nothing else.** PTPlaces has no built-in copy, although PTLocal ships one (place files of 15 Nov, `LocalSnapshot.swift`) and already shows "Built-in copy of 15 Nov: connect to update". | `PTPlaces/PlacesHomeView.swift:90-104`, `PTPlaces/PlacesStore.swift:85` | Fall back to the built-in place files (PTLocal's bundle through a hook, or PTPlaces' own copy from `scripts/places/snapshot.py`) and say so. Spec P1. | PTPlaces |
| J1-02 | RULE, SRC | **Places home never says whether it is live, saved or built-in.** The footer says facts come "with the date it was read", but no screen-level line exists. `RemoteFeed` cannot tell a cached copy from a fresh one (only `updated` and `phase`). | `PlacesHomeView.swift:60-87` (masthead), `PTCore/Feed/RemoteFeed.swift` | Add `origin` (live, saved, built-in) to `RemoteFeed`; show PTLocal's `ProvenanceLabel` wording under the masthead and under each town hero. Spec C1 + P2. | PTCore owner, PTPlaces |
| J1-03 | RULE | **"Independent of Web Summit."** in the Places footer, and "not affiliated with ... Web Summit" in More's About footer. | `PlacesHomeView.swift:343`, `PTCore/Shell/ShellParts.swift:10` (`SupportLinks.independence`) | "PrompTugal.news is independent: no owner, sponsor or advertiser decides what it covers." No third-party name. | PTPlaces, PTCore owner |
| J1-04 | RULE | **Thumbs up and down send an anonymous POST** to the observability lane although comments and sign-in are hidden for privacy. App Privacy says "Data Not Collected" and the review notes say nothing is sent. | `PTPlaces/Comments.swift:175-181`, `PTPlaces/AnonymousVote.swift:63`; shown at `PlaceDetailView.swift:159-168` and on every story tile | Hide `ThumbsBar` with `placesComments(false)` in this version (same switch), or keep the vote on the device only. | PTPlaces |
| J1-05 | DE | **"Show the welcome again" (More) opens the summit welcome**: "Lisbon · 9–12 Nov", "Your summit, on your phone", "Pick your talks"; its "Choose talks" opens Explore, which has no Talks segment now (`showsTalks: false`). | `Shell/OnboardingView.swift` (whole), `PublicSettingsView.swift:68-71,109-114`, `ExploreView.swift:41` | New welcome (three rows): "Pick your town" (Follow), "Every story opens its source", "Works offline, says when it is". Buttons "Find my town" (opens Places) and "Not now". Show it once on first launch again. Spec S2. | shell |
| J1-06 | DE | **Now tab after a failed agenda load says "The agenda could not be loaded."** The summit is over and the agenda is irrelevant, but `reader.agenda.isEmpty` still gates the page. Header kicker "Lisbon · Wednesday 25 November · 23:30" and the freshness line follow the agenda. | `Shell/NowView.swift:51-53,101-103,123-126` | In the public build drop the summit phase machine from Now: header = greeting + the reader's towns; freshness from the places feed. Spec S3. | shell |
| J1-07 | JG | **The first screen's numbers are jargon**: "local AI stories", "on the AI map", "live" (hero stats); "Case study"; "The mandate"; "Powered by AgentiCCells"; "Everything is connected". | `PlacesHomeView.swift:131-134,198-200,281,309,430`; `PlaceDetailView.swift:172-193,321,449` | "stories", "organisations mapped", "towns published"; drop "Case study" (call it "Spotlight: Loulé"); "What this town's agent covers" for mandate; drop the AgentiCCells line from reader screens. | PTPlaces |
| J1-08 | JG, decision | **The product promise and the content disagree.** The listing says "Local news, every fact sourced"; a town page says "Local AI news: each story passes the PrompTugal test: AI within three steps". A reader looking for local news finds only AI-related stories. | `PlaceDetailView.swift:260-261`, `PlacesHomeView.swift:281` | Decision for Dinis via the conductor: either the copy says "Local news about AI and technology, town by town", or the by-place feed widens (since.json, civic notices, events). Until then, say it plainly in the section head. | conductor / Dinis |
| J1-09 | EM | **36 place files load on every launch** before anything is cached; on a slow line the home shows the spinner "Reading the places from promptugal.news" for a long time. | `PlacesStore.swift:85-96` | Show the home as soon as the index arrives (it already does when `places` is non-empty); load the files lazily for visible tiles and followed towns. | PTPlaces |
| J1-10 | JG | Masthead line "Portugal · The Algarve · 17 towns" hides the 17 district capitals the app now covers. | `PlacesHomeView.swift:77` | "Portugal · The Algarve · 34 towns and cities" from the store's counts. | PTPlaces |

## J2. "What is happening in my town"

Path today: Places → scroll past the hero, two case studies, the newsroom live strip, persona, Near me, Portugal, then the 17-tile mosaic (district capitals in a sideways strip below) → town page. Or Now → "Your towns" → Pick.

| # | Kind | What the reader meets | File | Fix | Owner |
| --- | --- | --- | --- | --- | --- |
| J2-01 | DE | **No way to find a town by name.** No search on Places, the capitals are in a horizontal strip, and Near me sits fifth on the page. A reader in Évora scrolls past the whole Algarve. | `PlacesHomeView.swift:26-44`, `PlacesWiring.swift:24-32` | "Find your town" row directly under the masthead: a search field over all places, plus Near me as its first suggestion. Followed towns pinned above the hero once there are any. Spec P3. | PTPlaces (+ PTLocal for Near me) |
| J2-02 | EM | **On the town page the news is the eighth block**, after hero, Now in, mandate, comment row, newsroom live and summary, the four big numbers, "Centre of gravity" and child places. | `PlaceDetailView.swift:33-50` | Order: hero (Follow) → Now in → latest news (lead + list) → events → our articles → local media → the AI map → agents → "What we do not know yet" → How this page is made. Numbers fold into the hero. Spec P4. | PTPlaces |
| J2-03 | EM | **"Now in" disappears silently** when a town has no `now.json`, and its footer says "read hourly" while the data collectors have stopped since 21 Nov. | `PTPlaces/PlaceNow.swift:132-177`, `PlaceDetailView.swift:150-155` | Show a one-line empty state ("No weather station near Alcoutim yet; IPMA covers Faro") and drop "read hourly"; the "read 4 days ago" stamp stays and turns amber after 6 hours. | PTPlaces |
| J2-04 | JG | Follow invite on Now reads "Follow your town in the Algarve" but lists every town including district capitals; Loulé and Faro are forced first. | `PTPlaces/MyTowns.swift:66-80` | "Follow your town: its latest story shows here." Order by Near me when allowed, else alphabetical. | PTPlaces |
| J2-05 | EM | A followed town with no story says "No local AI story yet." with nothing to do. | `MyTowns.swift:96` | "No story yet. Open Lagos to see its events and local media." as a link to the town. | PTPlaces |
| J2-06 | SRC | Town page has no live/saved/built-in line; "How this page is made" (at the very bottom) gives "Updated" and a raw JSON URL. | `PlaceDetailView.swift:480-500` | Provenance line under the hero (spec P2); keep "How this page is made" but show the JSON link as "Data file" with the host, not the full URL. | PTPlaces |
| J2-07 | JG | Town status pill "Live" / "Researching" uses "Live" for "this town's site is published", while the app's provenance uses "Live" for "fetched just now". | `PTPlaces/PlaceVisuals.swift:122` (`StatusPill`), `PTLocal/LocalViews.swift:143,184` | Town status: "Published" / "Being researched". Keep "Live" for data only. | PTPlaces, PTLocal |
| J2-08 | JG | "Centre of gravity", "The AI map ... the nearer the centre, the fewer steps from AI", steps badges ("2 steps") on every story. | `PlaceDetailView.swift:206-215,317-345`, `StepsBadge` | "Where AI shows up in Loulé"; "Organisations doing AI here"; steps badge only on the lead, with "2 steps from AI: why?" opening the path. | PTPlaces |
| J2-09 | EM | Events on the town page come only from the by-place file (few); the data layer's `events/by-place/{id}.json` (593 official events) is not read. | `PlaceDetailView.swift:394-425` | Bigger-pass workstream 2 (events block with its own provenance line). | PTPlaces + PTLocal |
| J2-10 | DE | "Spot something wrong? Comment on it." in the AI map subtitle, while comments are hidden. | `PlaceDetailView.swift:322` | Drop the sentence while `placesComments` is false; or point to the public corrections address if the site publishes one. | PTPlaces |
| J2-11 | JG | "Algarvio voice (for fun)" toggle changes the lede text; fine, but the mandate kicker "The mandate, in Algarvio (same facts)" keeps "mandate". | `PlaceDetailView.swift:70,178` | Keep the toggle; rename per J1-07. | PTPlaces |

## J3. "Is this true? Show me the source"

Path today: on Places and town pages a story tap opens the source URL directly (good: source first). In News and in Now's "Latest news" a tap opens the promptugal.news article page in a web view (`SitePage`); the original sources are one more hop inside that page.

| # | Kind | What the reader meets | File | Fix | Owner |
| --- | --- | --- | --- | --- | --- |
| J3-01 | RULE, SRC | **News tab and Now's Latest news never show a story's source in the app**; they open our own article page. "Every story links to its source" holds only on the web page. | `PTNews/NewsHomeView.swift:85,102,157`; `Shell/NowView.swift:430-445` | A native story header above `SitePage` (or a native story view): title, our summary, then "Sources" with each publisher and host, first, as buttons. `articles.json` carries the source URLs (bigger-pass). Spec N1. | PTNews, shell |
| J3-02 | SRC | Story rows and tiles do not show where the tap goes. The kicker falls back to "Story" when `publisher` is empty, and nothing says the link leaves the app. | `PlacesHomeView.swift:515-555` (`StoryTile`), `:557-595` (`StoryRow`) | Every row ends with the source host and an "arrow.up.right" glyph ("lusa.pt ↗"); never the bare word "Story". | PTPlaces |
| J3-03 | JG | Provenance line reads "conductor · read 21 Nov · signed site-key-2" or "signature missing". "Signature", key ids and agent handles mean nothing to a reader; "signature missing" sounds like tampering. | `PlaceDetailView.swift:678-695` (`ProvenanceLine`), `:486-491` | "Checked by the Loulé agent on 21 Nov" + a seal icon when valid; when not valid, no seal and "not yet checked". Key id only in "How this page is made". | PTPlaces |
| J3-04 | DE | **No screen explains the app's badges**: live / saved / built-in, "Simulated", seal, "read on", steps. | none | New "How we source" screen in More, linked from every provenance line (tap). Spec S4. | shell |
| J3-05 | RULE | **Newsroom "Replay the last 24 hours" has no badge.** It replays real dashboard hours, but the App Store description and review notes promise "anything shown as a replay or a simulation is labelled Simulated". | `PTLocal/Live/ReplayControl.swift:20`, `NewsroomLiveView.swift:84` | Either show `SimulatedBadge` ("Replay") while scrubbing, or change the listing text to "simulations are labelled Simulated; replays are labelled Replay". Decision for the conductor; I recommend a "Replay" badge plus the listing fix. | PTLocal, conductor |
| J3-06 | SRC | "Live from promptugal.news" appears whenever the fetch succeeded, even though the data inside was read on 21 Nov (collectors stopped). | `PTLocal/LocalStore.swift:15-21` | Bigger-pass workstream 6: drive the label from each feed's `read_at`: "Updated just now, data read 21 Nov". | PTLocal |
| J3-07 | JG | Newsletter items marked "assembled from data" with no hint of which data. | `PTNews/NewsHomeView.swift:135` | "Built from the newsroom's sources" linking to the item's sources. | PTNews |
| J3-08 | SRC | Story dates in the future (wire debrief) undermine trust exactly where a reader checks. | `PTSync/FeedParser.swift` or `PTCore` `Content.published` (root cause open) | Root cause first; `StoryWhen` already shows a date instead of "in 6 hours". | conductor batch |

## Cross-journey top ten (do in this order)

1. J1-04 thumbs send data (privacy answer at risk in review).
2. J1-03 "Web Summit" text in two places.
3. J1-01 offline first open dead end (built-in copy exists, unused).
4. J1-02 / J2-06 live / saved / built-in line on Places and town pages.
5. J3-01 News and Now open our page, not the source.
6. J3-05 replay without a badge vs the listing's promise.
7. J1-05 summit welcome reachable, "Choose talks" into nothing.
8. J1-06 Now gated by the summit agenda.
9. J2-02 town page order, news eighth.
10. J2-01 find a town by name / Near me first.

Items 1 to 3 and 6 are small and should go into the next App Store build; 4 and 5 are the "data honesty" batch; 7 to 10 are the visible "local news" batch.
