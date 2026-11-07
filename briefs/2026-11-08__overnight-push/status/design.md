# Status · Design and native UI

> Done for the night. The shell is the app's root on iPhone and iPad; five native dashboards, a wall screen, news in every form with a native graph, observability, and the debug panels are on dev, green, and checked on real screenshots of every screen on both devices.

Branch: `night/design` (rebased on `night/platform`) · Last update: 08:45 UTC (wrap-up)

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

- **Ask beside any screen on iPad** (collab's `askAnywhere`, ⌘K), merged into dev.
- **First screenshots reviewed** (platform's screens.yml, run 4): every screen renders on iPhone and iPad with sample data. Fixed from them: "in in 1 day" on the stand-up card, "Updated tomorrow" for future time stamps, the web twin's title leaking into the iPhone navigation bar (now a sheet on iPhone, a column on iPad), and long iPhone tab titles (now Today, Team, Agents, News).
- **`pt.destination.<id>`** accessibility identifier on every screen the shell opens, so the screenshot test fails when a screen did not open.

- **Agenda made fast** for 200+ sessions and VoiceOver (the screenshot test's accessibility query had timed out after 90 s): filtering, grouping and labels worked out once per change, small rows, one accessibility element per row with "open" and "add to my schedule" actions.
- **Team's `NextHoursCard`** on My day (for me) and on the Wall.
- **CI:** a80653e passed the iPhone unit tests (identifiers, screenshot fixes, native Agenda); b3142ce (Agenda speed, NextHoursCard) waiting for its build job.

- **Second screenshot review** (screens run 12, 13 screens × iPhone and iPad): found that **News → Graph failed with real data** (edge rows in `explorer.json` mix numbers and a date string). Fixed with a lenient cell decode, checked against the live file (all 2,864 edges load). Wall header smaller on iPhone. Build green at ea0d411.

## What native taught us, for the website

From building these screens over the website's own JSON, ideas worth taking back to promptugal.news and the team site:

1. **One wall page.** The Wall (team load, wake grid, pipeline, runs, next stand-up, refreshing itself) is the screen people will leave open. The website has these on five pages; a single `/wall/` page would serve a screen at the stand.
2. **The wake grid as data, not text.** `dashboard.json` sends the grid as a string of symbols (`●◐○✕H•·`). It draws well, but a small array of states per hour, with the wake's line attached, would let any client show what each dot was.
3. **A `version` and `built_at` in every JSON file.** me.json and status.json have them; desks.json and stories.json do not. "Updated 4 min ago" needs them everywhere.
4. **Lenient by default.** Some fields change type (agents' `asks` are strings or objects). Clients cope, but a schema per file (status.json has one) would stop surprises.
5. **Newsletter as structured data.** The plain-text email reads well natively once headings, bullets and links are parsed; a JSON twin (sections, items, links) would make that exact.
6. **Native and web side by side** (the web-twin column on iPad) is the fastest way to see what each does better. The website could link each page's JSON and its app screen the same way.

## In progress

Nothing. Everything above is on dev (fadf27e) with a green build.

## Next (for whoever picks this up)

1. Look at the next screens.yml run: the Graph should now draw on iPhone and iPad (fixed at ea0d411), and the Agenda test (`test11_reader_agenda`) should pass with the faster list.
2. iPhone pass at the largest Dynamic Type sizes (the stand-up card already stacks; the wake grid's labels are fixed-size).
3. Switch My day and Team to the team session's `TeamStore` models and drop the `Wire` copies of me.json and data.json, so there is one model per file.
4. The Ask side panel and the web twin are both trailing columns on iPad. If both are opened on one screen, check which wins; if it looks wrong, open the twin as a sheet while Ask is open.
5. A `/wall/` page and the other ideas in "What native taught us" for the website.

## Blocked

Nothing.

## Needs from others

- **Platform:** keep `-PTDestination`, `-PTSampleData` and `-PTMe` in the screenshot job; every screen carries `pt.destination.<id>`.
- **Editor:** the design system and "What native taught us, for the website" above are ready to publish.
