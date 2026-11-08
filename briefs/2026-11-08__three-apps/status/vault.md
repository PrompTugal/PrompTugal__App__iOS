# Vault: PTVaultUI

> (8 Nov, B) VaultCollabAccess checked against collab-seams 11acc2e: matches; waiting for CollabSeams on dev before dispatching CI. Vault/ is moved into PTVaultUI and green in CI (run #272, commit e5328ff). The background task id is now a parameter. Still to do: move VaultCollabAccess once collab's protocol is in PTCore.

**Branch:** `split/vault` (from origin/dev 45284d0) · **Phase:** 3 (move done, green) · **Updated:** 8 Nov, 01:05 UTC

## Done

- Read the three-apps README, contracts, and the overnight rules.
- Mapped what `PrompTugal/Vault/` (9 files, 1526 lines) uses from outside.

## What Vault/ uses from outside

| Candidate | Used by Vault/? |
| --- | --- |
| Design (Theme, Components) | No. It uses system fonts and colours only (`.green`, `.headline` are SwiftUI's). |
| HTTPClient | No. It uses `HTTPVaultTransport` from SGitVault. |
| TeamFeatures | No. The comments mention `ScheduleStore`, nothing in code. |
| Debug panels | No. `VaultTrafficLog` and `VaultTrafficEvent` live in SGitVault. `VaultTrafficPanel` (in Debug/) reads from Vault, not the other way. |
| AppShell, Destinations | No. They call `VaultHomeView` and `VaultSession.shared.log`. |
| Logs, Lisbon time, BuildInfo | No. |

Imports in Vault/: Foundation, SwiftUI, UIKit, CryptoKit, Security, LocalAuthentication, AuthenticationServices, BackgroundTasks, VisionKit, Observation, SGitVault. PTVaultUI therefore needs only SGitVault, and `import PTCore` is not needed unless PTCore ends up holding something I have not found. I will check when I move.

## Edges to break

| Edge | Plan |
| --- | --- |
| **BGTask id** `news.promptugal.reader.vault-refresh` in `VaultConfig.backgroundRefreshTask` | Make it a parameter. `VaultBackground.register(taskIdentifier:)` stores it; `VaultBackground.schedule()` uses the stored id (and does nothing if register was not called). Remove the constant from `VaultConfig`. Each app's entry point passes its own id. Platform adds the id to that app's `BGTaskSchedulerPermittedIdentifiers`. |
| **Keychain service** `news.promptugal.reader.vault` | Stays as it is. Keychain items are per app anyway, so Team does not collide with the public app. Moving the string would lock out existing keys on the public app. |
| **Passkey relying party, PRF salt** | Unchanged. Same site for both apps. |
| **Public API for callers outside the package** | Mark `public`: `VaultSession` (shared, log, reader, keyInventory, trustSigner, chooseMyVault, userMessage, backgroundRefresh, picks calls, importKey, myVaultId), `VaultTrustStore`, `VaultKeychain` members used outside, `VaultError`, `VaultHomeView`, `VaultBackground`, `OpenVault`. I will list the exact members from the callers (Schedule, AI, Lanes, Coordination, Debug, Shell, App) after PTCore lands and use only what they call. |

## Outside code that calls Vault (must keep compiling)

TeamFeatures, AIKeyStore, AskView, CollabDebugPanel, LaneAddress, LanesView, LanesStore, TeamNotes, VaultTrafficPanel, DebugHomeView, SystemPanels, DebugPreviews, CollabVaultGlue, CoordinationStore, CollabHooks, TeamPlansView, PrompTugalApp, TeamBackground, AppShell, Destinations, ScheduleVaultLink, ScheduleVaultSync, ScheduleMerge, MyDayView. These belong to other roles. They get `VaultSession` and friends through `@_exported import` in Exports.swift, so they need no change from me.

## Added by the conductor

- Collab defines `CollabVaultAccess` in PTCore (`CollabSeams.swift`, plain types only). PTVaultUI gets the conformance `VaultCollabAccess`, wrapping `VaultSession`, as `CollabVaultGlue` does today. That means PTVaultUI depends on PTCore after all. Waiting for the exact protocol from the conductor.
- Make `VaultSession` API public for the callers in Schedule/, AI/, Lanes/ and Coordination/.

## Tests

- `PrompTugalTests/VaultAppTests.swift` (uses `@testable import PrompTugal`, covers trust store, Keychain errors, "my vault", user-facing errors) moves to `Packages/PTVaultUI/Tests/PTVaultUITests/` with `@testable import PTVaultUI`. Risk: Keychain tests may need an app host on the simulator. If they fail without a host, they stay in the Team app's test target and I write that here.
- Other tests that mention Vault (AITests, ScheduleTests, CoordinationTests) stay with their owners.

## Done (move)

- 9 files moved with `git mv` to `Packages/PTVaultUI/Sources/PTVaultUI/`; `VaultAppTests` moved to the package tests.
- `public` on `VaultSession` and the members outside code calls, `OpenVault`, `KeyInventoryItem`, `VaultHomeView`, `VaultBackground`.
- `VaultBackground.register(taskIdentifier:)`; `VaultConfig.backgroundRefreshTask` removed. `PrompTugalApp.init` passes `news.promptugal.reader.vault-refresh` (platform's file, one-line change so it compiles).

## In progress

`VaultCollabAccess` stays in `Coordination/CollabVaultGlue.swift` until collab's `CollabVaultAccess` protocol is in PTCore.

## Next

0. (01:05 UTC) Merged to dev as e5328ff. Waiting for collab's `CollabSeams.swift` (PTCore) on dev. Then: `git mv` CollabVaultGlue.swift to PTVaultUI as `VaultCollabAccess` (public, `install()`), dispatch CI, report. The edited file is prepared.

1. Merge origin/dev. `git mv` the 9 files to `Packages/PTVaultUI/Sources/PTVaultUI/`.
2. Add `public`, change the BGTask id to a parameter, set `Package.swift` deps to SGitVault (platform owns the dependency list; I will ask if it is not already right).
3. Move VaultAppTests. Push, read the iOS run, fix.

## Blocked

Phase 1 (empty packages linked) on dev. The conductor says I can start the move then, without waiting for PTCore, since Vault/ needs nothing from it. The conductor will ping me.

## Needs from others

- **Platform:** each app's entry point passes its own task id to `VaultBackground.register(taskIdentifier:)`: `news.promptugal.reader.vault-refresh` for the public app, a `news.promptugal.team...` id for Team. Add both to each app's Info. Today `PrompTugalApp.init` calls `VaultBackground.register()`; the call changes to take the id.
- **Platform:** PTVaultUI's `Package.swift` lists SGitVault and PTCore only if PTCore is really needed. My map says SGitVault alone is enough, but the contracts graph allows both.

## After the split (for the release notes)

- Keychain items are scoped to the app's access group (team ID + bundle ID). The Team app (`news.promptugal.team`) will not see vault keys saved by today's app (`news.promptugal.reader`). Those keys stay with the public app. Teammates re-import their key in the Team app. No keychain-sharing group tonight.
- Call-site change for platform's phase 4 entry points: `VaultBackground.register()` becomes `VaultBackground.register(taskIdentifier: "<this app's id>")`.

## Last CI run

iOS run #272 (workflow_dispatch), split/vault e5328ff: green on all 7 jobs (build, Release build, SGitVault tests, package tests, iPhone and iPad unit tests).

## Handoff

Handed off to the session on account B. Do not dispatch CI from the old session.

- **Head:** see the last commit on `split/vault` (the sha is in the handoff message). Code up to e5328ff is on dev, green in run #272.
- **Waiting on CollabSeams:** the commit "vault: VaultCollabAccess moves into PTVaultUI" is pushed but does **not compile** until collab's `CollabSeams.swift` (the `CollabVaultAccess` protocol and `CollabHooks.HookError`, public, in PTCore) is on dev. It moves `Coordination/CollabVaultGlue.swift` to `Packages/PTVaultUI/Sources/PTVaultUI/VaultCollabAccess.swift`: `public final class VaultCollabAccess: CollabVaultAccess`, `public init(session: VaultSession = .shared)`, every protocol member `public`.
- **install():** `public static func install()` sets `CollabHooks.vault = VaultCollabAccess()`. Each app entry point calls it at launch (platform adds the call). `CollabHooks.vault` defaults to nil in PTCore.
- **Next steps:** when CollabSeams is on dev, merge origin/dev, check the file against the real protocol, dispatch ios.yml on split/vault (pushes to split/** do not trigger it), fix what CI shows, report to the conductor.
- **Background task id:** `VaultBackground.register(taskIdentifier:)`. `PrompTugalApp.init` passes `news.promptugal.reader.vault-refresh`. Each app passes its own id and lists it in `BGTaskSchedulerPermittedIdentifiers`.
- **Keychain note for the Team app (release notes):** Keychain items are scoped to team ID + bundle ID. The Team app (`news.promptugal.team`) will not see vault keys saved by the public app (`news.promptugal.reader`). Teammates re-import their key in the Team app. No keychain-sharing group tonight.

## Account B (8 Nov)

- Checked `VaultCollabAccess` against `CollabSeams.swift` on `split/collab-seams` (11acc2e): all 12 protocol members and `HookError` cases match. Fixed a comment (role is "teammate") and an unused-result warning. No CI dispatched; waiting for the conductor to say CollabSeams is on dev.
- 02:40 UTC: CollabSeams still not on dev (head d519d14). Waiting. Conductor note: when told, merge origin/dev, then dispatch ios.yml with app=all, runner=self-hosted.
- 03:02 UTC: CollabSeams still not on dev (head cd1bcdb). Waiting. Conductor (03:02): the self-hosted runner is going offline, so dispatch ios.yml with app=all, runner=macos-26.
- 03:07 UTC: CollabSeams on dev; merged origin/dev (b614118), protocol file identical to the one checked. Dispatched ios.yml app=all runner=macos-26: run 310. 03:23: still queued.
- 03:37 UTC: run 310 (b614118) failed in the Team app only: Coordination/CollabHooks.swift:53, the Team app's local `CollabVaultAccess` shadows PTCore's. Conductor ruling: joint merge on split/collab; run 314 includes split/vault. Run 310 cancelled by the conductor. I push PTVaultUI fixes only if run 314 shows a PTVaultUI error, and tell collab the sha. Code on split/vault: b614118.
- 04:00 UTC: waiting on collab's joint run 314 (split/collab 72c152c, includes split/vault b614118). Still queued. Nothing to fix on my side until it shows a PTVaultUI error.
