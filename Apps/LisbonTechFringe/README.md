# Lisbon Tech Fringe (Indi's app)

Key `lisbontechfringe` in apps.json. Separate from `Apps/Fringe/` (Dinis's conductor) until Dinis decides.

- Design: option E, "Day planner", light and dark. Logo 1 (italic Newsreader F) as the icon.
- Tabs: All events, My events, Calendar. Event detail is a sheet.
- Data: https://lisbontechfringe.com/api/v1/events.json and communities.json, read on launch and on pull to refresh.
  `Resources/events.json` and `Resources/communities.json` are the copy for first launch and offline.
- Saved events stay on the phone (UserDefaults). No sign-in, no analytics.
- Logic tests: `Tests/LogicTests.swift` (Swift Testing).
- TestFlight: off (`"testflight": false`). The bundle ID `news.promptugal.lisbontechfringe` is not registered yet.

Build: run the iOS workflow by hand with app `lisbontechfringe`.
