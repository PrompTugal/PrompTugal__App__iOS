# Team messaging v1: what Indi's team built (branch night/team-messaging)

> From prompter@web-summit.indi, for Indi's team, to conductor.B@ios.PrompTugal.dinis. 9 November 2026. Your brief: [README.md](README.md). Nothing is on `dev` until you review it and CI is green.

## Where it is

- **Branch `night/team-messaging`** (CI builds night branches; `dev` is untouched).
- **The core, in `Packages/PTLanes/Sources/PTLanes/Messages/`** (formats, envelope crypto, device keys, the key directory, the store and transports), with tests in `Packages/PTLanes/Tests/PTLanesTests/MessagesTests.swift`.
  - **Why PTLanes and not a new `PTMessages` package yet:** messaging reuses PTLanes's internal `LaneCrypto` (sgit hybrid v2, for agents) and `LaneClient` (the append lanes) without making them public, and the Team app already links PTLanes, so `project.pbxproj` and `apps.json` do not change. If you prefer `PTMessages`, say so and we move the folder in one commit (PTMessages depending on PTLanes, with those two types made public).
- **The screens, in `Apps/Team/Sources/Messages/MessagesView.swift`**, registered as the `messages` destination in the Team section (under More on iPhone). The redesign (Messages as a tab) comes on its own branch.

## What it does (v1)

- Chat and email, text only, between people and agents; groups from `data/messaging/groups.json`.
- **The envelope `ws-msg-env-1`**, byte for byte as the team site's reference (`admin/tools/messages.mjs`, spec `people/indi/messaging/FORMATS.md`): one content key per message, sealed per reader (ws-ecies-1 to P-256 people and devices; sgit hybrid v2 to agents' RSA keys), signed by the sender's P-256 key over the content and the reader list.
- **Opening refuses** a bad signature, a signer on no published list, a reader it was not sealed to, a `from` that is not the signer, or an id or thread that differs inside and out. A refused message is counted ("1 message could not be verified"), never shown.
- **Device keys:** two P-256 keys in the Secure Enclave (software keys on the simulator), only the enclave handle in the Keychain, this device only. "This iPhone's key" shows the public entry for `data/messaging/device-keys.json`. Signing needs no Face ID (it happens on every message), unlike `VaultDeviceSigner`.
- **Polling:** 10 seconds on the Messages screen, a minute with the app open, 20 minutes otherwise. BGAppRefresh is not wired yet.
- **Transport:** "Messaging is not switched on yet" until the team's messaging vault exists (conductor@web-summit.dinis makes it); then a person pastes the vault's details on "This iPhone's key" and the lanes are used (`LaneMessageTransport`).

## Tests (Swift Testing, in PTLanesTests)

Formats; person to person; person to agent and back (RSA); every refusal; **a known-answer vector made by the Node reference, opened here**; two stores talking through an in-memory post office, with unread counts and reload from disk; "not switched on".

## Not done yet

- Notifications have no Reply button yet (a plain notification per message).
- BGAppRefresh; attachments; mini apps (v2 and v3 of the plan).
- The shared messaging vault and each person's lane (conductor@web-summit.dinis).
