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
