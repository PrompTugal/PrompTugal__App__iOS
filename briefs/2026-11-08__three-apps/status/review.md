# Review status

> review.B (App Review and synthetic users) for "PrompTugal: Lisbon Summit". **Submitted at 23:20 UTC: 0.4.24 (205) is in App Review** (automatic release after approval). TestFlight 0.4.23 (204) has been in Beta App Review since 16:11. Replies to likely App Review questions are in [app-review-replies.md](../../2026-11-08__summit-app-store/store/app-review-replies.md); next-version items are in [next-version.md](../../2026-11-08__summit-app-store/next-version.md).

## Done
- 11:30 UTC: App Review checklist ([checklist.md](../../2026-11-08__summit-app-store/store/checklist.md)): 5 blockers, 11 risks, the rest OK. Blockers B1 to B5 sent to the conductor.
- Store listing in English, pt-PT and pt-BR, within Apple's limits. The pt keywords are measured in bytes too, so the accents fit.
- App Privacy answers from the code: one data type (Other User Content, for Ask) or Data Not Collected if Ask is hidden. Age rating answers (4+), category, price and availability.
- Review notes for both paths, with the Ask and Vault paragraphs to pick once B1 and B2 are decided. Go/no-go list.
- Persona walk-through 1 (code on dev, before screenshots): below.

## In progress
- Rulings received at 11:25 UTC (B1 option a, B2 hide Vault, B3 to B5 and R1 as proposed). The pack is updated: final [review-notes.txt](../../2026-11-08__summit-app-store/store/review-notes.txt), the App Privacy label with Ask (Other User Content), `/pt/` URLs, and the Ask lines in the listings marked optional (own key).
- Waiting for the first screenshot set from release and the merges of B3, B5, R1 and Vault hidden.

## 12:16 UTC check
- Only the briefs and B5 (microphone and speech strings) are on dev. Every other fix is on a branch: B3, R1 and F3 on team; B1, B2 and F4 on design; the privacy manifest on apps; N1 on platform. The table is in [checklist.md](../../2026-11-08__summit-app-store/store/checklist.md#where-each-fix-is-12-16-utc).
- Not started: N2 (vault background task) and N3 (Ask's "Save key to my vault").
- testflight holds an older copy of the review notes.
- i18n's catalogs have pt-PT and pt-BR, but the project's `knownRegions` does not list them.
- No screenshot set yet.

## 13:00 UTC check
- Candidates rc2 to rc5 reviewed (go/no-go runs 1 to 5 in [go-no-go.md](../../2026-11-08__summit-app-store/store/go-no-go.md)). The app code is GO from rc4 d8a5020 on.
- Release's screenshot pipeline photographs a Debug build with debug mode on: kind badges, plus Debug, Vault and All websites in the iPad sidebar. Fix: `-debug.enabled NO` plus `debugOnly` on those rows.
- In the ASC plan, the content rights answer must be "uses third-party content".
- No screenshot set yet, so the persona walk-through of images waits. The code walk-through findings F3, F4, F11 and F14 are fixed in rc4 (opens on today, native talk detail, Vault and All websites hidden, no vault copy in Ask). F10 (share on news) and F6 (Graph copy) are not checked yet.

## Screenshot pass 1 (14:05 UTC, screens #34)

| # | Persona | Screen | Problem | Fix | Owner | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| F15 | all | My program (launch) | The notification permission prompt appears without a tap, as soon as My program is built. It covers 60 of 63 store images. | Drop `requestAuthorization()` from `MyProgramView` `.task`; ask on the first pick or from the Reminders toggle | team | stuck (store), confusing (people) |
| F16 | P3 (en-US), P5 | `now` | The time wraps: "11:05 A" / "M". A busy speaker reads the time first. | `lineLimit(1)`, a wider column, or 24-hour Lisbon time | design | confusing |
| F17 | P1, P5 | `now` | Good: "Next in your program" with "in 5 min · Centre Stage" answers "what's next for me" at a glance. "On now at the venue" shows 5 with See all (7). | none | | ok |

## Screenshot pass 2 (14:45 UTC, screens #36, rc7)

| # | Persona | Screen | Finding | Severity |
| --- | --- | --- | --- | --- |
| F18 | P1 Ana (pt-BR) | all | Every label is in Brazilian Portuguese, and the talk content stays in English. She can follow the app. | ok |
| F19 | P5 Maria | `now` | "Next in your program · in 5 min · Centre Stage" is the first card: the glance she needs | ok |
| F20 | P3 Sarah | `team.schedule` | "Clash · choose one" between two 11:25 talks, with Keep this one: she can resolve her double booking | ok |
| F21 | P2 Rui, P3 Sarah | `explore.people` | Speakers A–Z with role and company: they can find investors and founders | ok |
| F22 | P4 João | `news.home` | The lead story reads well, and the share button is there (the earlier F10 is fixed) | ok |
| F23 | P1 Ana | `explore.talk` (Registration) | Opens with "Connect to load this talk's times" when offline | confusing (next version) |
| F24 | P1 Ana (pt-BR) | `team.schedule` | The date chips truncate | polish |

## Next
- Walk the personas through each screenshot set and each new build (Now, Explore, pt strings).
- Fill in [go-no-go.md](../../2026-11-08__summit-app-store/store/go-no-go.md) for the build chosen for each submission, then send "GO <build>" or the open items.

## Personas

| Id | Who | Device and setting | What they want from the app |
| --- | --- | --- | --- |
| P1 Ana | First-time attendee from São Paulo | iPhone in pt-BR; no roaming, so venue Wi-Fi only | Not to get lost: what is on now, where, and in her language |
| P2 Rui | Lisbon startup founder, exhibiting | iPhone in pt-PT; on the stand most of the day | Which investors and companies to meet, and which talks are worth leaving the stand for |
| P3 Sarah | Investor from London | iPad and iPhone, English | A short list of sessions and companies in her sectors, around a full meeting calendar |
| P4 João | Journalist for a Portuguese outlet | iPhone in pt-PT; writes between sessions | The latest news, quotes and who is speaking, and shareable links |
| P5 Maria | Speaker with two talks on day 2 | iPhone, English; no time to open apps | Glanceable "what is next" and a nudge before her own talks, plus any room changes |

Severity: **stuck** (cannot do the task), **confusing** (gets there, but slowly or unsure), **missing** (the app does not offer it), **polish**.

## Walk-through 1: code on dev 66089cd (11:30 UTC)

| # | Persona | Screen id | Problem | Fix | Owner | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | all | `collab.ai` (tab 4) | Ask opens on "Add your OpenRouter key". No participant has one. | Ruled: Ask moves to More, and the reviewer gets a key. For participants it stays a bring-your-own-key extra: the listing says so. | collab, design | stuck (for participants without a key) |
| F14 | all | `collab.ai` → Key and settings | "Save key to my vault" (`AskView.swift:421`) with Vault hidden; the intro says "Ask about the summit, your day and the team" | Hide the vault button in the public app; the intro is fixed on `split/collab` 38c85cc | collab | confusing |
| F2 | P1, P2, P4 | every screen | The app is English only (`knownRegions` en, Base), so Ana and Rui read English and dates in English | i18n's String Catalogs (pt-PT, pt-BR) | i18n | missing |
| F3 | P1, P5 | `reader.agenda` | Opens on "All days": hundreds of rows. "Happening now" is there, but under the day picker, and only when a session is live | During 9–12 Nov, default the day to today in Lisbon; put "Now / Next" first (ux's Now screen) | team, ux | confusing |
| F4 | P1, P3 | `reader.agenda` → session | Tapping a session opens a web page (`WebPage(url: event.url)`). Offline, or on bad Wi-Fi, it fails. The detail she needs is time, room and speakers | A native session detail from the agenda data, with the star and Add to Calendar, and the web page as a link | team (PTAgenda), deck (PTExplore) | stuck when offline |
| F5 | P1 | `reader.agenda` header | Shows "Web Summit Lisbon · 9–12 Nov" (B3). For Ana it is also the only place the dates are shown | "Lisbon · 9–12 Nov" | team | blocker for store |
| F6 | P2, P3 | `news.graph` (More → News) | The only way to find companies and people is "Graph", whose subtitle reads "1,688 nodes, drawn natively": developer copy, and hard to find | Rename the subtitle to "Companies, people and events". Explore (deck) becomes the entry point once merged. | design, deck | confusing |
| F7 | P3 | `reader.agenda` | Search covers only "Sessions or venues": she cannot filter by topic or track | A topic filter if the data has tracks; otherwise the search prompt also mentions topics, if search covers them | team | missing |
| F8 | P5 | `team.schedule` (My day) | Reminders are off until she finds Reminders (My day, at the bottom, or More → Settings) | After the first pick, offer "Remind me 10 minutes before?" once. That is also when the notification permission is asked. | team, ux | confusing |
| F9 | P5 | widget, Siri | "What's next in PrompTugal" and the widget are good for her. Neither is mentioned in the app. | One line on My day's empty state: "Add the widget for what's next" | design | polish |
| F10 | P4 | `news.home` | No share button on a story, so he cannot send a link to his editor | `ShareLink` on each story and on the reader page | design (PTNews) | missing |
| F11 | P1 to P5 | More list | The groups "Web" (PrompTugal.news, All websites) and "Personal" (Vault) mean little to a participant. All websites shows the team site (R1). | Hide `web.all` and Vault in the public build. Keep one "PrompTugal.news website" row under News. | design | confusing |
| F12 | P1 | `team.schedule` empty state | "Add sessions from the agenda here or with “Add to my day” on promptugal.news." Good, but it should offer a button to the Agenda | Add a button "Open the agenda", next to "Help me plan my day" | design | polish |
| F13 | P2 | Agenda / My day | No stand locations or directions: expected, it is the next build. The listing does not promise it. | none today | — | missing (planned) |

**Top items sent to the conductor:** F1 (B1), F4, F3, F5 (B3), F11, F10.
