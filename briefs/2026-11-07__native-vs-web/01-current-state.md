# 01 · Where the app is today

> PrompTugal 0.3.1 is a five-site browser with a native offline reader. It has no identity, no personal sync, no notifications and no way for the website and the native code to talk to each other.

## What 0.3.1 does

The app is 1,164 lines of Swift in 5 files, uses only Apple frameworks and targets iOS and iPadOS 17.

| Area | What it does | Where in the code |
| --- | --- | --- |
| Website shell | Opens 5 websites from `Websites.json` in a sidebar. Each site keeps its own `WKWebView`, page and Back history while the app runs. | `WebsiteView.swift`, `WebsiteShortcuts.swift` |
| Link policy | Same-site HTTPS pages stay in the app. Links to other hosts open in Safari. Only `https`, `http`, `mailto` and `tel` are opened. | `WebsiteBrowser.decidePolicyFor` |
| Web storage | One shared `WKWebsiteDataStore.default()` for all five sites, kept across launches and separate from Safari. | `WebsiteBrowser.init` |
| Configurable sites | Users can edit `Websites.json` in the Files app. A broken file falls back to the bundled defaults with a notice. | `WebsiteDirectory.load` |
| Offline reader | Native Now, Agenda, Saved and News tabs, built from three public feeds on promptugal.news. | `PrompTugalApp.swift`, `Content.swift` |
| Feeds | `api/v1/live/agenda.json`, `api/v1/events/{id}.json` and `feed.xml`, with a 15-second timeout and HTTPS-only story links. | `FeedClient` |
| Native store | `content.json` (cached feeds and details) and `saved.json` (bookmarks) in Application Support. | `ReaderStore` |
| Refresh | Every time the app becomes active, with no background refresh. | `ReaderView.onChange(of: scenePhase)` |
| Time | Every agenda time is shown in Lisbon time, including sessions that end after midnight. | `Lisbon` |

## What it does not do

- **No identity.** It does not know who the user is. It has no sign-in, no passkey and no team role.
- **Two schedules that never meet.** Schedule picks made on promptugal.news live in the website’s local storage inside the web view. Sessions saved in the native reader live in `saved.json`. Neither can see the other.
- **No bridge.** No `WKScriptMessageHandler` and no injected script, so the website cannot ask the app for anything, and the app cannot tell the website anything.
- **No alerts.** No local notifications before a session, no push, no Live Activities.
- **Not on the Home Screen or Lock Screen.** No widgets, no App Intents (Siri, Shortcuts, Spotlight), no Control Center controls.
- **No capture.** No camera, QR or NFC, no voice notes, no share sheet into the app.
- **No private data.** Nothing is encrypted beyond iOS file protection, and nothing syncs between a person’s iPhone and iPad.
- **No background work.** The feeds are fresh only when the app is open.

## What this means

0.3.1 is a good base. The website shell, offline cache, Lisbon-time handling and link policy are careful and small. But every feature the team has asked for (personal schedule, own inputs, planning, private notes, a vault) needs one of the missing pieces: **identity, a bridge, a private store and alerts**. Those four pieces are the foundation in [brief 05](05-architecture.md) and phase 1 of [the roadmap](07-roadmap.md).
