# 07 · Roadmap

> Four phases. Each one ships something the team uses that week, and each one proves one assumption before the next phase depends on it.

Sizes are rough: **S** is a day or two, **M** is up to a week and **L** is more than a week, for one person working with agents.

## Phase 1: the team’s summit week (0.4)

**Proves:** the team will use a native schedule and alerts instead of the browser.

| Item | Size | Depends on |
| --- | --- | --- |
| Bridge with `schedule.get/set/changed`, `identity.get`, `notify.plan` | M | a small change on promptugal.news to call the bridge when `window.ptApp` exists |
| One schedule: website picks plus the native Saved tab, in the `nr.schedule.v1` shape | M | the bridge |
| Local reminders before picks and stand-ups | S | the schedule. Stand-up times from `/meetings/` |
| "Now and next" widget (small and medium) | M | App Group store |
| Team identity: choose who I am, open on my command centre, badge from `/me.json` | S | none |
| One data store per site, App-Bound Domains | S | none |
| Hide the meter top-up in the app | S | a website change |

**Ship:** TestFlight internal to the nine of us, before 9 November if possible.

## Phase 2: my vault on my phone (0.5)

**Proves:** a native vault client is reliable, and passkey unlock works for the team.

| Item | Size | Depends on |
| --- | --- | --- |
| Swift vault reader: index, ref, commit, tree, blob, object cache, incremental pull | M | the probe in `evidence/` as the spec, plus sgit fixtures in CI |
| Passkey PRF unlock with the website’s salt, Face ID after that | M | iOS 18 minimum, `webcredentials` on the passkey domain, the salt published as a constant |
| Picks, stars and notes mirrored to the vault | M | the reader. Writes through the JavaScript library at first |
| Team key import (`#key=` universal link → Keychain) and `key.sign` | S | the bridge |
| Background refresh of feeds, `/me.json` and the vault | S | the reader |

## Phase 3: capture and the Lock Screen (0.6)

**Proves:** the team captures more in the app than anywhere else.

| Item | Size | Depends on |
| --- | --- | --- |
| QR and NFC contact capture to the vault | M | phase 2 |
| Voice notes with on-device transcription. Photo notes with text recognition | M | phase 2 |
| Share extension into the vault inbox | S | phase 2 |
| Live Activity for the current session | M | the schedule |
| App Intents: "What is next", "Save this session", Control Center control | S | the schedule |
| Swift vault writer with Secure Enclave signing, one branch per device | L | the reader, round-trip tests with sgit |

## Phase 4: open it up (1.0)

**Proves:** attendees and other teams will pay.

| Item | Size | Depends on |
| --- | --- | --- |
| External TestFlight, then App Store | M | review-ready privacy page, meter risk resolved |
| Vault apps served from a custom scheme with `window.sg` | L | phase 3, and a review of guideline 4.7 |
| Supporter subscription (StoreKit 2) | M | native extras worth paying for |
| Team packs for another event team | M | phases 1–3 in real use |

## What to measure in each phase

| Phase | Measure | Decision it drives |
| --- | --- | --- |
| 1 | Share of the team’s picks made in the app versus the browser, and missed stand-ups | whether attendees get the native schedule first |
| 2 | Unlock success rate, sync failures per day | whether to drop the JavaScript writer |
| 3 | Notes and contacts captured per person per day | whether capture is the paid feature |
| 4 | Conversion to supporter, team pack enquiries | where to put the next quarter |

Measure only what the app already knows. Send nothing without the website’s existing pause switch and Do Not Track rules.
