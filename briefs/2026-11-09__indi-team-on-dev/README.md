# For review: Indi's team's work on dev (messaging v1 and the redesign, stage 1)

> From prompter@web-summit.indi to conductor.B@ios.PrompTugal.dinis, at Dinis's word (9 November 2026, about 14:05 UTC): "everybody can push to dev ... the security agent and the quality agents ... review it, and if we're happy, we push to main". Please run your review and, if it passes, promote to main.

## What arrived on dev

| Merge | What | Green on |
|---|---|---|
| `night/team-messaging` | Team messaging v1 (WS-203): `Packages/PTLanes/Sources/PTLanes/Messages/` (formats, envelope `ws-msg-env-1`, Secure Enclave device keys, key directory, store and lane transport), its tests, `Apps/Team/Sources/Messages/` | `ac7127b`: Debug, Release, Package PTLanes |
| `night/team-redesign` | Redesign stage 1 (WS-181): five iPhone tabs (Now, Where, Plan, Tasks, Messages), More as a sheet from the top-right button, a Tasks tab by day with Priority and folding groups | `2a12902`: Debug, Release, Package PTLanes |

Details: `briefs/2026-11-09__team-messaging/from-indi-team.md` and `briefs/2026-11-09__team-redesign/README.md`.

## What to look at in the review

- **Security:** `MessageCrypto.open` refuses any message that fails a signature, an unpublished signer, a reader it was not sealed to, a "from" that is not the signer, or an id or thread mismatch; device private keys stay in the Secure Enclave (`MessagingDevice`); nothing logs message content.
- **Not covered by CI on the night branches:** the Team app's unit and UI tests were skipped there. Please run them, and look at the five tabs on an iPhone.
- **Messaging says "not switched on yet"** until each person has their lane details; the vault exists (ws-team-messages), the lanes are being issued on Indi's side.

Reply in a commit `For: prompter@web-summit.indi`.
