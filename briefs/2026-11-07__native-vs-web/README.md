# Brief pack: native vs web, team first

> What the PrompTugal iOS app should do itself and what it should leave to the websites, starting with the team as the first users, and how a phone can open our sgit vaults.

**Pack date:** 7 November 2026 · **App at time of writing:** 0.3.1 (build 4) · **Status:** proposal for the team to decide on

## The question

The app is set to become the offline layer and the personal layer for PrompTugal. That means personal schedules, team inputs, reading, planning and, later, revenue. The websites are fast to change and already do a lot. So the question is where each capability should live: native code in the app, the websites inside the app, or both, with a bridge between them.

The first users are the team. If the app makes the team’s own week at Web Summit Lisbon easier (reading, schedule, notes, inputs, briefs), it will also be right for attendees.

## The answer in five lines

1. **The website is the content and the workflow. The app is the device: private state, offline, unlock, alerts, capture.** If a feature needs the device, put it in the app. If it is content or a workflow that changes weekly, put it on the web.
2. **Every team member gets a personal, encrypted space: their own sgit vault, opened on the phone with the same passkey as on promptugal.news, then Face ID.** We showed that a phone can read a vault with Apple’s own crypto, with no Python and no server changes ([brief 04](04-vaults-on-ios.md)).
3. **Don’t rebuild the web: bridge to it.** promptugal.news already has a personal schedule (`nr.schedule.v1`), a passkey vault and offline caching, and web-summit.sgit.ai has a command centre per person. The app adds what browsers can’t: alerts, widgets, Keychain keys, background sync and capture ([brief 02](02-native-vs-web.md), [brief 05](05-architecture.md)).
4. **Build for the team first, in four phases, each of which proves one thing** ([brief 07](07-roadmap.md)). Phase 1 (bridge, unified schedule, notifications, widgets) fits in the summit week. Vault unlock is phase 2.
5. **Earn money only from what is native and genuinely extra**: a supporter tier, sponsor slots and team or enterprise packs. App Store rules shape all three ([brief 06](06-monetization.md)).

## Briefs in this pack

| # | Brief | Read it if you want to know… |
| --- | --- | --- |
| 01 | [Where the app is today](01-current-state.md) | what 0.3.1 actually does and where it stops |
| 02 | [The split: native, web or both](02-native-vs-web.md) | the rule, and every capability placed |
| 03 | [Team first: features for us](03-team-features.md) | what each team member gets, by job |
| 04 | [Vaults on the phone](04-vaults-on-ios.md) | whether sgit vaults can run on iOS, and how to unlock them |
| 05 | [Architecture](05-architecture.md) | the bridge, the stores, sync and the security model |
| 06 | [Monetization](06-monetization.md) | what we could charge for, and what Apple allows |
| 07 | [Roadmap](07-roadmap.md) | the phases, their size and what each proves |
| 08 | [Risks and decisions](08-decisions.md) | what we need the team to decide |

## How this pack was made

- The app facts come from the source in this repository (`PrompTugal/*.swift`), not from memory.
- The vault facts come from reading the `sgit-ai` 0.27.0 package and from a working probe that decrypted the app’s own vault (`i9mbeqwb`) end to end. The probe is in [evidence/vault_read_probe.py](evidence/vault_read_probe.py).
- The Apple platform facts were checked against Apple’s documentation and App Store Review Guidelines on 7 November 2026. Where something could not be confirmed, the brief says so.
- The website facts come from reading promptugal.news, web-summit.sgit.ai, newsroom.sgit.ai and sgit.ai on 7 November 2026.
