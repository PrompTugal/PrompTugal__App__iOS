# Contracts: three apps

> The fixed interfaces for the split: the package graph, what moves where, apps.json, bundle IDs, CI behaviour and who owns which files. Change this page only through the conductor.

## 1. Package graph

There are no cycles. An arrow means "depends on".

```
PTCore      → (nothing)
SGitVault   → (nothing)
PTWeb       → PTCore
PTAgenda    → PTCore, PTWeb
PTNews      → PTCore, PTWeb
PTVaultUI   → PTCore, SGitVault
PTAsk       → PTCore, PTAgenda, PTNews, PTVaultUI
PTLanes     → PTCore, PTVaultUI
```

Each package is a local Swift package: swift-tools-version 6.0, platform `.iOS(.v18)`, one library product named after the package, and a `Tests/<Name>Tests` target. If a move shows that a package needs something above it, move that piece **down** (usually into PTCore), or inject it with a closure or protocol. Never add an upward edge. If neither works, write it in your status page and the conductor decides.

## 2. What moves where

| From `PrompTugal/` | To | Owner |
| --- | --- | --- |
| `Design/` | PTCore | platform (phase 2) |
| `App/HTTPClient.swift`, the log types, Lisbon time, `Content.swift` shared constants, `BuildInfo` | PTCore | platform (phase 2) |
| `Debug/`: the log stores and the panel building blocks | PTCore | platform (phase 2) |
| `Debug/`: screens that show team or vault data | stay in the Team app | design |
| `Bridge/`, `Shell/WebPage.swift`, `App/Web/` (Websites.json, WebsiteView) | PTWeb | team (WebPage and WebsiteView: design reviews) |
| `Schedule/`, `Notifications/`, `Shared/NowNext.swift` | PTAgenda | team |
| `Store/` | stays in the Team app (Reading credit is hidden in Release; Dinis has not decided) | team |
| `News/`, the graph (`Dashboards/Graph*`) | PTNews | design |
| `AI/` | PTAsk | collab |
| `Lanes/` | PTLanes | collab |
| `Coordination/` | stays in the Team app | collab |
| `Vault/` | PTVaultUI | vault |
| `Team/`, `Dashboards/` (except the graph), `Shell/` (except WebPage) | the Team app (`Apps/Team/`) | design and team |
| `App/` (the remaining parts) | the Team app | platform |

Tests move with their code into the package's `Tests/` when they need no app host. Tests that need the app host stay in the Team app's test target.

## 3. Bundle IDs and records

| App | Bundle | Extensions | App Group | Upload |
| --- | --- | --- | --- | --- |
| PrompTugal | `news.promptugal.reader` (existing record "PrompTugal.news") | `.widgets`, `.intents` | `group.news.promptugal.reader` | yes |
| Team | `news.promptugal.team` (new record, Dinis creates it) | none tonight | `group.news.promptugal.team` if needed | yes, once the record exists |
| RiskMandate | `ai.riskmandate.app` | none | none | no (blocked on the publishing account) |

Each app has its own `MARKETING_VERSION`. PrompTugal continues from 0.3.1, Team starts at 0.1.0 and RiskMandate at 0.0.1. CI sets build numbers per app: run number plus that app's offset, so PrompTugal stays above the manual build 6.

Each app has its own entitlements, Info settings and `PrivacyInfo.xcprivacy`, and asks only for what it uses. The PrompTugal app ships no debug panels in Release, no team screens and no lanes.

## 4. apps.json

```json
{
  "packages": {
    "PTCore": {"path": "Packages/PTCore", "deps": []},
    "SGitVault": {"path": "Packages/SGitVault", "deps": []},
    "PTWeb": {"path": "Packages/PTWeb", "deps": ["PTCore"]}
  },
  "apps": {
    "team": {"project": "Apps/Team/Team.xcodeproj", "scheme": "Team", "bundle": "news.promptugal.team",
             "paths": ["Apps/Team/"], "packages": ["PTLanes", "PTAsk"], "testflight": true},
    "promptugal": {"project": "Apps/PrompTugal/PrompTugal.xcodeproj", "scheme": "PrompTugal", "bundle": "news.promptugal.reader",
                   "paths": ["Apps/PrompTugal/"], "packages": ["PTAsk", "PTAgenda"], "testflight": true},
    "riskmandate": {"project": "Apps/RiskMandate/RiskMandate.xcodeproj", "scheme": "RiskMandate", "bundle": "ai.riskmandate.app",
                    "paths": ["Apps/RiskMandate/"], "packages": ["PTCore"], "testflight": false}
  },
  "all": [".github/workflows/ios.yml", ".github/workflows/ios-release.yml", "apps.json", "scripts/release/", "Config/Shared/"]
}
```

Rules:

- `packages` on an app lists the **direct** packages. Tools compute the closure through `deps`.
- A changed file triggers an app when it is under one of the app's `paths`, or under the `path` of any package in its closure. A changed file under `all` triggers every app.
- **A test (`scripts/apps/check_apps.py`, run in CI on Linux) fails** if:
  - a project's `XCLocalSwiftPackageReference` list differs from its app's closure;
  - a package's `Package.swift` dependencies differ from its `deps`;
  - the graph has a cycle.
- `scripts/apps/affected.py <base> <head>` prints the affected apps as JSON, for the CI matrix.

## 5. CI

- `ios.yml`:
  1. A `changes` job on ubuntu runs `affected.py`.
  2. A matrix over the affected apps builds Debug and Release and runs the unit tests on iPhone and iPad.
  3. A matrix over the affected packages runs `swift test` / `xcodebuild test` for the packages.
- `ios-release.yml`:
  - It uses the same `changes` job.
  - For each affected app with `testflight: true` and a green build, it packages, signs and uploads to that app's record.
  - Each app has its own variable to pause pushes: `TESTFLIGHT_ON_PUSH_<APP>`. The existing `TESTFLIGHT_ON_PUSH=false` still pauses all of them.
  - Tags `team-v*`, `promptugal-v*` and `riskmandate-v*` release one app.
  - Manual runs take an `app` input (`all` or one app).
- `screens.yml` photographs the PrompTugal app and the Team app separately.
- `website.yml` is unchanged: site and docs only.

## 6. Ownership tonight

| Role | Owns | Branch |
| --- | --- | --- |
| platform | the workspace, every `.xcodeproj`, `Config/`, `apps.json`, `scripts/apps/`, PTCore, `Apps/*/App/` (entry points) | `split/platform` |
| team | PTWeb, PTAgenda, `Store/`, `Team/` | `split/team` |
| design | PTNews, `Shell/` and `Dashboards/` in the Team app, the PrompTugal app's screens and Destinations, `Debug/` screens | `split/design` |
| collab | PTAsk, PTLanes, `Coordination/` | `split/collab` |
| vault | PTVaultUI, SGitVault | `split/vault` |
| release | `.github/workflows/ios*.yml`, `.github/workflows/screens.yml`, `scripts/release/` | `split/release` |
| editor | `website/`, `briefs/` (except other sessions' status pages) | `split/editor` |

The conductor merges into `dev` once a branch is green and its phase is due.

## 7. Rulings during the night

These replace the matching rows above.

- **PTCore also gets:**
  - from platform (phase 2): `Event`, `Story`, `FeedClient` (with `site`), `RemoteFeed`, `LoadPhase`, `FeedCache`, and `enum Wire {}` with its loose decoders;
  - from collab: one file, `CollabSeams.swift`, with protocols and value types only (Data, String, URL; no vault types). The conformance, `VaultCollabAccess`, lives in PTVaultUI;
  - from design (phase 4): the shared shell UI parts, in its own subfolder `Sources/PTCore/Shell/`.
- **PTAgenda also gets `News/AgendaView.swift` and `App/ReaderStore.swift`**, moved by team. ReaderStore has the schedule injected; it no longer uses `TeamFeatures.shared`.
- **PTNews:**
  - There is no `Dashboards/Graph*` file; the graph is already in `News/`.
  - PTNews defines a `NewsSource` protocol and `NewsFeeds` (newsletter, board, graph).
  - Each app adds `extension ReaderStore: NewsSource {}`.
  - `DashboardData` forwards to `NewsFeeds`.
- **The bridge works at JSON level.** ScheduleDocument, ScheduleMerge and ScheduleID stay in PTAgenda.
- **Seams between packages** use small protocols and registries, set by each app at launch:
  - in PTWeb: `WebBridgeHub`, `BridgeServices`;
  - in PTAgenda: `AgendaTeamSource`, `AgendaIdentitySource`, `VaultPicksAccess`, `AgendaHub`.

  The public app supplies team sources that return nothing.
- **PTAsk** takes an `AskContextProvider`. `PublicAskProvider`, in PTAsk, offers the agenda, picks, news and the current page. `TeamAskProvider`, in the Team app (`Coordination/`), keeps every current team context and tool.
- **App Intents, widgets and the intents extension** go with the PrompTugal app in phase 4. The Team app has no extensions tonight.
- **URL schemes:** PrompTugal uses `promptugal://`, Team uses `ptteam://`. Reminder links take the scheme from the app.
- **Background refresh:** `VaultBackground.register(taskIdentifier:)` takes each app's BGTask id from its entry point.
- **Keychain after the split:** vault keys saved by today's app (`news.promptugal.reader`) stay with the PrompTugal app. In the Team app (`news.promptugal.team`), teammates import their key again.
