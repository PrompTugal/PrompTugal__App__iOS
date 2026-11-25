# Shell spec: remove the summit, add -PTPlace and local.maps (c.ios.ux for c.ios, 25 Nov 2026)

> For the shell owner (c.ios). Against candidate c3 (`92c0fb1`). Files under `Apps/PrompTugal/Shell/` unless named. Goal: no summit screen, string or prompt in the public app; every old link still opens something.

## 1. Remove the summit destinations (`Destinations.swift`)

- Delete from `more`: `team.schedule` (My program), `map` (Venue map), `settings.reminders` (Reminders).
- Aliases: point every removed or summit id at `places`: `team.schedule`, `team.planner`, `map`, `settings.reminders`, `reader.agenda`, `explore.talk`, `explore.summit`, `explore.people`. Keep `explore.companies`, `explore.places`, `explore.stories`, `explore.library` (news content). Remove `.summit` and `.talk` from `exploreStarts`; `explore.graph` / `news.graph` to `explore` (graph card goes, see 4).
- `settingsSummary`: "Data sources, newsroom, about, privacy, support".
- Hide `local.credit` from the More list (`listed: false`), keep it routable.

## 2. Remove the summit from screens

- **`PublicSettingsView.swift`**: delete `StandSection` (struct and use), the Reminders row, the `PickCalendarToggle` section and its footer. Add rows in this order: Data sources, Newsroom, Algarve maps, On this device; then Appearance, Show the welcome again, About; then "About this build" with the version and CI status. Footer text without "17 town sites" (now 34 places).
- **`OnboardingView.swift`**: new copy (ux specs.md S2): kicker "PrompTugal.news", title "Local news, town by town"; rows "Find your town on the map", "News rises from town to region to country", "Every story opens its source, every number its data site". Buttons "Find my town" (opens Places) and "Not now". `finish(chooseTalks:)` becomes `finish(findTown:)`.
- **`PublicShell.swift`**: show the new welcome once on first launch again (`onboardingSeen` false and no launch destination); `finishOnboarding` opens `places`.
- **`NowView.swift`**: delete the phase switch, `agendaMissing`, `countdown`, `startProgram`, `forYou`, `whereToBe`, `onNow`, `upNext`, `tomorrow`, `thanks`, `StartProgramCard`, `SessionRow`, `SeeAllButton`, `PracticalCard`, the `InterviewsStrip` uses and the talk sheet. Keep: header (greeting without "Lisbon ·", the places provenance line), `AppNoticeCard`, `MyTownsCard`, `LatestNewsCard`. The freshness line reads the places feed, not the agenda.
- **`ExploreView.swift`**: drop the Talks hook and `GraphCard` ("Explore the summit graph"); `showsTalks: false` stays.
- **`TalkScreens.swift`, `PickCalendar.swift`**: no longer referenced by public screens once the above goes; remove from the public target or leave unreferenced (shell owner's call). `ReaderStore.refresh()` should stop fetching the agenda in the public app.
- **PTNews** (not the shell, for its owner): remove the "Interviews" segment and change the header "Independent coverage from Lisbon" to "Stories from every town, region and the country".
- **PTCore** `SupportLinks.independence` (`Shell/ShellParts.swift:10`) and **PTPlaces** footer (`PlacesHomeView.swift:357`): no third-party name; "PrompTugal.news is independent."
- Launch arguments: `-PTSeedPicks` and `-PTHideTerm` become unused; leave them harmless. Notification permission must never be asked (Reminders are gone).

## 3. Add `local.maps`

In `more`:
```
ShellDestination(id: "local.maps", title: String(localized: "Algarve maps"), symbol: "map", group: "More",
                 summary: String(localized: "Every town coloured by its news: map, 3D, grid, cartogram")) { AnyView(AlgarveMapsView()) }
```
`AlgarveMapsView` is public in PTLocal (`Live/AlgarveMapStyles.swift:471`). A tap on a town should open its page (`place:<id>`, below) instead of PTLocal's own sheet if the hook allows; otherwise leave as is for now.

## 4. Add `-PTPlace <id>` and `place:<id>`

- **Route**: in `destination(_:)`, when the resolved id starts with `place:`, return a routable `ShellDestination` built on the fly: id unchanged, title the place name (or "Place"), `phoneTab: nil`, `listed: false`, view `AnyView(PlaceDetailView(id: String(id.dropFirst(6))))`. Opened from a link it pushes onto the Places tab's stack, so `placesLayers()` applies. An unknown place shows the Places home. This gives `promptugal://open/place:loule`.
- **Launch argument** (DEBUG only, `PublicLaunch`): `-PTPlace <id>` is shorthand for `-PTDestination place:<id>`. ScreensTests will pass `-PTDestination place:loule`, so the argument is optional; the route is what matters.
- **Anchors (later, with c.ios.places)**: `place:<id>#now` and `place:<id>#lead` scroll to the "Now in" card or the lead story.

## 5. New ids for the IA (optional in this pass)

- `local.sources`: the Data sources screen (PTLocal builds it; ia.md "Where Data sources lives").
- `local.how`: How we source.

## 6. Screenshots after this lands

ScreensTests becomes: `places`, `place:loule`, `local.maps`, `now`, `news.home`, `local.newsroom` (design's order; `place:loule#lead` when the anchor exists). I change ScreensTests once the ids are on a candidate.

## Acceptance

- `grep -rn "Web Summit\|summit\|Summit" Apps/PrompTugal/Shell Packages/*/Sources` finds nothing user-visible (comments may stay).
- Fresh install: the new welcome, then Places with the map at the top. No notification prompt, ever.
- `promptugal://open/team.schedule` opens Places. `promptugal://open/place:faro` opens Faro.
- More lists: Data sources (once built), Newsroom, Algarve maps, On this device, Appearance, welcome, About, version, CI status.
