# Lisbon Tech Fringe (key `fringe`)

Indi's app (design option E, "Day planner"). It replaces the first Fringe app here, at Dinis's word via Indi on 11 November 2026.

- Tabs: All events, My events, Calendar. Event detail is a sheet.
- Icon: logo 3, the F on a tile (Fraunces italic F as an outline). Wordmark in Fraunces, bundled under the SIL Open Font License (`Resources/Fonts/`).
- Data: https://lisbontechfringe.com/api/v1/events.json and communities.json, read on launch and on pull to refresh.
  `Resources/events.json` and `Resources/communities.json` are the copy for first launch and offline.
- Saved events stay on the phone (UserDefaults). No sign-in, no analytics, no packages.
- Logic tests: `Tests/LogicTests.swift` (Swift Testing).
- TestFlight: signing is automatic with the API key. Upload needs an App Store Connect record for `news.promptugal.fringe` (see briefs/2026-11-11__lisbon-fringe-app).
