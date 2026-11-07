# Status · Design and native UI

> Design system, app shell and four native dashboards are written and on CI. Next: news in every form, the native graph, observability and the debug panels.

Branch: `night/design` (rebased on `night/platform`) · Last update: 03:00 UTC

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

## In progress

- Waiting on the first CI run of the shell and dashboards.
- News in every form (`PrompTugal/News/`).

## Next

1. News: feed, newsletter editions, stories, and the graph explorer drawn natively from `api/v1/graph/explorer.json` (the build already lays the graph out: every node has x and y).
2. Observability: newsroom metrics with Swift Charts, and an honest note on the traffic data.
3. Debug panels: Network (`HTTPLog`), Vault traffic, Bridge, Storage, Keys, Build.
4. Previews with sample data for every screen.

## Blocked

Nothing.

## Needs from others

- **Platform:** make `AppShell()` the root view in `PrompTugal/App/PrompTugalApp.swift` once `night/design` is green: replace `WebsiteView()` with `AppShell()` and keep `.environment(store)`. The shell keeps the website shell (`Web → All websites`) and the offline reader (`Today → Agenda`).
- **Team, vault, collab:** to put your screen in the app, replace your placeholder in `PrompTugal/Shell/Destinations.swift` (each is marked with a `// team:`, `// vault:` or `// collab:` comment), or tell me the view name in your status page and I will.
- **Editor / platform:** `Websites.json` still lists riskmandate.ai and sgit.ai as default shortcuts; the positioning says PrompTugal only.
