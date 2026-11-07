# 08 · Risks and decisions

> Seven decisions for the team, then the risks we know about. Most decisions only need a yes or no.

## Decisions needed

| # | Decision | Recommended | Why it matters |
| --- | --- | --- | --- |
| D1 | Raise the minimum to **iOS 18**? | Yes | Passkey PRF, broadcast Live Activities, Control Center controls, Spotlight entities. iOS 17 devices can update for free. |
| D2 | Is the website’s `nr.schedule.v1` **the** schedule format for the app too? | Yes | One format means one schedule. The vault path `agenda/picks` already uses it. |
| D3 | Publish the passkey **PRF salt** as a shared constant, and add the app to the passkey domain’s `apple-app-site-association`? | Yes | Without both, the app cannot open the same vault as the website. |
| D4 | Native Swift vault client (option A) over bundled Python? | Yes | Proven feasible, small, and works in widgets and background tasks. |
| D5 | Keep the master key on the device behind Face ID after a passkey unlock? | Yes, wrapped by a Secure Enclave key | One passkey prompt per device, then Face ID. The trade-off is that a cached key is a target. It is hardware-wrapped and biometry-bound. |
| D6 | Hide the reading meter top-up inside the app? | Yes, now | It is the one App Store review risk we already have. |
| D7 | Should team features be **in the public app behind a team identity**, or in a separate build? | Same app | One codebase, and attendees get what the team proves. Team-only content stays sealed to team keys anyway. |

## Risks

| Risk | Likelihood | Effect | What we do |
| --- | --- | --- | --- |
| The sgit format moves faster than the Swift client | high | the app can’t read new vaults | Fixtures from each sgit release in CI. Read the `min_client` field in the branch index and refuse clearly. |
| The PRF salt or passkey domain changes on the web | medium | vaults won’t open in the app | D3, with a test on both sides |
| WebAuthn PRF across devices has gaps (cross-device QR sign-in was reported broken in iOS 18.0–18.4) | medium | some unlocks fail | Recovery code path. Prefer the iCloud Keychain passkey on the same device. |
| App Review rejects the meter, or vault apps under 4.7 | medium | delayed release | D6, and vault apps only in phase 4 |
| Background refresh is rare or late | high | stale widgets | Refresh on every open, show "updated at" everywhere, never promise real time |
| Web storage purged by WebKit | medium | lost picks | The vault is the source of truth. App-Bound Domains. |
| Writes need access tokens readers don’t have | certain, for now | readers can’t sync | Team first. Reader tokens are a platform decision for sgit. |
| A native rewrite of web features | medium | duplicated work, drift | The rule in brief 02: nothing the web already does gets rewritten, except the vault reader |
| The summit is in two days | certain | phase 1 may not ship in time | Phase 1 items are independent. Ship whichever are ready to internal TestFlight. |

## Not confirmed

Things this pack relies on that we could not confirm on 7 November 2026:

- whether third-party apps’ `WKWebView` can run WebAuthn with PRF directly (we avoid relying on it: the native API is confirmed);
- the exact Apple commission on US link-out purchases after the 2026 court rulings;
- how long PBKDF2 with 600,000 rounds takes on each iPhone we support (to measure in phase 2);
- whether `cryptography` builds for iOS without patches (only relevant to option B, which we don’t recommend).
