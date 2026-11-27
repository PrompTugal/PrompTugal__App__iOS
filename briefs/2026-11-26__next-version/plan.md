# Next version: the conductor's brief against the app (c.ios, 26 Nov 2026)

> cl-6.conductor's brief (copied beside this file, from PrompTugal__Agent__Conductor `board/briefs/2026-11-26-ios-app.md`) checked against the app at c7 (dev c8110b0, TestFlight 0.4.127) and the live API at 02:45 UTC.

| # | Brief item | In the app at c7 | Next |
| --- | --- | --- | --- |
| 1 | "Today": lead and top stories, signature and sources inline | Home tab: lead and top stories, local-first, each opens the source page | **Article reader** (c.ios.places): summary, every source from `api/v1/articles/<id>.json` inline, the signature checked on the device (`<page>.md.sig`: base64 signature, key fingerprint, form `twin-without-version-or-builder/2`), "How this was made" from `api/v1/articles/provenance.json` |
| 2 | My places, latest news and live data | My towns (follow), town pages with news, events, council notices | Each followed town's newest items on Home; live data per town once data.promptugal.news collects again (stopped 21 Nov) |
| 3 | Freshness on every card | Done: live only when read under 3 h ago, else "snapshot, read <date>" | Keep |
| 4 | Offline reading of the last edition | Saved copies per feed | **Offline edition** (c.ios.local): fetch the edition from `api/v1/manifest.json` (3,222 files, sha256 each), verify hashes, "Saved for offline, read <date>" |
| 5 | Notifications, opt-in only | None (reminders removed with the summit) | Waits for Dinis: local notifications only, for a followed place or an IPMA warning (linked, not copied) |
| 6 | Languages from `i18n` | English only (AppCulture forces English) | Spec first (c.ios.explore): what `i18n` covers, then follow the device language. A PTCore change, so in a PTCore batch |
| 7 | "How this was made" | Newsroom board (agents, flow per town) | Per article, in the reader (item 1) |

Must-nots, kept: no reader data leaves the phone (votes only through the anonymous drain, and votes are hidden in the store build); licences checked per source; nothing claimed for RiskMandate beyond riskmandate.ai.
