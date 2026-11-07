# 03 · Team first: features for us

> Each of the nine team members gets one app that opens on their own command centre, knows their schedule, reminds them before every session and stand-up, captures notes and contacts in two taps, and keeps it all in their own encrypted vault. It is the attendee app, with the team switched on.

## Why the team first

- **Nine real users with real deadlines this week.** The team runs two stand-ups a day, three pulse check-ins, reports every two hours, around 109 agents and the summit floor from 9 to 12 November. If the app helps there, we will know within days.
- **The web pieces exist already.** Each person has a command centre (`/people/<id>/app/`), a briefing for every stand-up, a `/meet/<person>/` page behind the QR codes on shirts, and a key that opens content sealed to them. The app wires these to the device.
- **Everything built for the team is attendee-ready.** Swap "command centre" for "my day" and "team key" for "reader vault", and the same code serves readers. Team features are attendee features with a team flag.

## What every team member gets

### 1. Read

| Feature | Native or web | Notes |
| --- | --- | --- |
| Home tab is my command centre | Web in the app | The app opens `/people/<me>/app/` when a team identity is set. Event mode is already built for phones and iPads. |
| Unread badge on the app icon | Native | From `/me.json`: `only_you + decide + overdue`. Refreshed in the background (`BGAppRefreshTask`) and when the app opens. |
| News, the wires and briefs offline | Both | The native reader adds the newsroom wires (`/newsroom/wire.json`) and my briefs next to the PrompTugal feed. |
| Morning and evening edition | Native alert, web content | A notification when `/api/v1/newsletter.json` has a new edition. |

### 2. Schedule

| Feature | Native or web | Notes |
| --- | --- | --- |
| One schedule | Both, web model | Picks from the website (`nr.schedule.v1`) and the app’s Saved tab become one list, mirrored to my vault at `agenda/picks`. |
| Team stand-ups and my meetings in the same list | Native, from web data | Stand-ups from `/meetings/` and my items from `data.json` show alongside sessions, all in Lisbon time. |
| Reminders | Native | Before each pick and each stand-up (default 10 minutes, set per person), with the venue and a link to my briefing. |
| "Now and next" on the Lock Screen | Native | A widget for the next two items. A Live Activity runs from 10 minutes before an item until it ends. |
| Add to Calendar | Native | Write picks to the iOS calendar with EventKit, only when the person asks. |
| Where is everyone | Web, later native | Teammates’ public picks from their vaults, read with read keys they share. This is opt-in, per person. |

### 3. Plan my own view

| Feature | Native or web | Notes |
| --- | --- | --- |
| Starred companies, people and topics | Both | Star on any entity page. Stars go to the vault (`apps/stars/`) and come back as a native "My watchlist" and as Spotlight results. |
| Day plan with gaps | Native | Shows free slots between picks with the walking time between venues (from the 83 places in `/api/v1/place.json`). |
| Briefing pack before a meeting | Web, opened natively | Tapping a meeting opens that person or company page plus my notes from the vault. |
| Siri and Shortcuts | Native | "What is next?", "Save this session", "Open my briefing" as App Intents, which also work from the Action button and Control Center (iOS 18). |

### 4. Input: what I capture

| Feature | Native or web | Notes |
| --- | --- | --- |
| Contact capture | Native | Scan a badge, card or shirt QR (VisionKit), or tap an NFC tag on a shirt (iPhone only). Saves a contact card plus where and when to `apps/contacts/` in my vault. |
| Voice note | Native | Hold to record, transcribed on the device (Speech framework), tagged with the current session. Saved to the vault, and optionally sent to the newsroom lane as a tip. |
| Photo of a slide or stand | Native | Camera plus text recognition (Vision), attached to the session. |
| Share into PrompTugal | Native | A share extension that sends any link, text or photo from another app to my vault inbox. |
| Quick pulse | Native | Answer the three-times-a-day pulse check-in from the notification, without opening the site. |

### 5. Manage

| Feature | Native or web | Notes |
| --- | --- | --- |
| Decisions waiting on me | Web, native alert | The decide and delegate buttons stay on the web (they sign with my key). The app alerts me when `/me.json` shows a new `decide` item. |
| Signing with my key | Native key, web action | My `ws-keyring` key moves into the Keychain behind Face ID. The page asks the app to sign through the bridge, so the key never sits in page storage. |
| Device check | Native | "Is my vault synced, are my keys here, is the app current?" One screen, readable by the project manager’s dashboard if the person opts in. |

## By role

The nine roles need different defaults, not different apps.

| Role | Opens on | Turned on by default |
| --- | --- | --- |
| Lead and decision maker | Decisions waiting | decide alerts, stand-up briefings, investor meetings in the schedule |
| Project manager | Everyone’s schedule | team "where is everyone" view, overdue alerts, device-check overview |
| Editors and reporters | Newsroom desks and stories | voice and photo notes to the newsroom lane, session capture, wire alerts |
| Sales and partnerships | My meetings | contact capture, company watchlist, briefing packs before meetings |
| Builders | Board and wakes | report alerts, release status (`version.json` on each site) |

## What we would learn

By the end of the summit we should be able to answer three questions with numbers. Did the team use the app or the browser for their schedule? How many contacts and notes were captured in the app? Did reminders reduce missed stand-ups? Each answer decides whether the matching attendee feature is worth building.
