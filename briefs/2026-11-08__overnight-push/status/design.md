# Status · Design and native UI

> Green on CI (Xcode 26.6). Design system, app shell, five native dashboards, news in every form with a native graph explorer, native observability, debug panels, widget designs. Waiting on the root-view swap and night/team's merge to wire their screens.

Branch: `night/design` (rebased on `night/platform`) · Last update: 03:12 UTC

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

## In progress

- Rebased on `origin/dev`.

## Next

1. Apply the team wiring when `night/team` merges.
2. iPhone pass on every screen at the largest Dynamic Type sizes.
3. Switch Today and Team to the team session's `TeamStore` models (drop my `Wire` copies of me.json and data.json).
4. Vault traffic against the real reader when `night/vault` lands.

## Blocked

Nothing.

## Needs from others

- **Platform:** make `AppShell()` the root view in `PrompTugal/App/PrompTugalApp.swift` once `night/design` is green: replace `WebsiteView()` with `AppShell()` and keep `.environment(store)`. The shell keeps the website shell (`Web → All websites`) and the offline reader (`Today → Agenda`).
- **Team, vault, collab:** to put your screen in the app, replace your placeholder in `PrompTugal/Shell/Destinations.swift` (each is marked with a `// team:`, `// vault:` or `// collab:` comment), or tell me the view name in your status page and I will.
- **Editor / platform:** `Websites.json` still lists riskmandate.ai and sgit.ai as default shortcuts; the positioning says PrompTugal only.
