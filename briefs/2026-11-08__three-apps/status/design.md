# Status · Design (three apps)

> PTNews is moved and pushed but has never compiled. Run 294 was cancelled by the conductor: team's PTWeb (6cccf88) is uncompiled, so the run would only repeat its errors. I do not redispatch until split/team is green; then I merge it and dispatch once. PublicShell is not started (waits for phase 4).

Branch: `split/design` · Last update: 8 Nov, 02:52 UTC · Last CI run: iOS run 294 on 4430e67, cancelled by the conductor, no result

## Done
- Read the three-apps README and contracts, the overnight rules, and the App Review readiness page.
- Mapped Shell, Dashboards, Debug and News (below).
- Drafted the PrompTugal app's shell and the sharing options.

## Decisions (conductor)
- AgendaView and ReaderStore go to PTAgenda (team moves them; ReaderStore gets the schedule injected). PTAgenda must not depend on PTNews.
- PTNews gets `NewsSource` and `NewsFeeds`; `DashboardData` forwards to it. Each app adds `extension ReaderStore: NewsSource {}` (or a small adapter).
- Shell option C: shared parts in `Packages/PTCore/Sources/PTCore/Shell/` (mine); each app keeps its own root and Destinations.
- Team app scheme is `ptteam://`; PrompTugal keeps `promptugal://`. Reminders and links take the scheme as a parameter, not hard-coded.

- Editor needs code markers for site labels: PrompTugal root struct `PublicShell` (search `PublicShell(`); Team keeps `AppShell(` and `.teamFeatures()`. Sent the id list to the conductor.

- Merged `split/apps` (7d28094): `Apps/PrompTugal/` has the project, `PrompTugalApp.swift` (root `PublicShell()`, apps owns it) and a placeholder `Shell/PublicShell.swift` (mine). `Shell/` is a synchronized folder, so new files need no project edit.

## In progress
- Waiting for PTCore. `PublicShell` needs Design and the shared shell parts; with only PTVaultUI on dev I would be writing against types that do not exist yet. I start the moment PTCore is on dev.

## Next
1. Phase 3: merge `origin/dev`, move PTNews (with the fixes in section 1 once approved), push, read CI.
2. Phase 4: `Apps/PrompTugal/` screens and Destinations; the Team app's shell keeps working.

## Blocked
- Nothing yet. Phase 2 is the gate.

## Needs from others
- **Conductor:** answers to the five questions in section 1.4.
- **Platform:** `RemoteFeed`, `LoadPhase`, `FeedCache`, `enum Wire {}` with `LooseText`, `LooseScalar`, `WireDate` into PTCore, plus `Event`, `Story`, `Lisbon`, `FeedClient` from `Content.swift`.
- **Collab:** `AskView.swift:196` and `AIContext.swift:320` use `TeamFeatures`; PTAsk cannot, and the public app has no TeamFeatures.

## 1. PTNews: what moves, and what it needs from outside

### 1.1 What is in News/ today
| File | Lines | Uses from outside News/ |
| --- | --- | --- |
| `NewsHomeView.swift` | 268 | `ReaderStore` (news, newsUpdated, newsUnavailable, refresh), `DashboardData` (newsletter, board, refreshAll), `Wire.Edition`, Design, `WebPage`, `FeedClient`, `Story`, `Lisbon`, `HTTPClient` |
| `GraphExplorerView.swift` | 401 | `DashboardData.graph`, `RemoteFeed`, Design, `WebPage`, `FeedClient` |
| `GraphModel.swift` | 176 | `FeedClient`, Palette |
| `AgendaView.swift` | 204 | `ReaderStore`, `ScheduleStore`, `Event`, `Lisbon`, `WebPage` |

The graph is already in `News/`. There is no `Dashboards/Graph*` file; the graph feed is a property of `DashboardData`.

### 1.2 Where it breaks the package graph (PTNews → PTCore, PTWeb only)
1. **`AgendaView` needs `ScheduleStore`** (PTAgenda). PTNews cannot depend on PTAgenda. It is an agenda screen, not a news screen. **Proposal:** it moves to PTAgenda (team's package), not PTNews. `TodayView` (Team) uses it too and imports PTAgenda anyway.
2. **`ReaderStore` holds both the news cache and the agenda cache** in one `content.json`, and calls `TeamFeatures.shared.schedule` and `NowNextPublisher`. **Proposal:** PTNews declares a small protocol, `NewsSource` (`news`, `newsUpdated`, `newsUnavailable`, `refresh()`), and an environment key. `NewsHomeView` reads that instead of `ReaderStore`. `ReaderStore` conforms with one extension, in the app target. No change to the cache or to behaviour. `ReaderStore` itself goes to PTAgenda with the schedule passed in instead of `TeamFeatures.shared` (team's call).
3. **`NewsHomeView` and `GraphExplorerView` read `DashboardData`** (the Team dashboards' store). **Proposal:** PTNews owns `NewsFeeds` (`@Observable`): `newsletter`, `board`, `graph`, plus `refresh`. These are the same `RemoteFeed` instances with the same URLs. `DashboardData` keeps its property names by forwarding to an instance of `NewsFeeds` (`var board: … { news.board }`), so the Team dashboards (`NewsroomStatusView`) do not change. The Team shell puts `data.news` into the environment; the public app creates its own.
4. **`Wire.Newsletter`, `Wire.Edition`, `Wire.StoryBoard`** (in `Dashboards/WireModels.swift`) go with PTNews as `extension Wire`. That needs the empty `enum Wire {}` and the loose decoders in PTCore (platform). `GraphExplorer` already sits in `GraphModel.swift`.
5. **`RemoteFeed`, `LoadPhase`, `FeedCache`** are generic and only use `HTTPClient`. They go to PTCore (platform), or PTNews gets them and Dashboards imports PTNews. PTCore is cleaner.
6. **`NewsroomAPI.url(_:)`** (3 lines) moves with `NewsFeeds` into PTNews.

### 1.3 What PTNews imports
- **PTCore:** Design (Palette, Space, Typo, Page, Card, Kicker, StateView, FreshnessLabel, surfaceKind), `HTTPClient`, `Event`/`Story`/`Lisbon`/`FeedClient` (from Content.swift), `RemoteFeed`, `Wire` base.
- **PTWeb:** `WebPage` (and `WebsiteView` for the "All websites" screen, which lives in the app's Destinations).
- **TeamFeatures:** nothing. After the three fixes, PTNews has no reference to the Team's stores.

### 1.4 Questions for the conductor
1. `AgendaView` to PTAgenda instead of PTNews? (I recommend yes; team moves it, or I do it in phase 3 with team's agreement.)
2. `NewsSource` protocol and `NewsFeeds` in PTNews as in 1.2? (Recommended. Small, no behaviour change.)
3. Who moves `ReaderStore`, and where? (Recommend team, to PTAgenda.)
4. Platform puts `RemoteFeed`/`LoadPhase`/`FeedCache`/`Wire` base/`Event`/`Story`/`Lisbon`/`FeedClient` in PTCore in phase 2?
5. Should the Team app get its own URL scheme (`promptugal-team://`) so the two apps do not both claim `promptugal://open/…`? (Platform.)

## 2. Which Shell, Dashboards and Debug types each app needs
| Item | Team | PrompTugal |
| --- | --- | --- |
| `AppShell`, `Destinations` (Team list), `ShellSection` | yes (stay) | own, smaller (section 3) |
| `PrivacyCover`, `ShellLink`, `LinkedPage` | yes | yes (shared, section 4) |
| `SampleMode`, `SampleBanner`, `LaunchOptions` sample flags, `PreviewSamples` | yes | no (dropped) |
| `IdentitySync`, `ChooseIdentityView`, "Who are you?" | yes | no |
| `SettingsView` (team picker + About) | yes | new `PublicSettingsView`: About, Privacy, Support, version, independence note, Reminders; debug switch only in DEBUG |
| `SupportLinks` | yes | yes (move to PTCore; two lines of URLs) |
| `DashboardData`, `TeamDashboardView`, `AgentsDashboardView`, `BriefedView`, `CommandCentreView`, `NewsroomStatusView`, `ObservabilityView`, `TodayView`, `WallView` | yes | no |
| `Debug/` panels | all | only Network and System panels, in DEBUG builds; none in Release |
| `LaunchOptions` (`-PTDestination`) | yes | yes, DEBUG only (screenshots) |

## 3. The PrompTugal app's shell (plan)

### Destinations
Ids stay the same as the Team app's, so `promptugal://open/<id>` links and reminders keep working in both.

| Section | Destination | id | Screen | From |
| --- | --- | --- | --- | --- |
| Summit | Agenda | `reader.agenda` | `AgendaView` | PTAgenda |
| Summit | My day | `team.schedule` | `MyDayView` (picks) | PTAgenda |
| Summit | Plan my day | `team.planner` | `PlannerView` | PTAgenda |
| News | News | `news.home` | `NewsHomeView` | PTNews |
| News | Graph | `news.graph` | `GraphExplorerView` | PTNews |
| Ask | Ask | `collab.ai` | `AskView`, with the consent sheet | PTAsk |
| Web | PrompTugal.news | `web.promptugal` | `WebPage(FeedClient.site)` | PTWeb |
| Web | All websites | `web.all` | `WebsiteView` | PTWeb |
| Personal | Vault (optional) | `vault` | `VaultHomeView` | PTVaultUI |
| Settings | Settings | `settings` | `PublicSettingsView` | Apps/PrompTugal |
| Settings | Reminders | `settings.reminders` | `ReminderSettingsView` | PTAgenda |
| Debug (DEBUG only) | Debug | `debug` | Network + system panels | PTCore panels |

Left out: Today (team), The team, My command centre, Messages, Where is everyone, Team home, Reading credit, What my agents do, Wakes/Reports (web), Briefed, Pulse/Board (web), Newsroom, Observability, Wall, Coordination, "Who are you?", sample data.

### iPhone
Four tabs and More, as today: **Agenda** (`reader.agenda`), **My day**, **News**, **Ask**, then **More** (Plan my day, Graph, Web, Vault, Settings, Reminders).
- **First screen: Agenda.** It works offline, needs no key and no identity, and is what an attendee or a reviewer wants first.

### iPad
A sidebar with the sections above (Summit, News, Ask, Web, Personal, Settings). First selection: Agenda. Vault keeps `ownsNavigation` (its own columns). ⌘1–⌘6 jump to a section, ⌘, opens Settings. The "Ask beside any screen" button and ⌘K stay (`askAnywhere`), once it is in PTAsk.

### Release rules (App Review pack)
- Ask consent sheet before the first request, context off except the public agenda (PTAsk; unchanged).
- Privacy cover while the scene is inactive.
- Settings links: Privacy, Support, "About this coverage"; independence note under it.
- Debug: no panel, no switch, no inspectable web views in Release. `DebugMode.defaultOn` is already false in Release; the public Settings has no toggle outside `#if DEBUG`, and the ⌘⇧D shortcut is also DEBUG only.
- No team names anywhere in the public target's Info or code. A grep for `TeamFeatures`, `DashboardData`, `TeamEndpoints` under `Apps/PrompTugal/` and the packages it links should come out empty. I will add that as a test in the app's tests.

## 4. Sharing the shell between the two apps
**Option A, one generic shell (`ShellKit` in PTCore).** `AppDestination` takes a plain group title instead of the `ShellSection` enum; `ShellRoot(destinations:, header:, badge:, overlays:)` draws the sidebar, tabs and More. One code path. Cost: rewrites the shell the Team app uses tonight (enum to struct, hooks as closures), so it can break Team.

**Option B, two small shells.** Copy ~250 lines per app. No shared risk, but fixes land twice.

**Option C (recommended): shared parts, two small roots.** PTCore gets only the pure UI parts (git mv, `public`): `AppDestination` (with a `group: String` instead of the enum), `SidebarRow`, `MoreRow`, `PrivacyCover`, `ShellLink`/`LinkedPage`, the `destinationID` modifier, `SupportLinks`. Each app keeps its own root (`TeamShell`, `PublicShell`) and its own `Destinations` list. The Team root is today's `AppShell` with those parts imported; the public root is ~150 lines. The Team app changes by imports and one enum-to-string edit. I would do this in phase 4, after the Team files are in `Apps/Team/`, so phase 3 stays small.

I need a yes from the conductor to put those parts in PTCore (platform owns it).

## Last CI run
None. Nothing moved yet.

## Handoff (8 Nov, 01:35 UTC)

**Head:** `split/design` at the commit named in the handoff message to the conductor (this page's own commit on top of `4430e67`). `4430e67` is the last code commit.

**Last CI run:** iOS run 294 (id 42434478548), `workflow_dispatch`, app=all, on `4430e67`. Status when I stopped: queued. Read it first: `mcp__github__actions_list list_workflow_runs` for `ios.yml`, branch `split/design`. Do not cancel it. If it fails, read `get_job_logs` with `failed_only`.

**Done**
- Merged `origin/dev` (PTCore, phase 2), `split/apps` (7d28094) and team's PTWeb (6cccf88) into `split/design`.
- PTNews moved with `git mv`: `NewsHomeView`, `GraphExplorerView`, `GraphModel` are in `Packages/PTNews/Sources/PTNews/`.
- New in PTNews: `NewsSupport.swift` (`NewsSource` protocol with the `newsSource` environment key, `EmptyNewsSource`, `NewsroomAPI`, `NewsFeeds` with newsletter, board, graph) and `NewsWire.swift` (`Wire.StoryBoard`, `Column`, `BoardStory`, `Newsletter`, `Edition`, all public; cut from `Dashboards/WireModels.swift`).
- `DashboardData` now owns `let news = NewsFeeds()` and forwards `board`, `newsletter`, `graph` to it. `NewsroomAPI` moved out of `DashboardData.swift`.
- App side: `PrompTugal/App/ReaderStore+News.swift` (`extension ReaderStore: NewsSource {}`), `PrompTugalApp` sets `.environment(\.newsSource, store)`, `AppShell` sets `.environment(data.news)`.
- Graph tests (`GraphIndexSafetyTests`, graph layout test) moved from `PrompTugalTests/DesignReviewTests.swift` to `Packages/PTNews/Tests/PTNewsTests/GraphTests.swift`.
- `Package.swift` of PTNews has `swiftLanguageModes: [.v5]`, like team's packages.
- One behaviour change: pull-to-refresh on News now reloads only the newsletter and the story board (`NewsFeeds.refresh`), not the team and newsroom feeds.

**Half-done / not done**
- PTNews has not been built. It needs `WebPage` and `.webTwin` from PTWeb (merged, public in `Packages/PTWeb/Sources/PTWeb/Web/WebPage.swift`), but team's own CI for 6cccf88 was not green yet when I stopped. Expect compile errors to fix from run 294 (public API, missing `import`s).
- `AgendaView` and `ReaderStore` are still in the app; team moves them to PTAgenda. When they move, check `NewsHomeView` still sees `ReaderStore: NewsSource` (the extension file must stay with the app or go with `ReaderStore`, but PTAgenda must not import PTNews).
- `AppShell.swift:98` still has `url.scheme == "promptugal"`. Platform is adding `enum AppLinks { public static var scheme }` to PTCore (commit ce3602e on `split/platform`). When it is on dev, change it and every other hard-coded scheme in `Shell/AppShell.swift` and `Shell/Destinations.swift` to `AppLinks.scheme`.
- `PublicShell` is not started (still the apps session's placeholder).

**Exact next steps**
1. Read run 294. Fix PTNews until green. Then dispatch again (`app=all`), and when green send `@parent` the branch, commit and run number.
2. Merge `origin/dev` again when team's PTWeb/PTAgenda land there; fix anything that moves.
3. Switch the link scheme to `AppLinks.scheme` once it is on dev.
4. Phase 4: build `Apps/PrompTugal/Shell/PublicShell.swift`, `Destinations.swift` and `PublicSettingsView.swift`, on top of `split/apps` (project and entry point are the apps session's; `Shell/` is a synchronized folder, so new files need no project edit). Shared shell UI parts go in `Packages/PTCore/Sources/PTCore/Shell/` (mine, per the conductor's ruling). Plan: sections 3 and 4 of this page.

**What I gave the editor (the conductor passed it on)**
- Root marker: `PublicShell` (search `PublicShell(`). Team keeps `AppShell(` and `.teamFeatures()`.
- Destination ids, same as Team's: `reader.agenda`, `team.schedule`, `team.planner`, `news.home`, `news.graph`, `collab.ai`, `web.promptugal`, `web.all`, `vault`, `settings`, `settings.reminders`, `debug` (DEBUG builds only).

**Conductor rulings in force:** AgendaView and ReaderStore go to PTAgenda (team moves them); `NewsSource` plus `NewsFeeds` in PTNews; shell option C (shared parts in PTCore `Shell/`, each app its own root and Destinations); Team's scheme is `ptteam://`, PrompTugal's is `promptugal://`; apps owns `PrompTugalApp.swift` and Config, design owns `Apps/PrompTugal/Shell/`.

**Scheduled triggers:** all three of mine are deleted.

## Update (8 Nov, 01:55 UTC, design.B)
- Took over from account A. Read the plan, contracts (section 7), handoff and this page.
- Run 294 was cancelled by the conductor. Rule from the conductor: do not redispatch until split/team is green; then merge split/team into split/design and dispatch once.
- Read PTNews against the public APIs of PTCore and PTWeb (`RemoteFeed`, `Wire`, `LooseText`, `Story`, `FeedClient`, `WebPage`, `webTwin`, Design components). Found nothing to fix by reading. Real errors will show on the first compile.
- Waiting for: team's PTWeb green; `AppLinks.scheme` on dev (then switch the hard-coded schemes in `Shell/AppShell.swift` and `Shell/Destinations.swift`); the conductor's word that phase 4 has started (PublicShell).

## Update (8 Nov, 02:52 UTC, design.B)
- Still holding. Team's run 300 on 1bf25c5 is queued, so split/team is not green. AppLinks.scheme is not on dev (dev d519d14).
- Conductor ruling (02:25): when split/team is green, merge origin/dev and split/team into split/design, then dispatch ios.yml once with app=all, runner=self-hosted.
- Nothing pushed to split/design except this page. PublicShell is not started.
