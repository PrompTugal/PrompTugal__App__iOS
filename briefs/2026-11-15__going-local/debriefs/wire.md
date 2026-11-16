# Debrief: appdev.wire@promptugal.dinis (hand-over, 16 Nov 2026 ~15:30 UTC)

> For a fresh session that knows nothing. Written when Dinis paused all PrompTugal agents to move them to other
> accounts. No key or credential values are in this file, and none are needed to pick the work up.

## Mandate

A worker for **conductor.a.ios@promptugal.dinis** (the iOS conductor) in `PrompTugal/PrompTugal__App__iOS`, created on
the night of 15–16 Nov 2026 (brief: `briefs/2026-11-15__going-local/tonight.md`, read its **CI rule**). Dinis presented
on the morning of 16 Nov and wanted **one TestFlight build with everything**.

Two lines of work existed and had to become one app:

- `night/going-local`: the conductor's integration. `Packages/PTLocal` (Live newsroom and Algarve maps, AI persona,
  near me, IPMA conditions, Credit, CI Status) and `Packages/PTTalk` (owner-only talk to the conductor).
- `night/ios-places`: ios.places@'s `Packages/PTPlaces` (the Places tab, place pages), which exposes **public hooks**
  so other packages can add to its screens without either package importing the other.

My job: merge both, then **wire the PTLocal/PTTalk layers into the PTPlaces screens in the app shell only**
(`Apps/PrompTugal`), never inside the packages. Then small shell fixes from Dinis's screenshots.

## What I own

All in `Apps/PrompTugal/` (the public app, bundle `news.promptugal.reader`):

| File | What |
| --- | --- |
| `Shell/PlacesWiring.swift` | The whole PTPlaces ↔ PTLocal/PTTalk wiring (below). The only file that imports both. |
| `PrompTugalApp.swift` | `PlacesWiring.start()` in `init()` (after `LocalCredit.start()`), and `.placesLayers()` on `PublicShell()` in the `WindowGroup`. |
| `Shell/PublicShell.swift` | Sidebar header (iPad): "PrompTugal.news · the Algarve" + `AppVersion.label`; `enum AppVersion` at the end of the file. |
| `Shell/PublicSettingsView.swift` | More: first section shows the same name + version; the "Reading credit" row (`LocalCreditView`). |
| `Shell/NowView.swift` | `StoryWhen(date:)` (future dates show the day, e.g. "15 Nov", never "in 6 hours"); in the `.after` phase no "Thanks for coming" and no Practical card. |
| `apps.json`, `PrompTugal.xcodeproj` | Merge resolution: PTPlaces, PTLocal, PTTalk (+ PTLanes, PTVaultUI) all linked. Camera usage text from ios-places, microphone + speech texts from going-local. |

### PlacesWiring.swift, as it stands on dev (e7d8470, v0.4.121)

- `PlacesWiring.start()`: `PlacesCredit.charge` → `LocalCredit.shared.charge(action:ref:date:title:)`,
  `PlacesCredit.costText` → `LocalCredit.shared.costText(action:ref:date:)`. Never gates content.
- `PlacesHomeLayers` (via `.placesHomeAccessory`): `NewsroomLiveSection()`, `PersonaBanner()`, `PersonaForYouCard()`
  (renders nothing until a persona is picked), `NearMeView()`.
- `PlaceLayers(placeID:)` (via `.placeAccessory`): `TownNewsroomLive(placeID:)` and, when
  `LocalStore.shared.site(id)` exists, `TownSummaryCard(site:)`. **`ConditionsCard` was removed by the conductor in
  1057a4d**: ios.places@'s "Now in <place>" panel shows the same IPMA data (and more) from the website's now.json.
- `RegionMapLayer` (via `.placesRegionMap { open in ... }`): `AlgarveStyledMap(towns: AlgarveMapTown.fromLocalStore(store)) { open($0) }`
  replaces the satellite map on the Algarve page; `open(id)` pushes that place. ios.places@ agreed to `fromLocalStore`
  (same ids as PTPlaces).
- `extension TalkTransport: @retroactive PlacesTalk {}`, `.placesTalk(TalkTransport.conductor)`: place comments go
  to the conductor's lane via PTTalk (without a pasted lane link the composer says so).
- `.talkSigning { try? PersonKeychain.load()?.signingKey() }`: PTTalk's composers sign with the person key that
  PTPlaces' sign-in keeps. Read from the Keychain directly because the closure is `@Sendable` and `PersonSession` is
  `@MainActor`.

## Why the hooks sit at the WindowGroup root

PTPlaces' place pages are pushed with `navigationDestination` inside the shell's NavigationStack. Environment values set
on `PlacesHomeView()` inside `Destinations.swift` are not reliably inherited by pushed pages or sheets. Setting them
once on `PublicShell()` (above every stack, both the phone TabView and the iPad split view) is what PlacesHooks.swift
recommends and what works.

## How I worked

- Branch: **`work/wire` only**. Pushes there run no CI. Never pushed `night/*`, `dev` or `main`; never dispatched runs.
- After each coherent step: push `work/wire`, then `send_message` the conductor "ready at <sha>"; the conductor merges
  into its candidate, runs **one** build an hour, and pushes green to `dev` (which uploads to TestFlight).
- Before each new commit, merge whatever the conductor last told me (`origin/night/going-local`, later
  `origin/work/candidate`) so there is one line of history.
- ios.places@ (PTPlaces owner) announces new hooks with a sha; I merged their `night/ios-places` **only after they said
  that sha was green**, preparing the wiring on a local branch meanwhile.
- No Swift toolchain in the Linux container: nothing is compiled locally. Checks I could run:
  `python3 scripts/apps/check_apps.py`, `python3 scripts/apps/test_apps.py`, and
  `python3 scripts/apps/affected.py <base> <head>` (which apps CI will build). CI is the compiler.
- Before calling any package API, grep its real signature (`public init`, `public func`) in the package source.
- Commit trailers: `Agent: appdev.wire@promptugal.dinis` / `For: conductor.a.ios@promptugal.dinis`.

## State at hand-over

- `dev` = e7d8470 (release v0.4.121) contains all my work through c11c205, plus the conductor's 1057a4d (ConditionsCard
  removed) and ios.places@'s 754672a (no summit onboarding sheet; the app opens on Places).
- `work/wire` = dev + this debrief. Nothing of mine is pending or unmerged.
- Open, not done by me:
  - **Root cause of future story dates.** `StoryWhen` only hides it on Now. The feed's dates are parsed somewhere in
    `Packages/PTSync/Sources/PTSync/FeedParser.swift` / `PTCore` `Content.published`; a date-only or zone-less string is
    probably read in the wrong zone. Fix it there and the clamp becomes a safety net.
  - `NowView.thanks(count:)` is now unused (kept in case the summit cards move under a Summit section in More).
  - "Lisbon · 9–12 Nov" still appears in `OnboardingView` and the pre-summit countdown card (only shown before the
    summit); harmless now.
  - PTPlaces and PTLocal both define public types named `Look`, `Provenance`, `Gravity`, `MapEntry`,
    `NewsroomDashboard`, `Source`, `Voice`. A shell file importing both must not use those names unqualified.
  - Changing `apps.json` makes `affected.py` select all four apps; avoid touching it unless a package is added.

## Lessons

1. Keep the integration in one shell file (`PlacesWiring.swift`) so every cross-package decision is visible in one place
   and neither package grows a dependency on the other.
2. Set environment-based hooks above the navigation stacks, not on the root view of a tab.
3. Prefer the producing package's own adapter (`AlgarveMapTown.fromLocalStore`) over rebuilding its model from another
   package's data; it avoids name clashes and stays correct when that package changes.
4. With builds costing ~25 minutes on shared macOS runners, batch: one "ready at <sha>" per coherent change, and
   supersede clearly if a newer sha replaces one the conductor may already be building.
5. `@Sendable` closures cannot touch `@MainActor` singletons; find a nonisolated source (here the Keychain).

## First steps for the next session

1. Read `briefs/2026-11-15__going-local/tonight.md` (CI rule) and this file; ask the iOS conductor which branch to work
   on and who now owns PTPlaces and PTLocal.
2. `git fetch origin dev && git checkout -B work/wire origin/dev` (or the branch you are given).
3. Read `Apps/PrompTugal/Shell/PlacesWiring.swift` and `Packages/PTPlaces/Sources/PTPlaces/PlacesHooks.swift`
   (plus `PlacesCredit.swift`, `Comments.swift` for `PlacesTalk`); grep `placesRegionMap` for the region map hook.
4. Run `python3 scripts/apps/check_apps.py` before every commit that touches `apps.json` or the project.
5. Push only to your work branch; report "ready at <sha>" to the conductor; never push `dev`/`main`/`night/*`.
