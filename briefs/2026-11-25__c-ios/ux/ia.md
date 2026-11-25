# Information architecture: PrompTugal.news, local news town by town (c.ios.ux, 25 Nov 2026)

> Read against `Apps/PrompTugal/Shell/Destinations.swift` at candidate c2 (`5404498`). Proposal only: the shell and the packages belong to their builders; every change below goes through the conductor.

## The idea in one line

A reader picks a town, sees what is happening there, and can open the source of every line. Everything in the tab bar serves that; the summit becomes one archived event behind a single row.

## Tabs (iPhone tab bar, iPad sidebar "Tabs")

| Today | Proposal | Why |
| --- | --- | --- |
| **Places** (`places`) | **Keep, first tab.** Rename the tab label "Towns"? No: keep "Places" (it covers Portugal and the district capitals too). | It is the product. It already opens first. |
| **News** (`news.home`): Latest, Newsletter, Stories, Interviews; header "Independent coverage from Lisbon" | **Keep, re-scope.** Header "The newsroom's stories, every one sourced". Segments: Latest, Stories, Newsletter. Drop "Interviews" (summit replays) to the Lisbon summit archive. | The national feed is useful next to the towns, but "from Lisbon" and summit interviews tell a reader this is a tech-summit app. |
| **Now** (`now`): greeting, "Lisbon · date", summit phases, Your towns, Latest news | **Keep, rebuild as "Your towns".** Followed towns first, each with its latest story and its "Now in" line (weather, warnings); then "Since you last looked" (`since.json`, bigger-pass workstream 1). Remove the summit phase machine from the public build. | Today the first card a reader can meet is "The agenda could not be loaded" or "Start your program / Choose talks". Now is the personal front page; it should be about the reader's towns. |
| **Explore** (`explore`): Speakers, Companies, Places of the summit | **Keep, rebuilt for the news** (c.ios.explore is on it): organisations (115 companies), stories (136), events (34), library and videos, all searchable. Rename segments to match. | "Speakers" and "Search talks, speakers" are summit words. The newsroom's companies and stories are the natural search space for "who is doing what in my town". |

Four tabs plus the More button stays: it fits the iPhone tab bar without a "More" overflow.

## More (sheet on iPhone, sidebar group on iPad)

| Today (id) | Proposal | Why |
| --- | --- | --- |
| My program (`team.schedule`) | **Move** into "Lisbon summit 2026" | Summit-only. |
| Venue map (`map`) | **Move** into "Lisbon summit 2026" | Summit-only; its name also clashes with the Algarve map. |
| Reminders (`settings.reminders`) and More > Reminders row | **Move** into "Lisbon summit 2026" | "Before each pick" only makes sense for talks. It also triggers the notification prompt via seeded picks. |
| Calendar toggle (`PickCalendarToggle` in More) | **Move** into "Lisbon summit 2026" | "The app adds talks" is summit copy. |
| "At the summit / Meet RiskMandate, booth A1-30" (`StandSection`) | **Remove** | The stand was on 12 Nov. A dated booth line reads as stale. |
| "Show the welcome again" (summit onboarding) | **Keep the row, new screen** (see journeys.md, J1) | The welcome must explain towns and sources, not talks. |
| Newsroom (`local.newsroom`) | **Keep**, top of More, read-only | Hard rule; it is also the honesty story ("who wrote this"). |
| CI status (`local.ci-status`) | **Keep**, but in an "About this build" section at the bottom, with a one-line plain explanation | Hard rule to keep. "How long a push takes to reach TestFlight" is developer language; a reader needs "Is this app up to date?". |
| Ask and summarise (`local.ask`) | **Merge**: the town summary already sits on each town page (`TownSummaryCard`) and Near me on Places home (`NearMeView`). Keep the More row only as "On this device" (Apple Intelligence status, persona switch). | Three features under one row with a jargon name; two already live where the reader needs them. |
| Reading credit (`local.credit`) | **Hide in this version** (keep the id routable for testers) | No purchase exists; a meter with prices and "top up" in a free app with "nothing to purchase" (App Review notes) confuses readers and reviewers. |
| Appearance, About links, independence note, version | **Keep** | Standard. Fix the independence copy (see journeys, J1-07). |
| *(new)* **Lisbon summit 2026** | **Add** one row, near the bottom: My program, Venue map, Reminders, Calendar, summit Interviews, summit Explore (Talks, Speakers) | Keeps every summit screen and `promptugal://open/<id>` link working for those who used it, out of the reader's way. |
| *(new)* **How we source** | **Add**: one screen that explains live / saved / built-in, "Simulated", "Read at the source", and links to `FeedClient.disclosure` | Journey 3 needs one place that defines the badges the app uses. |

Proposed More order: Newsroom · How we source · On this device · Appearance · Show the welcome again · About (links, independence) · Lisbon summit 2026 · About this build (version, CI status).

## Destination ids

No id is removed: moved screens keep their ids, so links and reminders still open. The shell change is one new group ("Summit") in `PublicDestinations.groups`, `listed: false` on the moved rows, and a new `summit` destination listing them. That is for the shell owner via the conductor (spec S1 in specs.md).

## Newsroom and CI status (kept, as required)

- Newsroom stays read-only: no steer, no ask, no "connect your conductor" button (its GapNote already says so; keep that text but drop "comes next", which promises a feature).
- CI status stays; the screen should say its own data age from `ci-status.json` (it is hours stale; onboarding.md).
