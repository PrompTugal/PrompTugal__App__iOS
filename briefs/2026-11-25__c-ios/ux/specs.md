# Short specs for the builders, via the conductor (c.ios.ux, 25 Nov 2026)

> Each spec is a proposal for the conductor to hand on. I do not edit these packages. Ids refer to journeys.md.

## For c.ios.places (PTPlaces)

**P0. App Store blockers (small, this build).**
- Hide `ThumbsBar` when `placesComments` is false (J1-04). Today it POSTs an anonymous vote (`Comments.swift:180`).
- Footer: replace "Independent of Web Summit." (`PlacesHomeView.swift:343`) with "PrompTugal.news is independent." (J1-03).
- Drop "Spot something wrong? Comment on it." while comments are hidden (`PlaceDetailView.swift:322`, J2-10).

**P1. Built-in copy for the first open offline (J1-01).** When the index and the list both fail and there is no cache, read the built-in place files (PTLocal bundles them, 15 Nov) through a new hook `placesSnapshot: () -> PlaceIndex?` set by the shell, or bundle PTPlaces' own copy. Never show the bare error when a copy exists. Acceptance: airplane mode, fresh install, Places shows the Algarve with "Built-in copy of 15 Nov: connect to update".

**P2. Provenance line (J1-02, J2-06).** Under the masthead and under each town hero, one line in PTLocal's wording: "Live from promptugal.news · 2 min ago", "Offline: the last copy this device read · 3 days ago", "Built-in copy of 15 Nov: connect to update". Needs C1. Tapping it opens "How we source" (S4) through the shell's `openDestination`.

**P3. Find your town (J2-01).** Directly under the masthead: followed towns as chips (if any), a search field over every place (Algarve towns and district capitals), Near me as the first suggestion (PTLocal's `NearMeView` logic, location only on the device). Section order after that: hero, Portugal, towns, across Portugal, latest, newsroom.

**P4. Town page order (J2-02).** hero (name, Follow, provenance line, the three counts) → Now in (with an empty state, J2-03) → latest news (lead + list) → events → our articles → local media → organisations doing AI here → agents → what we do not know yet → how this page is made. Comment and thumbs row removed while comments are hidden.

**P5. Plain words (J1-07, J2-07, J2-08, J3-03).** Replace: "local AI stories" → "stories"; "on the AI map" → "organisations mapped"; hero "live" → "towns published"; status pill "Live"/"Researching" → "Published"/"Being researched"; "Case study" → "Spotlight"; "The mandate" → "What this town's agent covers"; "Centre of gravity" → "Where AI shows up in <town>"; "The AI map" → "Organisations doing AI here"; drop "Powered by AgentiCCells" on reader screens; provenance "signed <key>" → "Checked by the <town> agent on <date>", "signature <x>" → "not yet checked". Every story row ends with its source host and "↗" (J3-02).

## For c.ios.local (PTLocal)

**L1. Freshness from `read_at` (J3-06, bigger-pass 6).** `Provenance.live` should carry the data's own read date: "Updated just now · data read 21 Nov" and turn amber when the data is older than its feed's expected cadence.

**L2. Replay badge (J3-05).** While `ReplayControl` has a position, show a badge "Replay" (same style as `SimulatedBadge`) on the board. The conductor decides whether the listing text changes to match.

**L3. Status words (J2-07).** `LocalViews.swift:143,184`: "Live"/"Researching" for a town → "Published"/"Being researched".

## For c.ios.explore (PTExplore)

**E1.** Segment names and search prompt without summit words: "Organisations", "Stories", "Events", "Library"; prompt "Search organisations, stories, events". Empty state "Nothing to show yet. The newsroom's data loads once online, then works offline." (today: "The summit data loads once online", `ExploreScreens.swift:169`). Every item shows its source host.

## For the shell and PTCore owner (conductor decides who)

**C1. `RemoteFeed.origin`.** `enum FeedOrigin { case network(Date), cache(Date?), builtIn(String) }`, set in `load()` and `loadCache()`. One small PTCore change that lets every screen say live / saved / built-in without its own store.

**C2. Independence line.** `SupportLinks.independence` (`PTCore/Shell/ShellParts.swift:10`) names a third-party trademark. New text: "PrompTugal.news is independent: no owner, sponsor or advertiser decides what it covers."

**S1. "Lisbon summit 2026" in More (ia.md).** New destination `summit` listing My program, Venue map, Reminders, calendar toggle, Interviews; `listed: false` on `team.schedule`, `map`, `settings.reminders`; remove `StandSection`; hide `local.credit` from More (keep it routable). Move CI status to an "About this build" section with the line "Is this app the latest version? Read-only."

**S2. New welcome (J1-05).** Replace `OnboardingView` copy: kicker "PrompTugal.news", title "Local news, town by town"; rows "Pick your town: follow it and its latest story is on Now", "Every story opens its source: we summarise and link out", "Works offline, and says when it is: live, saved on your phone, or the copy built into the app". Buttons "Find my town" (opens Places, focuses search) and "Not now". Shown once on first launch.

**S3. Now without the summit (J1-06).** Public build: no `NowModel` phases, no `agendaMissing`, no `PracticalCard`, no `StartProgramCard`. Header: greeting, today's date (no "Lisbon ·" prefix), the places feed's provenance line. Then Your towns (each with its latest story and its Now in line), then Since you last looked (`since.json`, bigger-pass 1), then Latest news.

**S4. "How we source" screen.** Defines: live / saved / built-in; "Simulated" and "Replay"; the seal; "read on"; "steps from AI"; and links to `FeedClient.disclosure`. Reached from More and by tapping any provenance line.

**S5. Screenshot hook (screenshots.md).** DEBUG-only launch argument `-PTPlace <id>` that pushes that place's page on the Places tab after launch, and `-PTPlaceMap` for the Algarve styled map. Then add destination aliases if preferred (`places.town`, `places.map`) so `ScreensTests` can name them.

**N1. Sources first in News (J3-01).** Above `SitePage` for an article (News feed, lead, Now's Latest news): a native header with the title and "Sources" (publisher, host, ↗) read from `articles.json`. Owner PTNews; the Now card is in the shell.
