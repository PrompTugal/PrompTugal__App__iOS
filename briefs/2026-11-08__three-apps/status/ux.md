# Status · UX (summit app)

> The participant experience spec for "PrompTugal: Lisbon Summit": five tabs (Now, My program, Explore, News, Ask), every screen with an id and an owner, cut to what can be built by the 16:00 UTC freeze. Owners build from this page; ux reviews every screenshot set against it.

**Session:** ux.B (Opus) · **Branch:** `split/ux` · **Updated:** 8 Nov, 11:55 UTC · **Freeze:** 16:00 UTC · **Submit:** 18:00 UTC

## The test every screen must pass

A participant opens the app at the venue, on bad Wi-Fi, and within ten seconds knows what is on now, what is next for them, and what is new. Apple's reviewer opens it on 8 or 9 November, before the summit starts, at home: the app must look complete and useful then too (see NOW-1, state A).

## 1. Structure

iPhone: five tabs, no "More" tab. iPad: the same five as the sidebar's top section, then a "More" section (Settings, Reminders, Websites).

| Tab | Id | Title (en) | SF Symbol | Root screen | Destination id |
| --- | --- | --- | --- | --- | --- |
| 1 | NOW-1 | Now | `dot.radiowaves.left.and.right` | NowView (new) | `now` |
| 2 | PROG-1 | My program | `star` | MyDayView (reworked) | `team.schedule` (keep the id: links and reminders use it) |
| 3 | EXP-1 | Explore | `magnifyingglass` | ExploreView (new, PTExplore) | `explore` |
| 4 | NEWS-1 | News | `newspaper` | NewsHomeView | `news.home` |
| 5 | ASK-1 | Ask | `sparkles` | AskView | `collab.ai` |

- **Settings** (SET-1) opens from a gear button in the toolbar of NOW-1 and PROG-1 (iPhone), and from the sidebar's More section (iPad). It holds: Reminders (SET-2), Language (opens iOS Settings for the app), Websites (`web.all`), About, Privacy, Support, Acknowledgements.
- **Removed from the tab bar and sidebar:** `reader.agenda` as a tab (it becomes the Talks list inside Explore), `team.planner` (becomes a section inside PROG-1), `news.graph` (moves into Explore, EXP-G), `web.promptugal` (the site is one tap away from every detail screen), `vault` (a participant does not need it today: hide the destination in the public build; keep the code). All old ids stay routable for `promptugal://open/<id>` so old links still land somewhere sensible: `reader.agenda` opens EXP-1 on Talks, `news.graph` opens EXP-1, `team.planner` opens PROG-1.
- Default tab on first launch: **Now**. `@SceneStorage` default changes from `reader.agenda` to `now`.
- The sidebar header text "Lisbon · 9–12 Nov" stays. No "Web Summit" in titles we control (Apple 5.2). Venue names from the data stay as they are.

## 2. NOW-1 · Now (owner: design builds the screen; team supplies `NowModel` in PTAgenda)

One scrolling `Page`, cards in this order. The screen changes with the summit's phase, worked out from Lisbon time and the agenda (9–12 Nov 2026).

**Header (all states):** `Kicker("Lisbon · <weekday day month>")`, Lisbon time in `Typo.data` (updates every minute), and the freshness pill (`FreshnessLabel`): "Updated 5 min ago" or, offline, amber "Offline · saved 08:10". Never a blocking spinner: show the saved data first, refresh behind it.

**State A · before the summit (now < 9 Nov 07:30):**
1. NOW-1a **Countdown card**: "The summit starts in 1 day" (or "in 5 hours"), with the first two official items: "Registration · Mon 9 Nov, 07:30 · Humberto Delgado Airport, Terminal 1" and "Opening Night · Mon 9 Nov, 18:00 · Centre Stage". Each row opens its detail (EXP-D).
2. NOW-1b **Start your program card** (only with 0 picks): "Pick the talks you want. We'll warn you about clashes and remind you before each one." Button "Choose talks" opens EXP-1 on Talks, day 10 Nov (the first full day). With picks: show PROG-mini (below) instead.
3. Latest news (NOW-1d), practical info (NOW-1e).

**State B · during the summit (9 Nov 07:30 to 12 Nov 23:59):**
1. NOW-1c **For you**: PROG-mini, the person's current pick (with "Now", red dot) or next pick: title (`Typo.headline`), "14:00 · in 25 min · Stage 2". If the next pick clashes with another, an amber "Clash" tag. Tapping opens EXP-D. With 0 picks: the NOW-1b card.
2. NOW-1f **On now at the venue**: up to 5 sessions running now, Centre Stage first, then by start time; each row shows "until 14:20 · Stage 8" and the pick star. "See all (12)" opens EXP-1 Talks filtered to "Now". Hidden when nothing runs (do not show an empty card).
3. NOW-1g **Up next**: up to 5 sessions starting in the next 60 minutes, by start time; row "14:30 · in 10 min · Centre Stage" plus the star. "Full agenda" opens EXP-1 Talks on today.
4. Latest news (NOW-1d), practical info (NOW-1e).
- Between days (after the last session, before the next day's first): NOW-1g shows "Tomorrow" with the first 3 sessions of the next day.

**State C · after the summit (from 13 Nov):** "Thanks for coming" card with the count of talks the person picked, then news. No empty now/next cards.

**NOW-1d · Latest news:** the three newest items from `feed.xml` (title, one-line description, "2 h ago"). "All news" opens NEWS-1. From the saved feed when offline.

**NOW-1e · Practical:** a small fixed card list shipped in the app (no feed exists for this today), each with a source link:
- Registration: "Collect your lanyard: Airport T1 (9–10 Nov) or Pavilhão de Portugal (9–12 Nov). Bring your ticket QR and photo ID." Times come from the agenda's `registration` items for today, so they stay right.
- Getting there: "Metro: red line to Oriente." Link: Metro de Lisboa summit service (source in our evidence `v-metro-web-summit-service`).
- Traffic: "Road closures around Parque das Nações, 9–12 Nov." Link: the Junta de Freguesia notice (evidence `v-parque-das-nacoes-traffic`).
- Shuttle: "Carris shuttle for participants." Link: evidence `v-carris-web-summit-shuttle` source.
Copy is final in en here; i18n writes pt-PT and pt-BR. design builds it as a static `PracticalInfo` list in `Apps/PrompTugal/Shell/`. If a source link fails review, drop the row, never the card.

**Data (team, PTAgenda):** `NowModel(events:picks:now:)` returning `phase` (before, during, between, after), `forYou` (current or next pick, with clash flag), `onNow` (≤5), `upNext` (≤5, 60 min), `tomorrow` (≤3), `countdown`. Pure function, unit-tested with fixed dates (8 Nov 12:00, 10 Nov 14:05, 12 Nov 23:00, 13 Nov). Reuses `Event.start/end` and `NowNextSnapshot` rules (a session with no end lasts 30 min).

## 3. Program flow (owner: team, PTAgenda; design reviews the look)

**Pick (everywhere a session appears):** a star button at the trailing edge of every session row (NOW-1c/f/g, EXP-1 Talks, EXP-D, PROG-1). Tap: star fills red, light haptic, a short toast at the bottom "Added to My program · Tue 14:00". If it overlaps an existing pick: toast "Added · clashes with ‹title›" in amber with "View" (opens PROG-1 scrolled to it). Undo: tap the star again. VoiceOver: "Add to my program" / "Remove from my program" action.

**PROG-1 · My program:**
- Top: a day picker (Mon 9 · Tue 10 · Wed 11 · Thu 12), defaulting to today during the summit, else 10 Nov when picks exist there, else the first day with picks.
- List by start time. Each row: time range in `Typo.data`, title, place, star. Overlapping picks are grouped under an amber "Clash · choose one" header with both rows inside; a row's swipe action "Keep this one" removes the others in the group.
- Between picks with a gap of 30+ min: a muted row "Free · 45 min" (this replaces the separate Plan my day screen; the planner's walking times are cut).
- Reminders row at the top: "Remind me 10 min before each talk" toggle. The first time the person picks a talk with reminders not decided, show the existing native "Turn on reminders?" alert once. Lead time choice (5, 10, 15 min) lives in SET-2.
- Toolbar: "Add to Calendar" (existing CalendarExport, all picks of the day) and the gear (SET-1).
- **Empty state:** star icon, "Your program is empty", "Star talks in Explore or on Now. They appear here in time order, with clashes marked." Button "Choose talks" opens EXP-1.
- Widget and Siri: unchanged; they read `NowNextSnapshot`, which already includes picks. Check that a pick or un-pick republishes the snapshot (team).

## 4. Explore (owner: deck builds PTExplore; design wires it in the shell)

**EXP-1 · Explore:** a search field at the top (searches all four lists), then a segmented control: **Talks · Speakers · Companies · Places**.
- **Talks** = today's `AgendaView` list, moved here as is (day picker, search, "Happening now" section, star per row). Add one filter chip row: All · Now · My picks. Hide the "Web Summit Lisbon" kicker (5.2); use "Lisbon · 9–12 Nov".
- **Speakers, Companies, Places**: alphabetical lists from `api/v1/people.json` (275), `companies.json` (120), `places.json` (83), with section index letters. Row: label only (the index has no more). Tap: EXP-P detail.
- **EXP-D · Talk detail:** title (`Typo.title`), day and time range, place, kind badge, speakers (from `api/v1/events/<id>.json`), the pick star as a large button "Add to My program", "Add to Calendar", "Open on promptugal.news". Offline: show what the agenda row has; speakers show "Connect to see speakers" if the detail was never loaded.
- **EXP-P · Person, company or place detail:** name, the talks linked to it (from its API file), "Open on promptugal.news". Load on open and cache; offline shows the name and "Saved details not available offline yet".
- **EXP-G · Your graph (appears after personalization):** a card at the top of EXP-1, shown only when the person has **3 or more picks**: "The people and companies behind your 5 picks", tap opens the graph. Scope: the union of `api/v1/graph/events/<id>.json` for the picks. **Cut line:** if the scoped graph is not ready by 15:00, the card opens the existing `GraphExplorerView` (full graph) and the copy becomes "Explore the summit graph". With fewer than 3 picks, no graph entry anywhere: no empty graphs.
- **Fallback if PTExplore misses the freeze:** the Explore tab shows `AgendaView` (Talks) alone, titled "Explore", with EXP-G above it. Speakers, Companies and Places wait for the next build.

## 5. News (owner: design, PTNews; collab supplies the offline feed through PTSync)

**NEWS-1:** keep NewsHomeView (Feed, Editions, Stories). Changes:
- Rename the segmented labels to: **Latest · Newsletter · Stories**.
- Each item opens a native reader (title, date, body) when the text is in the feed; the web page otherwise. Back returns to the same scroll position.
- Offline: the saved feed, with the amber "Offline · saved 08:10" pill at the top. Never an empty list when a saved copy exists.
- The graph is no longer reached from News (it lives in EXP-G).

## 6. Ask (owner: collab)

**ASK-1:** AskView as it is, with suggested first questions as tappable chips: "What's on now?", "What's next in my program?", "Which talks clash in my program?", "What's new today?".
- **Without a key** the screen must still explain itself in one card: "Ask uses your own OpenRouter key", what it costs, "Add key". No team context, ever.
- **Review risk (for review and the conductor):** a tab that needs a paid third-party key may be read as incomplete (2.1). If review decides it is a risk, Ask leaves the tab bar and becomes a row in SET-1 ("Ask, with your own AI key"); the tab bar then has four tabs. ux accepts either; review decides.

## 7. Empty, loading and offline states (all owners)

| Situation | What the person sees |
| --- | --- |
| First launch, no network | The core pack built into the app: full agenda, latest saved news. Pill: "Offline · from the app". Nothing blank. |
| Network back | Refresh behind the content; the pill changes to "Updated just now". No reload flash. |
| A list is empty because of a filter | `ContentUnavailableView` with the reason and one way out ("Show all days"). |
| A detail was never loaded and we are offline | The fields we have, plus one muted line "Connect to load more". |
| A request fails with saved data | Keep the data, amber pill "Couldn't refresh · saved 08:10". No alert. |
| A request fails with no data | `StateView` with "Try again". |

## 8. Visual direction (PTCore Design, no new tokens)

- **Type:** serif (`Typo.display`, `Typo.title`, `Typo.headline`) for screen titles and session titles; SF for interface text; `Typo.data` (mono) for times and places. Dynamic Type everywhere; check XXL on NOW-1.
- **Colour:** paper background, `Palette.card` cards, ink text. **Red** = live and mine (the "Now" dot, filled star, tint). **Amber** = clash, stale, offline. **Green** = only "Updated just now". No blue except links to the web.
- **Spacing:** `Space.l` (16) screen margins and between cards, `Space.m` (12) inside cards, `Space.radius` (14) corners. Max readable width `Space.readable` on iPad.
- **Rows:** time first, in mono, left-aligned in a fixed 64 pt column, so the eye runs down the times.
- **iPad:** NOW-1 in two columns (`Columns`): left For you, On now, Up next; right News, Practical.
- **Dark mode:** the palette already pairs; screenshots in light only.

## 9. Owners and order

| Id | Screen | Builds | Needs from | By |
| --- | --- | --- | --- | --- |
| SHELL | Five tabs, settings gear, iPad sidebar, routes for old ids, default `now` | design | — | 13:30 |
| NOW-1 | Now screen, states A/B/C, practical card | design | team `NowModel` | 15:00 |
| NOW-M | `NowModel` + tests | team | — | 13:30 |
| PICK | Star everywhere, toast, clash toast, snapshot republish | team | — | 14:00 |
| PROG-1 | My program: days, clash groups, free gaps, reminders row, empty state | team (design reviews) | — | 15:00 |
| EXP-1/D/P | Explore: Talks (AgendaView), Speakers, Companies, Places, details | deck | design wires the tab | 15:30 (fallback above) |
| EXP-G | Graph after 3 picks | deck (scoped) or design (fallback card) | — | 15:00 decide |
| NEWS-1 | Labels, native reader, offline pill | design | collab feed | 15:00 |
| ASK-1 | Suggested chips, no-key card | collab | review's decision | 15:00 |
| OFFLINE | Core pack in the app, sync on launch and background | collab (PTSync) | apps wiring | 15:00 |
| I18N | Every string above in en, pt-PT, pt-BR; dates and times in Lisbon time with the locale's format | i18n | final copy from this page | 15:45 |

**Cut first if late (in this order):** EXP-P details (lists open the web page instead), scoped graph (full graph fallback), native news reader (web page), NOW-1 iPad two columns (one column), free gaps in PROG-1.

## 10. Screenshot review

For every screenshot set from `screens.yml`, ux checks each screen id above against this page and sends fixes to the conductor as: `<screen id> · what · why`. Screenshots needed: NOW-1 (state A with picks, and state B with a fixed date if the Screens run can set `-PTNow 2026-11-10T14:05`), PROG-1 with a clash, EXP-1 Talks, EXP-D, NEWS-1, ASK-1 with chips. Ask release for a `-PTNow` launch argument (DEBUG only, like `-PTDestination`) so state B can be photographed today.

## Log

- 11:55 UTC: spec v1 written from the briefs, the public app's code on `dev` (66089cd) and the live API (agenda 201 items, people 275, companies 120, places 83, `feed.xml`).
