# Next version: ideas from Dinis (8 Nov, 11:40 UTC)

> Captured while the first summit build goes to Apple. None of this is in today's submission unless marked **today**. The aim: show what the next generation of app looks like, built and shipped by agents with fast release loops, while staying simple to start, personal, and private.

## Principles

1. **Simple first, personal fast.** Start with almost nothing to read; ask "who are you?" early and let the app change with the answer.
2. **Lessons-learned UX.** Several design passes, by more than one designer: our ux session, Silvio's designer agent, Claude Design, and a ChatGPT review. Compare, then pick.
3. **Show the superpower.** Many small releases, visible improvement day by day, feedback loops from users and the website straight into builds.
4. **Private by default** (see below). One of the most privacy-aware apps on the store.

## Privacy (**today**, for the public build)

- No tracking, no advertising identifiers, no cookies, no third-party analytics.
- Usage telemetry only, and **a switch to turn it off**; a mode that sends nothing at all.
- Everything else stays on the device or encrypted (vaults).
- Beta testers may be asked to opt in to more, explicitly.

Today's check (review and apps): the public build sends no telemetry and no logs off the device, except what Ask sends to OpenRouter when the user gives their own key. The App Privacy label says the same.

## Modes and personas

- Participant, investor, buyer, technology scout, startup, press (a few, not many).
- Each mode changes what Now, Explore and the graph show first, and which connections the app suggests.
- Chosen in a first-run "who are you?" step, changeable any time.

## The graph: manufactured serendipity

- **Where to go and who to meet.** "You should talk to people from company X", and the reverse: "company X should talk to you".
- Show the whole graph when it helps, but the power is **navigation with meaning**: two, three and four degrees of separation, with why each link exists.
- The user's own graph: picks, people met, companies of interest. The more it holds, the better the suggestions. Stored on the device; later moved with vaults.
- **Data that can be downloaded and refreshed**: the mappings come from published data packs (ontologies, entities, links), not from code, so the website and agents can update them live.

## Live, and back in time

- What is happening now, what happened in the last hour or two, what did I miss.
- A timeline to look back: the graph and the news as they were at a given time.
- Agents in the main sessions feed it (for example one watching social media, one watching the venue); the app shows a visualisation of what those agents are doing (like Angela's real-time agents view).
- Managing the fire hose: filters by mode, by my program, by my graph.

## Variations: language and design

- Many languages, with regional variants (pt-PT, pt-BR, es-ES, es-419, fr-FR …), following sgraph.ai.
- Content that exists only in English must still show, clearly marked, with the interface in the user's language.
- **Many designs**, not only themes: layout, structure and modes can change, as on the website. The app should map the whole website.

## Meetings, links and the summit's own data

- Manage links and meetings from the app, connected to the program and the graph.
- **Research** (now, off the critical path): does the summit's own app or site offer an API, an export or a "download my data" for meetings and contacts that a participant can import? Open data for the participant: "why can't I see my own meetings here?"

## Pay as you use

- The same billing model as the website: start with $5 of credit, spend as you use (Ask, sync, graph queries), visible balance.
- Payments through the App Store only (in-app purchase); not wired in this version. **App Review note:** a credit balance that can be topped up must use in-app purchase (guideline 3.1.1); showing usage against a free starting credit is fine as long as nothing can be bought outside the App Store.

## Where to experiment first

- **Team and RiskMandate apps**, not the public app: OpenRouter chats and complete agent workflows running in the app, new designs, new modes. They do not go through App Review, so we can try freely. What works moves to the public app.

## Website and domain

- Today the public app's site is ios.app.promptugal.news (editor updates it for this app).
- **Recommendation needed:** a short domain for the summit app and its feedback loop. Proposal to come from the conductor after today's submission.

## Who

| Item | Owner |
| --- | --- |
| Design passes (variations, modes, onboarding) | ux (Opus) here; Silvio's designer agent, Claude Design and a ChatGPT review through the other conductors, briefed with this page |
| Synthetic-user studies of each variation | review (Opus) |
| Graph navigation and data packs | collab (PTSync), deck (PTExplore), a new graph session |
| Live timeline and agent visualisation | new session, after today |
| Summit data research, domain proposal | vault session (research only) |
| Billing (credit, usage, no payment) | new session, Team app first |
| OpenRouter workflows | Team and RiskMandate apps |

## UX follow-ups from the rc2 review (ux, 8 Nov, 12:45 UTC)

Not blockers for today's submission; for the next build.

- **NOW-1h Ask card:** `AIKeyStore.shared.hasKey` is not observed, so the three questions appear only after the next minute tick once a key is added. Make the key store observable or read it through the environment.
- **EXP-1 offline message:** "The summit data loads once online, then works offline." is followed by the raw system error. Show only our sentence; log the error.
- **EXP-1 Talks:** `AgendaView` sets its own title "Agenda" inside Explore, and its rows' web fallback is titled "Session" (English in every locale). Let Explore own the title; use the talk's title.
- **EXP-G scoped graph:** the card opens the full graph ("Explore the summit graph"). Next: only the people and companies behind the person's picks, from `api/v1/graph/events/<id>.json`.
- **PROG-1:** a source comment in `MyProgramView.swift` was rewritten by the strings pass (`String(localized: "Add to Calendar"…)` inside a doc comment). Cosmetic; tidy the comment.
- **NOW-1 iPad:** two columns (For you, On now, Up next | News, Practical), cut today.
- **NOW-1e Practical:** move the rows to `api/v1/practical.json` so the newsroom can update them during the summit without a build.
- **Old My day screen:** `MyDayView` (team stand-ups, vault, planner) is no longer reached in the public app; keep it for the Team app only.

## UX follow-ups from the store screenshots (ux, 8 Nov, 16:00 UTC)

- **PROG-1 day picker:** in en-US the segments read "Nov 10, 20…". Use short labels: "Mon 9 · Tue 10 · Wed 11 · Thu 12" (abbreviated weekday and day, Lisbon time).
- **EXP-1 title on iPhone:** still "Agenda" inside Explore (iPad is right); see the rc2 item above.
- **EXP-D talk detail for screenshots:** `explore.talk` falls back to the first item of 10 Nov, the registration notice. Prefer a picked talk, else the first `session`; then put the talk detail back in the store set.
- **EXP-G graph:** the full graph shows site URLs and date nodes as labels, overlapping. Scope it to the picks' neighbourhood and hide URL and date labels before it returns to the store set.
- **Strings in pt-PT/pt-BR:** "Official programme" in the Talks rows and the kind badge ("Registration") in the talk detail are English.
- **NextHoursCard:** same 64 pt time column that wrapped 12-hour times on Now; apply the one-line fix if the card is used again.
- **Screenshot filter:** `-PTHideTerm` checks titles and places, not news descriptions; extend it to descriptions so the News image is clean.

## From App Review and the screenshots (review, 8 Nov)

Found while preparing the first submission. None of these blocks it.

- **Screenshot filter on summaries.** `ScreenshotFilter.stories` checks only the title, so a story summary can show a third-party trademark in a store image. Check the summary too.
- **Seeded talk detail for screenshots.** `explore.talk` opens the first item, which is the Registration row. Open a seeded talk, so the store set can include a talk detail.
- **Talk detail offline.** A talk that is not in the cache shows "Connect to load this talk's times". Fall back to the bundled agenda seed, which already has the time and place.
- **pt-BR date chips** in My program truncate ("9 de nov. d…"). Use a shorter day format, such as "ter 10", or a wider chip.
- **pt-PT wording.** "palestra" is Brazilian usage; "sessão" reads more naturally in European Portuguese.
- **Graph labels** show raw URLs (for example "websummit.com/…"). Use readable names, and keep the graph out of store images until then.
- **The planner.** "Plan my day" (free slots and walking times) is only in the Team app. Bring it to My program, then add it back to the store description.
- **A "send nothing" switch** in Settings, with the line "This app sends nothing about you; Ask sends only what you allow" (see the privacy section above).

## First-run onboarding (ux, for 0.4.25; design builds, i18n translates)

**ONB-1 · one screen, shown once.** Not a carousel: one screen, three rows, one decision. It must take under five seconds to read.

- **When:** the first launch only (`@AppStorage("onboarding.seen")`). Never in UI tests or store screenshots (skip it when `-PTDestination` is set; show it with `-PTOnboarding`). Settings gets a row, "How PrompTugal works", that opens it again.
- **Presentation:** iPhone, a full-screen cover over Now; iPad, a form sheet. Now is already loaded behind it, so closing it lands on real content.
- **Does not ask for anything.** No notification prompt, no account, no mode question here (the notification prompt stays on the first pick, as today; the mode question is MODE-1, next-next version).

**Layout (top to bottom, `Page`, `Space.xl` between blocks):**

1. Kicker `Lisbon · 9–12 Nov` (`Kicker`), title in `Typo.display`.
2. Three rows: SF Symbol in a 44 pt circle (`Palette.paper2` fill, `Palette.red` symbol), then a headline (`Typo.headline`) and one or two lines of body (`Typo.body`, `Palette.muted`).
3. Fine print (`Typo.meta`, muted).
4. Primary button (`.borderedProminent`, full width), secondary button below it (`.plain`).

**Copy (en, final):**

| Slot | Text |
| --- | --- |
| Kicker | Lisbon · 9–12 Nov |
| Title | Your summit, on your phone |
| Row 1 · `star` | **Pick your talks** · Tap the star on any talk, in Explore or on Now. It goes into My program. |
| Row 2 · `calendar.badge.exclamationmark` | **See clashes and free time** · My program puts your talks in order, marks the ones that clash and shows the gaps between them. A reminder comes before each one. |
| Row 3 · `wifi.slash` | **Works offline, stays on your phone** · The agenda and the news are saved here and work with no signal. Your picks stay on this phone: no account, no tracking. |
| Fine print | Ask is optional. It uses your own AI key, and only what you ask is sent. |
| Primary | Choose talks |
| Secondary | Not now |

- **Choose talks** closes the screen and opens Explore on Talks, today (or 10 Nov before the summit). **Not now** closes it on Now. Both set `onboarding.seen`.
- **Accuracy (review):** do not write "nothing leaves your phone". The app downloads the agenda and news (no personal data in those requests), and Ask sends questions when the person uses it. Row 3 and the fine print say exactly that.
- **VoiceOver:** each row is one element ("Pick your talks. Tap the star…"); the symbols are hidden. The title is a header.
- **Dynamic Type:** at the largest sizes the screen scrolls; the buttons stay at the bottom (`safeAreaInset`).

**Notes for i18n (pt-PT, pt-BR):**

- Use the app's existing names for the tabs and features: "O meu programa" (pt-PT) and "Meu programa" (pt-BR) for My program; "Explorar"; "Agora"; the existing translation of "Ask".
- "Talk": pt-PT **sessão**, pt-BR **palestra** (review's note: "palestra" reads Brazilian).
- Address: pt-BR **você**; pt-PT avoids "você": use the imperative or the possessive ("Toque na estrela", "o seu telemóvel"). "Phone": pt-PT **telemóvel**, pt-BR **celular**.
- "Your summit, on your phone": translate the idea, not the words. Keep it under 30 characters; it sits in `Typo.display`.
- Portuguese runs about 20 to 30% longer. Nothing may truncate: rows wrap and the screen scrolls.
- "A reminder comes before each one": do not hard-code a number; the lead time is a setting (5, 10 or 15 min).
- "Lisbon · 9–12 Nov": use the same strings as the Now and Agenda kickers ("Lisboa · 9–12 nov.").
- The fine print names no service. "AI key": pt-PT "chave de IA", pt-BR "chave de IA".

## Modes and personas (ux spec for the next-next version)

**The idea:** one optional answer, "I'm here as…", changes what Now and Explore show first. It never hides the summit: everything stays one tap away. The answer stays on the phone.

**MODE-1 · the picker.** Four choices plus "Just show me everything" (the default, today's app):

| Mode | Symbol | One line under it (en) |
| --- | --- | --- |
| First-timer | `figure.walk` | Where to go, what not to miss, how it works. |
| Investor | `chart.line.uptrend.xyaxis` | Pitches, founders and the companies behind them. |
| Founder | `lightbulb` | Masterclasses, meetups and investors to meet. |
| Press | `mic` | Press conferences, announcements and the main stage. |

- **Where:** a second step after ONB-1 ("What brings you to Lisbon?", with "Skip"), and a row in Settings, "I'm here as", which shows the current mode. Changing it takes effect at once; no restart.
- **Storage:** one value in `UserDefaults` (`mode`), never in the vault sync, never in a request, never in an Ask prompt unless the person types it. The App Privacy label does not change.
- **Rules ship as data, not code:** a small JSON in the app (`modes.json`), later also in the content pack (`api/v1/modes.json`), downloaded by everyone alike, so the download says nothing about the person. The app applies the rules locally.

**What each mode changes (rules use fields the agenda and news already have: `kind`, `place`/track, title words, news `category`/topic):**

| Mode | Now | Explore › Talks | News (Latest) |
| --- | --- | --- | --- |
| First-timer | Practical card moves up, under For you. Up next favours Centre Stage. Before the summit: Registration and Opening Night first. | Default filter chip "Main stages" (Centre Stage, Stage 2). | Topics `the-summit`, `portugal` first. |
| Investor | Up next favours `kind: pitch` (PITCH group rounds) and talks whose speakers come from companies. A card "Pitches today" (count, next start). | Default chip "Pitches"; the Companies segment opens first. | Topics `investor`, `startups`, `portugal-startup` first. |
| Founder | Up next favours masterclasses ("[Hosted by …]", Masterclass N), meetups (Meetup N) and side events. | Default chip "Masterclasses and meetups". | Topics `startups`, `portugal-startup`, `ai` first. |
| Press | Up next favours `kind: announcement` (press conferences, Stage 2) and Centre Stage. A card "Press conferences today". | Default chip "Press conferences"; People opens first. | Topics `announcements`, `interviews`, `policy` first. |

- **Ranking, not removal.** A mode reorders and sets a default chip; "All" is always the first chip, and one tap shows everything. On Now the venue cards keep their counts ("See all (7)") so nothing looks missing.
- **The person's picks always win:** For you and My program ignore the mode.
- **Visible:** Now's kicker line gains the mode ("Lisbon · Tuesday 10 November · 11:00 · Investor"), tappable to change it. No hidden personalisation.
- **Graph (EXP-G):** later, the mode picks the starting node type (companies for investors and founders, people for press, places for first-timers).

**Screens and owners (when it is scheduled):** MODE-1 picker and Settings row (design), `ModeRules` and ranking in `NowModel` and the agenda filter (team), Explore default segment and chips (deck), news ordering (design, PTNews), `modes.json` and its pack entry (collab), strings (i18n), review checks the privacy text.

**Tests:** for each mode, a fixed agenda at 10 Nov 11:00 gives a fixed order in `upNext` and a fixed default chip; "Just show me everything" equals today's output exactly.

**Out of scope:** modes that change the layout or the tab bar, more than four modes, inferring the mode from behaviour, and anything that leaves the device.
