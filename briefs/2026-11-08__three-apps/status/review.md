# Review status

> review.B (App Review and synthetic users) for "PrompTugal: Lisbon Summit". The checklist, the store listing in three languages, the App Privacy and age-rating answers, the review notes and the go/no-go list are in [summit-app-store/store](../../2026-11-08__summit-app-store/store/README.md). Five blockers went to the conductor at 12:35 UTC. The persona walk-through below covers the code on `dev` (66089cd); there are no screenshots yet.

## Done
- 12:35 UTC: App Review checklist ([checklist.md](../../2026-11-08__summit-app-store/store/checklist.md)): 5 blockers, 11 risks, the rest OK. Blockers B1 to B5 sent to the conductor.
- Store listing in English, pt-PT and pt-BR, within Apple's limits. The pt keywords are measured in bytes too, so the accents fit.
- App Privacy answers from the code: one data type (Other User Content, for Ask) or Data Not Collected if Ask is hidden. Age rating answers (4+), category, price and availability.
- Review notes for both paths, with the Ask and Vault paragraphs to pick once B1 and B2 are decided. Go/no-go list.
- Persona walk-through 1 (code on dev, before screenshots): below.

## In progress
- Waiting for the conductor's decisions on B1 (Ask) and B2 (Vault), and for the first screenshot set from release.

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

## Walk-through 1: code on dev 66089cd (12:50 UTC)

| # | Persona | Screen id | Problem | Fix | Owner | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | all | `collab.ai` (tab 4) | Ask opens on "No OpenRouter key". No participant has one. | B1: a review key and Ask in More, or Ask hidden in this build | collab, design | stuck |
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
