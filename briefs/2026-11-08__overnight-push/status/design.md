# Status · Design and native UI

> The shell is the app's root on dev: every section is reachable on iPhone and iPad. Team and vault screens are wired in; collab's land with night/collab. Now polishing every screen on both devices.

Branch: `night/design` (rebased on `night/platform`) · Last update: 05:30 UTC

## Done

- **Design system** (`PrompTugal/Design/`). See "The design system" below.
- **App shell** (`PrompTugal/Shell/`): `AppShell` (iPad `NavigationSplitView` sidebar with ten sections; iPhone four tabs plus More), `Destinations.swift` (the registry), `WebPage` (a web page in the shell, logged to Debug → Network), the **web twin** (a "Web original" button that opens the web page beside the native screen on iPad, as an inspector column), `SettingsView` (who I am, debug mode, triple tap on the version). Keyboard: ⌘1–⌘8 sections, ⌘, Settings, ⌘⇧D Debug. Deep links: `promptugal://open/<destination id>`.
- **Feeds** (`PrompTugal/Dashboards/`): `RemoteFeed` loads one public JSON file through the platform's `HTTPClient`, decodes it off the main actor, caches the bytes in Caches for offline use. `WireModels.swift` holds lenient models (every field optional) for `me.json`, `people/<id>/app/data.json`, and the newsroom's `dashboard`, `status`, `stories`, `decisions`, `desks` and `newsletter` JSON.
- **Native dashboards**:
  - **My day** (`TodayView`): stand-up countdown with my briefing one tap away, only-you / decide / overdue / soon tiles, most urgent, decisions waiting, what my agents did, messages. Asks "who are you?" the first time.
  - **The team** (`TeamDashboardView`): a card per person (colour, level 1–6, counts, ten-day sparkline, agents), a stacked bar chart of who needs help, everyone's next stand-up on one time line. Tap a person for their day.
  - **Agents** (`AgentsDashboardView`): the newsroom's 24-hour **wake grid redrawn in Canvas** (same legend as the web: ● ◐ ○ ✕ H • ·), tap a row for that agent's last wake, next steps and asks; runs per hour (Swift Charts); hand-offs; "mine only" filter.
  - **Briefed** (`BriefedView`): my stand-up and briefing, decisions from my command centre (with the recommendation), the newsroom's open decisions, what the agents ask, newsletters, and the briefs on the web.
  - **Newsroom** (`NewsroomStatusView`): the pipeline as connected stages, the story board as columns, the desks' funnel, build order, what waits on a person, agents by status.

## The design system

| Piece | What it is |
| --- | --- |
| Colours (`Palette`) | From the app icon and AccentColor: ink `#111318`, red `#AD222B` (dark `#FF868A`), green `#0B6B1E` (dark `#6FCF7F`), paper `#F5F1EA` (dark `#14161B`), card, rule, muted. Plus amber (stale, partial) and blue (web). Dark values are the website's. `Palette.series` for charts; `Palette.stable(key)` gives any agent or person the same colour everywhere. |
| Type (`Typo`) | Serif (New York) for headlines and titles, like the brand; SF for interface text; SF Mono for data. All text styles, so Dynamic Type works. |
| Spacing (`Space`) | A 4-point grid: 4, 8, 12, 16, 24, 32. Card radius 14. |
| Components | `Card`, `TitledCard`, `Kicker`, `ScreenHeader`, `StatTile` (with tone and sparkline), `StatGrid`, `CountPill`, `Sparkline`, `Avatar`, `LevelBar`, `InfoRow`, `Page`, `Columns` (two columns on iPad, one on iPhone). |
| Kind badge | `KindBadge`: Native (green), Web (blue), Hybrid (amber). `.surfaceKind(_:)` puts it in the toolbar of every screen when debug mode is on. |
| States | `StateView` (loading, error with retry, empty), `FreshnessLabel` ("Updated 4 min ago", amber when older than 30 minutes or offline), `GapNote` (what the app cannot show, and why). |

- **CI green** at `d9733c8`: build, unit tests, SGitVault tests and the simulator app, Xcode 26.6.
- **News** (`PrompTugal/News/`): the feed (lead story plus a grid), the newsletter editions read **natively from their plain-text email** (headings, bullets, links), the story board by column, and the **graph explorer drawn natively**: all 1,688 nodes and 2,863 edges from `api/v1/graph/explorer.json` in one Canvas, at the layout the website's build computed. Pinch, pan, filter by world, search, tap a node for its links as the site's own sentences ("X is listed under Y"), and find the shortest path between two nodes.
- **Observability** (`Dashboards/Observability/`): agent wakes by hour (stacked by outcome), runs by day and kind, the team's ten days, desk runs, and **endpoint health measured by the app** (median time, failures, bytes per endpoint). The gap is stated on screen: reader traffic is sealed in a vault, so there is no public JSON; the native vault reader will open it.
- **Debug** (`PrompTugal/Debug/`): Network (platform's `HTTPLog`, host filters, timing bars, bytes by host), Vault traffic (`VaultTrafficLog`, kind filters, and a **decrypt pipeline** for one object: fetch → verify SHA-256 → key → AES-GCM → inflate → JSON), Storage (feeds, files, each website's data kinds), Keys (keychain names and protection only; the query never asks for data), Build (`BuildInfo` plus the versions of the sites read).
- **Widget and Live Activity designs** (`Design/WidgetDesigns.swift`): small and medium "Next" widgets and a Lock Screen session activity, as plain views the widget target can use.
- **Per Dinis via the conductor:** debug mode on by default (the team is the first audience); every screen has an iPhone (compact) and an iPad (regular) preview, with sample data (`PreviewSamples`, made-up people).
- **Team wiring prepared** (local commit, applied once `night/team` is on dev): `.teamFeatures()` on the shell; MyDayView, PlannerView, TeamHomeView, ReadingCreditView, ReminderSettingsView and BridgeLogView in the registry; the bridge hooks in `WebPage`.

- **03:12** Merged `origin/night/platform` (normal merge; platform's files as platform has them), then `origin/dev`. No more rebases.
- **Native command centre** (`CommandCentreView`): a person's board issues by workstream, filters (open, overdue, named for me, done), search, and a status bar. Opens from My day and from any teammate.
- **My agents' time line** on Agents; graph legend folds on iPhone; stand-up card stacks at accessibility text sizes.
- **Vault wiring prepared** (local commit): `VaultHomeView()` under Vault, and `VaultSession.shared.log` as the Debug log.

- **04:10–04:30** Team wiring applied (`.teamFeatures()`, MyDayView, PlannerView, TeamHomeView, ReadingCreditView, ReminderSettingsView, BridgeLogView, the bridge hooks in `WebPage`); vault wiring applied (`VaultHomeView`, Debug → Vault traffic on `VaultSession.shared.log`, Debug → Keys lists the vault session's key inventory). Platform made `AppShell()` the root on dev (3b77e1c).
- **Agenda, native** (`News/AgendaView.swift`): now, then by day, search, "my picks only", and a star that writes to the one schedule (`ScheduleStore`). Replaces the old reader inside the shell, which nested its own split view and tabs.
- **No nested navigation:** a destination can say it owns its navigation (`ownsNavigation`, the vault's three-column split view). On iPad the shell's sidebar steps aside; on iPhone it opens full screen from More.
- **One identity:** `IdentitySync` keeps the design screens' "who am I" and the team session's `TeamIdentityStore` in step, both ways.
- **Debug → Native and web:** how many screens are native, hybrid or web, screen by screen.

- **Wall** (`Dashboards/WallView.swift`, Today → Wall): the team's load, the agents' 24-hour wake grid, the pipeline, the latest runs and the next stand-up on one screen that refreshes every five minutes and keeps the iPad awake. For a stand or a desk at the summit.
- **Collab hooks:** `WebPage` tells Ask which page is on screen (`CollabHooks.noteCurrentPage`); Debug → Collaboration and AI (`CollabDebugPanel`); the Keys panel lists collab's keys by presence only.
- **Launch arguments** for screenshots and UI tests: `-PTDestination <id> -PTSampleData -PTMe <id>` (platform's screens.yml uses them).
- **CI:** dev run 104 is the first fully green integrated run (build, SGitVault, iPhone and iPad tests), with design's code in it.

## In progress

- CI on the newest head (runners are queued across six sessions; a run waits 10–20 minutes).

## Next

1. Apply the team wiring when `night/team` merges.
2. iPhone pass on every screen at the largest Dynamic Type sizes.
3. Switch Today and Team to the team session's `TeamStore` models (drop my `Wire` copies of me.json and data.json).
4. Vault traffic against the real reader when `night/vault` lands.

## Blocked

Nothing.

## Needs from others

- **Collab:** none; your Destinations entries come in with night/collab, and I will only move them if needed.
- **Editor:** the build log can link the design system section above.
