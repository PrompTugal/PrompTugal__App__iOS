# Summit app: to the App Store today

> The public PrompTugal app becomes "PrompTugal: Lisbon Summit", the app for summit participants: what is happening now, your own program, news and talks, offline, in English and Portuguese. Today we submit it to Apple twice: a public TestFlight link and an App Store review. This page is the plan; every session reads it first.

**Lead:** Dinis Cruz · **Conductor:** conductor.B (Opus) · **Starts:** 8 Nov, 11:30 UTC · **Feature freeze:** 16:00 UTC · **Submit:** by 18:00 UTC (Lisbon is on UTC)

## What Dinis decided (8 Nov, 11:20 UTC)

1. **All of the team works on this until it is submitted.** Other work pauses.
2. **App Store name: "PrompTugal: Lisbon Summit".** No "Web Summit" in the name or the icon (Apple guideline 5.2: third-party trademarks). The home-screen name stays "PrompTugal".
3. **Two paths today, in parallel:** a TestFlight public invite link (Beta App Review) and an App Store submission. We share whichever Apple approves first.
4. **Languages:** English, Portuguese (Portugal) and Portuguese (Brazil), as separate variants, in the app's own text. Content stays in the languages the sites publish.
5. **Two new Opus sessions:** a mobile designer and UX lead, and an App Review and synthetic-users lead. Implementers stay on Sonnet.

## The MVP: if this were the only build Apple ever saw

A participant opens the app at the venue, with poor Wi-Fi, and within ten seconds knows what is on now, what is next for them, and what is new.

| Area | What the participant gets | Owner |
| --- | --- | --- |
| **Now** (first tab) | What is happening now and next, across the venue and in "my program"; latest news and practical info (traffic, transport, venue notices) from the live feeds | ux (spec), design (screens), team (data) |
| **My program** | Choose your own program from the agenda: pick talks, see clashes, reminders, the widget and Siri | team (PTAgenda), design |
| **Explore** | Talks, speakers, companies and places, searchable; once the program is personal, the graph of the people and companies behind your picks | deck (PTExplore), design |
| **News** | Live news from JSON and RSS feeds, readable offline | collab (PTSync), design (PTNews) |
| **Ask** | Ask about the summit and your day, no team context | collab |
| **Languages** | English, pt-PT, pt-BR for every screen, dates and times in Lisbon time | i18n |
| **Offline** | Core pack built into the app; sync on launch and in the background; works with no network | collab |

Not in this build (next): stand locations and directions, decks, demographics of participation, more languages.

## Who does what today

| Session | Model | Today |
| --- | --- | --- |
| **ux** (new) | Opus | Owns the participant experience: the app's structure, the Now screen, program flow, visuals and copy. Writes short specs with screen ids for design and team; reviews every screenshot set. |
| **review** (new) | Opus | App Review compliance (2.1, 4.2, 5.1, 5.2), store listing in en/pt-PT/pt-BR (name, subtitle, description, keywords, what's new, review notes), and synthetic users: persona walk-throughs of each build's screenshots and flows; files issues to the owners. |
| **i18n** (new) | Sonnet | String Catalogs for the PrompTugal app and the packages it shows: en, pt-PT, pt-BR; Lisbon time formatting; reads sgraph.ai for the regional-variant approach. |
| design | Sonnet | Builds the screens ux specifies in `Apps/PrompTugal/Shell/` and PTNews. |
| team | Sonnet | PTAgenda: now/next, personal program, clashes, reminders, offline agenda. Team-native screens pause. |
| collab | Sonnet | PTSync into the PrompTugal app (core pack, news, agenda), live JSON/RSS feeds, Ask text. |
| deck | Sonnet | PTDeck merges as is; then PTExplore: talks, speakers, companies, places. |
| apps | Sonnet | The PrompTugal project: names, localizations (pt-PT, pt-BR), Info, privacy, PTSync and PTNowNext wiring, App Store build settings. |
| release | Sonnet | App Store screenshots from `screens.yml` (6.9", 6.5", iPad 13"), the App Store version and metadata through the API (plan first), the submission path. |
| testflight | Sonnet | External group, public link and Beta App Review submission for the first good build (plan first, then on the conductor's go). |
| editor | Sonnet | The app's page on the site: support, privacy policy and marketing URLs the store needs, in en and pt. |
| platform, vault | Sonnet | Support: CI capacity, merges, fixes others ask for. |

## Rules for today

- **One goal.** Anything that does not help the summit build waits.
- **Small merges, often.** Quick runs (`quick=true`) for fix rounds, one full run for READY. Never more than one queued run per branch. Cancel your own red or superseded runs at once.
- **ux decides the experience; review decides what Apple will accept.** If they disagree, the conductor decides.
- **Nothing changes in App Store Connect without a plan first and the conductor's go.** Dinis approved submitting today; each submission still gets a final check.
- The rules of the [three-apps plan](../2026-11-08__three-apps/README.md#rules-for-every-session) and [contracts](../2026-11-08__three-apps/contracts.md) still apply.

## Needs from Dinis

1. **Secret `REVIEW_CONTACT_PHONE`** (Beta App Review and App Review need a phone number).
2. **App Store Connect, by hand:** App Privacy answers, age rating, price (free) and availability, and the app name change if the API cannot set it. review prepares every answer.
3. **Demo access** for review, if any screen needs a sign-in (the public app should not).
