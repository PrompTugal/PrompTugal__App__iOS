# App Store submission: PrompTugal.news (draft, c.ios, 25 Nov 2026)

> Approved and on sale since 25 Nov: 0.4.24 (205), the Lisbon Summit build of 8 Nov. This is the pack for the next version, built from candidate c2c (Explore without Talks; top-ups, comments, sign-in, talk and votes hidden; no summit, CI or credit screens listed in More). Dinis enters the parts marked **manual** in App Store Connect; the name and subtitle can go through testflight-ops `set-app-info` once the new version exists in App Store Connect.

## Version and build

- **Version:** the c2d build's version (0.4.124 or the next number the release bot gives). It must match the build's CFBundleShortVersionString.
- **Build:** the c2d TestFlight build once it is processed.

## Name and subtitle (30 each)

- Name: **PrompTugal.news** (approved by Dinis, 25 Nov)
- Subtitle: **Local news, every fact sourced** (30). Dinis's line "Local news, town by town, every fact sourced" is 44. Alternatives: "Local news, town by town" (24), "Town by town, sourced" (21).
- Home Screen name stays "PrompTugal" (CFBundleDisplayName): "PrompTugal.news" is cut off under the icon.

## Promotional text (170)

```
Local news for Portugal, town by town: the Algarve's 17 towns and the district capitals. Every story opens its source.
```

## Description (4000)

```
PrompTugal.news is local news for Portugal, town by town. It starts with the Algarve and its 17 towns and now covers the district capitals too.

PLACES
• Portugal, the Algarve and each town: its latest stories, the organisations on its map, and what is happening there now
• Maps of the Algarve in several styles, with each town coloured by how much news it has
• Near me: the closest town and its news (your location stays on your phone)

EVERY FACT SOURCED
• Every story opens its source first. We summarise and link out; we do not replace the reporting
• Every screen says whether it shows live data, the copy saved on your phone, or the copy built into the app
• Works offline with the last copy you saw

THE NEWSROOM, IN THE OPEN
• PrompTugal.news is written by a newsroom of AI agents with people in charge. See which agent covers each town and what it did today (read-only)
• Replays of the newsroom's real activity say so, and anything simulated is labelled "Simulated"

ON YOUR DEVICE
• On iPhones with Apple Intelligence, a short summary of a town or a story, made on the device
• No account, no tracking, no ads

PrompTugal.news: local news from Portugal, every story with its source.
```

## Keywords (100)

```
Portugal,Algarve,local,news,towns,Faro,Lagos,Tavira,Loulé,Portimão,map,sourced,AI,regional,newsroom
```

## What's new

```
PrompTugal.news is now local news, town by town: the Algarve's 17 towns and Portugal's district capitals, maps, and the newsroom of agents behind the stories. Every story opens its source.
```

## App Review notes

```
PrompTugal.news reads public news and place data from promptugal.news and its public data sites. No account or login is needed and there is nothing to purchase in this version.

Location (when in use) is only used on the device to find the nearest town for "Near me"; it is never sent anywhere.

Apple Intelligence summaries run on the device with Apple's Foundation Models where available; on other devices the app says so and shows the source text.

The newsroom board can replay the last 24 hours of the agents' real activity (labelled as a replay); anything simulated carries a "Simulated" badge.
```

## App Privacy (**manual**)

Answer: **Data Not Collected**. In c2d a public user cannot send anything: comments, sign-in, thumbs votes and "Connect to the newsroom" are hidden.

What leaves the device in c2d for a public user: plain GETs of public files from promptugal.news and its data sites, ios.app.promptugal.news and raw.githubusercontent.com. Location, Apple Intelligence and the on-device reading count stay on the device. No analytics, crash reporting, ads or third-party SDKs.

## Age rating (**manual**)

- 4+ as before. New question (due 15 Jan 2027, required now because we submit): location sharing with other users: **No**. Dating: **No**.

## Availability (**manual**)

- Remove China mainland until the security assessment and the AIGC filing are done (due 31 Jan 2027 for existing apps).
- Mac and Vision Pro: unticked, as before. Price: free. Release: manual.

## Screenshots (**manual**, or screens.yml)

The 0.4.24 screenshots show the summit agenda and must be replaced: 6.9", 6.5" and iPad 13". Places home, the Algarve map, a town page, a story with its source, Newsroom. `screens.yml` still shoots the summit destinations (explore.talk, team.schedule, map) and needs its list changed first.

## Open, for Dinis

1. Subtitle choice.
2. Place comments and "Connect to the newsroom" in the App Store build: hide them in this version (recommended: they need a person key and a lane link a reviewer cannot have, and once a public user can send, the privacy answer changes), or keep them.
3. 0.4.24 is the summit app with a known notification-tap crash: leave it on sale until the new version is approved, or remove it from sale now.
