# Lisbon Fringe: the iOS app

> From conductor.B@ios.PrompTugal.dinis, at Dinis's word (11 November 2026, about 10:45 UTC): "you ... are still conductor.B@ios.PrompTugal.dinis and going to be focus on iOS development, which we now need to pivot into creating a new app for this fringe." Site and team: https://github.com/PrompTugal/PrompTugal__News__Fringe (BRIEF.md, SWARM.md); lead conductor.fringe@PrompTugal.dinis.

## What it is

The phone companion to fringe.promptugal.news: an independent guide to the alternative, community and side events around Web Summit Lisbon this week. Its job is to help someone in Lisbon right now find what's on, where, when and how to join, including what moved because of Storm Charles.

**A fourth app in this repository:**

| | |
|---|---|
| Key | `fringe` |
| Path | `Apps/Fringe/` |
| Scheme | `Fringe` |
| Display name | **Lisbon Fringe** |
| Bundle | `news.promptugal.fringe` |
| Distribution | TestFlight **internal** only until Dinis says otherwise |

## Day one (the first TestFlight build)

| Tab | What |
|---|---|
| **Now** | What is on now and next. The storm block: warnings and what moved, read from https://storm-charles.promptugal.news/api/v1/index.json, with links to IPMA and ANEPC. Not a warning service. |
| **Events** | Today, Thursday 12 and Friday 13. Filters for day, type (unconference, meetup, side event, party, workshop, online) and topic. Each event shows name, organiser, place or link, times, how to join (public link), status (on, moved, cancelled, online, unknown) and the storm note. Each event also shows its source link and the time it was read. |
| **My plan** | Picks, clashes and Add to Calendar, reusing PTAgenda's picks and its busy/free rules. Reminders are local and asked for only after the first pick. |
| **Communities** | Once the site publishes communities.json. |

**More:** About (the independence line and a link to the organisers' official site), Join the team (opens fringe.promptugal.news/join/), and Submit an event (opens /submit/ on the web).

## Data

- **Sources:**
  - https://fringe.promptugal.news/api/v1/events.json and communities.json (the site's dev.fringe@ keeps their fields stable);
  - a seed bundled in the app for first launch and offline use, from the repo's `seed/events-2026-11-11-social-watch.json` until events.json serves.
- **Event fields** (the seed's shape): `name, kind, organiser, date, start, end, place, join, url, status, storm_note, topics[], read_at, verified`.
  - `start` and `end` may be null.
  - Unknown values show as unknown, never as a guess.

## Rules

- **Privacy as the public app:** Data Not Collected. Plain reads of public files without cookies or identifiers. No account, analytics or third-party SDKs.
- **Network:** the only hosts are fringe.promptugal.news and storm-charles.promptugal.news. Links elsewhere open in Safari.
- **People:** no contact details and no private people.
- **Websites:** no automated reading of websummit.com.
- **Independence line:** on About and on the first launch.
- **Reuse, don't fork:** PTCore, PTWeb, PTNowNext and PTAgenda (picks, clashes, calendar). A new package `PTFringe` holds the models and the store.
- **No App Store or Beta submits without Dinis's word.**

## Who

- **apps:** the app, the target, PTFringe and the screens.
- **platform:** apps.json, signing, CI and the TestFlight upload.
- **design:** the look, from pt.news's Front Page (design E).

## Needs Dinis (Apple's side; the API can't do these)

1. **App Store Connect → Apps → New App:**
   - iOS;
   - name **Lisbon Fringe**, or a fallback such as "Lisbon Fringe: Summit Week" if that name is taken;
   - bundle ID `news.promptugal.fringe`. If it isn't in the list, the platform worker registers it first with the API key.
   - SKU: anything.
2. **An internal TestFlight group** (for example "Lisbon Fringe Internal"), or say "use the existing internal testers".
3. **The provisioning profile and its secret:** the platform worker creates the profile with the API key and needs Dinis to add it as the secret `IOS_PROFILE_FRINGE_APP_BASE64`, unless it can be made in CI.
