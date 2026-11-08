# Handoff to conductor.B

> At about 01:40 UTC on 8 Nov, Dinis moved the split to account B. This page is the state at handoff: what is on dev, where each role's branch stands, the merge protocol, and the decisions already taken. conductor.B@ios.PrompTugal.dinis and its sessions continue from here.

**Handed over by:** conductor@ios.PrompTugal.dinis (account A). It stays available in its own session for questions, but it no longer merges or directs sessions for the split.

## Read first

1. [README](README.md): the plan, the phases and why.
2. [contracts](contracts.md), especially §7 "Rulings during the night". It overrides the earlier sections where they differ.
3. Each role's status page in [status/](status/), on that role's `split/<role>` branch, which has the latest copy.

## State of dev at handoff

`dev` is green and shippable, and every push uploads to TestFlight.

| Phase | State |
| --- | --- |
| 1. Workspace and seven empty packages, `apps.json`, `check_apps.py`, `affected.py` | **on dev** |
| 2. PTCore (Design, HTTPClient, Content, Lisbon, BuildInfo, RemoteFeed, Wire…) | **on dev** (platform f1be270, run 278) |
| PTVaultUI (vault) | **on dev** (e5328ff, run 272) |
| Per-app CI (`ios-changes.yml`, matrices from `apps.json`) | **on dev** (release e83a083) |
| Screens on dispatch only | **on dev** |
| TestFlight ops workflow (`testflight-ops.yml`, `scripts/testflight/`) | **on dev**; contact details come from secrets |
| 3. PTWeb, PTAgenda (team), PTNews (design), CollabSeams then VaultCollabAccess then PTLanes then PTAsk (collab and vault) | **in progress**, not on dev |
| 4. Root project → `Apps/Team`; PrompTugal and RiskMandate projects; extensions move to PrompTugal | prepared: projects exist on `split/apps`, plans are in the status pages |
| One version for every app (v0.4.n), quick CI mode, skip upload when there is no App Store Connect record | `split/release`, proof runs in progress |

## Branches at handoff (heads at 01:40 UTC)

| Role | Branch | Head | Next step |
| --- | --- | --- | --- |
| platform | `split/platform` | ce3602e | `AppLinks.scheme` in PTCore: merge once its run is green. Then phase 4 (plan in its status page). |
| team | `split/team` | 6cccf88 | PTWeb and PTAgenda pushed together and not compiled yet. Fix until green, then merge. Switch reminder links to `AppLinks.scheme`. |
| design | `split/design` | 4430e67 | PTNews, which needs team's PTWeb: merge `split/team`. Then PublicShell in `Apps/PrompTugal/Shell/` on top of `split/apps`. |
| collab | `split/collab-seams` | 11acc2e | `CollabSeams.swift` alone. Merge it first. |
| collab | `split/collab` | a32e67a | PTLanes, after vault's VaultCollabAccess. PTAsk goes last, after PTAgenda, PTNews and PTVaultUI. |
| vault | `split/vault` | 01e5e19 | VaultCollabAccess and `install()`, held locally until CollabSeams is on dev. |
| release | `split/release` | 0ed75bc | Quick mode, one version and the record-missing skip. Merge after a quick-mode run and an ios-release dry run are green. |
| editor | `split/editor` | 5d6e8c7 | Site for the public app, Team pages in admin, review texts. Hold it and merge with phase 4. It was waiting on a Bash permission prompt at handoff. |
| testflight | `split/testflight` | 0f58b2c | Watches uploads only (internal testers). No App Store Connect changes without Dinis. |
| apps | `split/apps` | eab1d7a | Projects for PrompTugal and RiskMandate exist. CI runs 285, 289 and 290 were queued. Merge RiskMandate as soon as it is green. |

## Merge protocol (as run so far)

- **Only the conductor pushes to `dev`.** Merge the exact commit a green run tested (`git merge <sha>`), never a later untested head. Never rebase, never force-push, never push to `main`.
- **Before each push to dev,** run `python3 scripts/apps/check_apps.py`, then `python3 website/build.py && python3 website/validate.py && python3 -m unittest website/test_site.py` with `set -o pipefail`.
- **"Green" means a full ios.yml run:** Debug and Release builds, package tests, iPhone and iPad unit tests. Quick mode is for iterating only.
- **CI on branches:** pushes to `split/**` do not trigger CI. Sessions dispatch ios.yml on their branch.
- **Queue load:** cancel superseded queued runs on dev. Screens runs by hand, once after phase 4.
- **Order inside phase 3:** CollabSeams, then VaultCollabAccess, then PTLanes. PTWeb before PTNews. PTAsk last.
- **Phase 4:** platform moves the root project to `Apps/Team` (bundle `news.promptugal.team`, Xcode scheme `Team`, URL scheme `ptteam`). Apps adds the widget and intents targets to the PrompTugal project, after platform moves them. In the same commit, `apps.json` "team" switches to `news.promptugal.team` and "promptugal" gets `testflight: true`.

## Decisions already taken by Dinis

- Three apps in one repo. PrompTugal keeps the existing App Store Connect record (`news.promptugal.reader`). Team gets `news.promptugal.team`. RiskMandate publishes from the same account, bundle `ai.riskmandate.app`.
- One version for every app, equal to the repo release tag, starting at v0.4.0.
- Internal testers only during the summit: no external groups, no Beta App Review.
- Sessions run on Sonnet, the conductor on Opus.

## Waiting on Dinis

- App Store Connect records for Team and RiskMandate: register the bundle IDs, create the apps, add internal groups with automatic distribution.
- The optional `REVIEW_CONTACT_PHONE` secret, needed only for external review after the summit.
- The optional self-hosted Mac runner, with its safety steps (see the conductor session's notes).
