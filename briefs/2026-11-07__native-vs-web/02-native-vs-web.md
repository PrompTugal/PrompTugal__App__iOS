# 02 · The split: native, web or both

> The websites already have a personal schedule, a passkey-unlocked vault, offline caching and per-person command centres. The app should not rebuild any of them. It should add what a browser cannot do: always-there alerts, the Home and Lock Screen, Keychain-held keys, background sync and capture, through one small bridge.

## What the websites already do

The web is further along than the app. Everything below lives in the browser, with no server-side reader accounts.

| Website | Already does | Where its state lives |
| --- | --- | --- |
| promptugal.news (v0.1.409) | Personal schedule ("Add to my day", `/my-day/`) | `localStorage` `nr.schedule.v1`: `{v:1, picks:[{id, at}]}`, with a `nr:schedule` event on change |
| promptugal.news | Encrypted vault (beta) opened with a passkey: PRF → door vault → master vault → reader vault | `/account/vault.html`, sg-vault 0.2.3 on `dev.send.sgraph.ai`. Picks mirror to the vault path `agenda/picks` |
| promptugal.news | Offline: a service worker precaches the front page, the summit days and the agenda, and readers can save any article | Cache Storage `pt-shell-*`, `pt-pages`, `pt-saved` |
| promptugal.news | Reading profile, reading meter, Ask (the reader’s own OpenRouter key) | `nr.profile.v1`, `web-summit.newsroom.meter.v1`, `nr-chat:key` |
| promptugal.news | An in-page agent API, `window.__tool`, with `schedule.picks`, `agenda`, `now`, `search`, `profile.summary`, `auth.whoami` | page JavaScript |
| promptugal.news | Typed open data: 195 agenda items, 1,179 search rows, a JSON file for every entity, graphs | `/api/v1/…` |
| web-summit.sgit.ai (v0.2.928) | Per-person command centres: tasks, decisions, "Named for me", today’s agenda, event mode, meeting briefings twice a day | `/people/<id>/app/data.json`, `/me.json`, `localStorage` `ws.me` and `cc.*` |
| web-summit.sgit.ai | Per-person keys from a `#key=` link that open content sealed to that person | IndexedDB `ws-keyring`, `data/sealed/<id>/` |
| newsroom.sgit.ai | Live wires read from public encrypted vaults, reader notes back to the newsroom | `sgit.notes.v1`, `/newsroom/wire.json` |

**What none of them can do:** send a notification before a session, show anything on the Lock Screen or Home Screen, keep a key safe behind Face ID, refresh while closed, read NFC, or be sure their storage survives. The app holds the only copy of the sites’ data on the device, and WebKit may delete script-written storage after 7 days without use unless the app sets App-Bound Domains.

## The rule

Ask four questions, in order. The first "yes" decides.

1. **Does it need the device?** That covers Face ID, Keychain, notifications, widgets, Live Activities, Siri and Shortcuts, Spotlight, camera, NFC, background refresh and the share sheet. If yes, it is **native**.
2. **Does it hold a secret or private data that must survive?** If yes, the **key is native** (Keychain) and the **data is in the vault**. The website may show it, but only through the bridge.
3. **Is it content, or a workflow we change every week?** That covers articles, agenda pages, command centres, meeting briefs, the graph and search. If yes, it is **web**, shown in the app’s web view.
4. **Is it something people do while walking between halls?** That covers checking what is next, saving a session, capturing a contact or a note. If yes, build a **native fast path over web data**. The data model stays the website’s, and the app adds a two-tap native surface.

## Every capability, placed

| Capability | Owner | Why | Web piece | Native piece |
| --- | --- | --- | --- | --- |
| Articles, agenda pages, company and person pages | Web | Content changes hourly, and agents publish it | everything | the web view, offline copies |
| Search and Ask | Web | Already built, and uses the reader’s own key | `/search/`, `/ask/` | Spotlight entries for saved items (iOS 18 `IndexedEntity`) |
| Personal schedule | Both, web model | `nr.schedule.v1` is the format | "Add to my day", `/my-day/` | Saved tab reads and writes the same picks, plus alerts, widget and Live Activity |
| Session reminders | Native | The web has no notifications | none | local notifications (at most 64 pending, so schedule the next 64) |
| "What is next" at a glance | Native | Lock Screen and Home Screen | none | WidgetKit widget, Live Activity during a session |
| Calendar export | Native first | No ICS feed on the web yet | later, an `.ics` per pick | EventKit write with the user’s consent |
| Vault unlock | Native | Face ID and Keychain beat a browser tab | the same door, master and reader vault layout | passkey PRF (iOS 18) or a Keychain key behind Face ID |
| Vault data (picks, notes, profile) | Vault | Survives devices and browsers | `window.__vault` | a native vault reader and writer in Swift ([brief 04](04-vaults-on-ios.md)) |
| Team command centre | Web | Changes daily, built from the board | `/people/<id>/app/` | open it as the team member’s home tab, badge from `/me.json` |
| Meeting briefings | Web | Generated twice a day | `/meetings/<slot>/<person>/` | notification 10 minutes before each stand-up, with a deep link |
| Per-person keys (`ws-keyring`, `pt-keyring`) | Native | A `#key=` link in a chat is fragile | the same key format | import once through a universal link, keep in the Keychain, hand to the page through the bridge |
| Contact capture at the summit | Native | Camera and NFC | `/meet/<person>/` pages | QR scan (VisionKit) and NFC tap on shirts and cards, saved to the vault |
| Voice and photo notes | Native | Microphone, camera, on-device speech | the newsroom notes lane | capture, transcribe on device, append to the person’s lane |
| Offline reading | Both | The service worker covers the web, and the native cache covers the reader | `pt-pages`, `pt-saved` | keep the native reader as the sure path, prefetch picks overnight |
| Reading meter and payments | Web, for now | Uses Stripe Payment Links, and App Store rules apply in the app | `/account/` | see [brief 06](06-monetization.md) before any change |
| Theme and design variants | Web | Pure presentation | `promptugal.theme`, `pt-design` | pass the system appearance through the bridge |

## What this means for the code

- The app needs **one bridge** (`WKScriptMessageHandlerWithReply` in its own `WKContentWorld`) and a short list of messages ([brief 05](05-architecture.md)). The website already has `window.__tool` and `window.__vault`, so the bridge is mostly a native implementation of calls that exist.
- The five sites should get **separate data stores** (`WKWebsiteDataStore(forIdentifier:)`, iOS 17), so a key or schedule on one site cannot be read by another. Each store should be listed in **App-Bound Domains**, so WebKit does not purge it.
- **Nothing the website already does should be rewritten in Swift**, except the vault reader, because unlock and background sync must work with no page open.
