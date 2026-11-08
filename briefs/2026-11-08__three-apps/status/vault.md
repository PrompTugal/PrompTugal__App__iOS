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
- 04:22 UTC: joint run 314 (split/collab 72c152c) failed with errors only in Packages/PTLanes (SecretStore not found, LanesView.body not public, LanesEnvironment.linkedVaults actor isolation). None in PTVaultUI or VaultCollabAccess. Run cancelled at 04:04, so the Package PTVaultUI job never ran: VaultCollabAccess is compiled (Team Debug build got past it) but PTVaultUI's own package tests are still unrun. No fix needed from vault; waiting for collab's next run.
- 04:43 UTC: collab's runs 314 and 320 were cancelled; run 322 (split/collab 0cdbebc) is queued. No PTVaultUI error seen so far. split/vault code is still b614118. Will read 322 when it runs and confirm Package PTVaultUI passes.
- 05:05 UTC: collab's run 322 (split/collab 0cdbebc): Package PTVaultUI passed (Test PTVaultUI, iPhone), promptugal and riskmandate builds and tests passed. Failures are collab's: PTLanes tests (OpenRouter not in scope), Team Debug build (LanesStore.websiteInbox is internal, used in AI/CollabDebugPanel.swift:45), Team unit tests. None in PTVaultUI or VaultCollabAccess. Vault code unchanged: b614118.
- 05:37 UTC: collab's run 324 (split/collab 99c3e91, contains vault b614118) is green. That is the joint run that covers VaultCollabAccess and install(). Run 326 (c6e7a26, status page only) is queued. Nothing more for vault to do; the conductor merges split/collab (vault commits included).
- 05:58 UTC: vault's phase 3 work is on dev (b614118 via collab's c6e7a26, dev 6300658, run 326 green). Standing by. Phase 4 contract for entry points: call `VaultCollabAccess.install()` once at launch and `VaultBackground.register(taskIdentifier: "<this app's id>")` (PrompTugal: news.promptugal.reader.vault-refresh); list the id in BGTaskSchedulerPermittedIdentifiers.

## Research for next-version.md (8 Nov, about 12:00 UTC)

Read-only, no code. The organiser is Web Summit (Lisbon, 9-12 Nov 2026). Confidence is marked on each item: **read** means a fetched page, **search** means a web-search summary I could not open myself.

### 1. Can a participant export their own data from Web Summit's app or site?

| Question | What exists | Confidence |
| --- | --- | --- |
| Connections export | The help article "Exporting your attendee connections" says: open the app (attend.websummit.com/lis26), Discovery tab, "Download Connections". An older media-hub page says Connections tab, Accepted connections, download icon. Format: CSV, emailed to the ticket's email address. A third-party guide says only confirmed connections are included. | search only. The article URL returned 404 to our fetch, so steps and columns are unverified. |
| Contacts as a ticket benefit | websummit.com/llms.txt lists "Downloadable file of contacts" among General attendee benefits, next to "Personalised schedule builder", "Searchable attendee list" and "App messaging function". Format, columns and scope are not stated. | read |
| Meetings | No export of meetings found. The app has a schedule builder and messaging; nothing says meetings can be downloaded. | not found |
| Schedule / calendar | No ICS or calendar feed found. The public schedule is at websummit.com/schedule. Personal schedule help article exists (support-rio.websummit.com) but returned 404. | not found |
| Profile | Nothing found on exporting your own profile. | not found |
| Public API for participants | None found. API Evangelist (a third party, "not affiliated") lists three "APIs" (Attendee Platform, Startup Programme, Developer Programme) captured from the web; it does not say they are public or documented. github.com/websummit has no attendee API. websummit.com/developers is a marketing page for the free developer ticket. developers.websummit.com does not resolve from here. | read |
| GDPR access (privacy policy) | The policy says it is oriented by the GDPR (search snippet; about.websummit.com/privacy, updated 29 Jun 2023, and websummit.com/privacy, updated 27 Oct 2026). Page bodies were not captured, so the request address, form, response time and format are **unverified**. Art. 15 and 20 GDPR give the right regardless; the practical route is the contact or DPO address in the policy. | body not read |
| Terms against reuse | Website terms (about.websummit.com, updated 14 Mar 2022) and websummit.com/terms-and-conditions: bodies not captured. **No clause verified, either way.** | not read |

Pages we could not reach: the connections help article (404 on both hosts we tried), the personal schedule article (404), support.websummit.com help centre (403), the Google Sites app guide (sign-in), developers.websummit.com (DNS), and the body text of the privacy and terms pages.

**What this means for us.** The one real route is the participant's own CSV of connections, downloaded by the participant from Web Summit's app and imported by hand into our app. That is user-initiated, so it is the safe design. We should not log in for the user, scrape, or call Web Summit's internal APIs: the terms are unread and it is the kind of thing they usually forbid. Before building the import: (a) someone with a ticket opens the app at the event and downloads the CSV, so we know the columns; (b) someone reads the terms and the privacy policy in a browser; (c) ask Web Summit's data protection contact whether meetings and the schedule can be exported.

### 2. Domain names (we cannot register anything)

Checked 8 Nov about 12:00 UTC by registry lookup (RDAP) and DNS: "not registered" means the registry had no record and the name had no DNS. Premium pricing and trademark checks are not done. None uses "Web Summit" or another third-party mark.

| Name | Why |
| --- | --- |
| tugasummit.app | "Tuga" is the informal name for Portuguese things; says Lisbon and summit, short, no mark. (.com also free.) |
| summitnow.app | Matches the Now tab: what is on now. Plain English, easy to say. |
| lisbonloop.app | For the feedback site: the feedback loop between users, the website and the builds. |
| summitpal.app | Friendly, personal; fits "who are you?" and the persona idea. summitpal.com is taken (it resolves). |
| ptsummit.app | Shortest, ties to PrompTugal; weakest as a public name. |

Taken or not usable: summitloop.com and summitloop.app (registered), feedloop.app (in use), summitpal.com (resolves), promptugal.com and promptugal.ai (registered, pointing at a parking-style address; **someone must check whether Dinis owns them**). promptugal.org was not registered when checked.
