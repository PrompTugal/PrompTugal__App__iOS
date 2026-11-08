# Three apps, one repository

> Tonight we split the one iOS app into three apps that share code through local Swift packages: the team's internal app, the public PrompTugal app, and an empty RiskMandate app. CI builds, tests and uploads to TestFlight only the apps a change touches. This page is the plan, and every session reads it first.

**Lead:** Dinis Cruz · **Conductor:** the coordinating session (Opus) · **Sessions:** Sonnet · **Starts:** 8 Nov, about 00:00 Lisbon · **Wrap-up:** about 10:00 Lisbon, with a report on this page

## What Dinis decided (8 Nov)

1. **Three apps:**
   - **Team** (internal): the Web Summit / RiskMandate team app. It is today's app with all its team features.
   - **PrompTugal** (public): 100% the site and the summit tools, for the team and every participant who installs it.
   - **RiskMandate**: explains and demos ABPs and our agentic workflows, with demos and videos. Tonight it is only an empty app with a working build and CI path.
2. **One repository.** Shared code lives in local Swift packages. A change to one app's code builds, tests and uploads only that app.
3. **The public PrompTugal app keeps the existing App Store record**, `news.promptugal.reader`. The Team app gets a new bundle ID, and its testers move to its new TestFlight.
4. **Before Monday 9 Nov:** the Team and PrompTugal apps are split, and PrompTugal is ready for Beta App Review.
5. **After the summit:** RiskMandate content.
6. **Models:** sessions run on Sonnet, the conductor on Opus.

## Why

The App Review findings came from shipping an internal team tool and a public app in one binary. The public app has no team names, no debug panels and no messages between users, so most review risks disappear. The team keeps every tool it has, and never needs App Review.

## Apple review so far

**Beta App Review approved the original PrompTugal app, in about 24 hours.** Build **0.3.1 (4)** of `news.promptugal.reader` ("PrompTugal.news") was submitted for Beta App Review, the review for external TestFlight testing, and Apple approved it about 24 hours later (status `APPROVED`, read by TestFlight ops at 01:19 UTC on 8 Nov). It is in the "PrompTugal External Users" group (0 testers so far, 10 sessions), and expires in 89 days.

- This was the one-binary app, before the split and before the [App Review readiness](../2026-11-08__app-review-readiness/README.md) fixes. The public PrompTugal app after the split is a smaller surface (no team screens, no debug panels, no messages), so its review should be no harder.
- It is a Beta App Review approval, not an App Store review. The App Store review of the public app comes after the summit.
- During the summit, every new build goes to internal testers only; build 4 stays in the external group as it is.

## The shape

```
PrompTugal.xcworkspace          opens all three apps and the packages
Apps/
  Team/Team.xcodeproj           today's project, moved and renamed; bundle news.promptugal.team
  PrompTugal/PrompTugal.xcodeproj   new; bundle news.promptugal.reader (+ widgets, intents)
  RiskMandate/RiskMandate.xcodeproj new and empty; bundle ai.riskmandate.app (no upload yet)
Packages/
  SGitVault/   (exists)  vault format, crypto, transport
  PTCore/      design system, HTTPClient, logs, Lisbon time, build info
  PTWeb/       web views, the bridge, CheckoutPolicy, Websites.json
  PTAgenda/    schedule, picks, planner, reminders, widget snapshot (NowNext)
  PTNews/      feed, news, graph
  PTAsk/       OpenRouter, Ask, consent, tools
  PTLanes/     append lanes, messages, report and block
  PTVaultUI/   vault session, Keychain, unlock, vault screens
apps.json      which packages each app is built from; CI reads it
```

The full rules (package graph, what goes where, `apps.json`, bundle IDs, CI, ownership) are in [contracts](contracts.md).

| App | Packages |
| --- | --- |
| Team | all of them |
| PrompTugal | PTCore, PTWeb, PTAgenda, PTNews, PTAsk, PTVaultUI, SGitVault (no PTLanes, no team dashboards) |
| RiskMandate | PTCore |

## Order of work

| Phase | Who | What | Done when |
| --- | --- | --- | --- |
| 1. Scaffold | platform (alone) | Create the workspace and the seven empty packages with their dependency graph. Link them to today's app target. Add one `Exports.swift` with `@_exported import` for each package, so app files need no new imports. Add `apps.json` and a test that checks it against the projects. | The app builds and tests green with empty packages. **Everyone else waits for this merge.** |
| 2. Core | platform | Move Design, HTTPClient, the logs, Lisbon/Content and BuildInfo into PTCore, and mark them `public`. | Green on dev. PTCore depends on nothing. |
| 3. Packages, in parallel | team: PTWeb, PTAgenda · design: PTNews · collab: PTAsk, PTLanes · vault: PTVaultUI | Move the folders, add `public`, and add `import PTCore` inside each package. Break any cycle by moving the shared piece down into PTCore, or by passing a closure or protocol. | Each package green on dev, with its tests moved into the package's own `Tests/` where they can run there. |
| 4. Split | platform + design | Move today's project and its remaining folders to `Apps/Team/` with the new bundle ID. Create `Apps/PrompTugal/` with bundle `news.promptugal.reader`, the widgets, the intents and its own Destinations list (design). Create the empty `Apps/RiskMandate/`. | All three build in CI. |
| 5. CI per app | release | Add a change-detection job (Linux) that reads `apps.json` and the diff, plus a matrix that builds, tests and uploads only the affected apps. Give each app its own version, build number, tags and TestFlight switch. | A change under `Apps/RiskMandate/` builds only RiskMandate. A change in PTAgenda builds Team and PrompTugal. |
| 6. Site and docs | editor | ios.app.promptugal.news becomes the PrompTugal app's site, and the Team app's pages move to the admin area. Update review notes, privacy and release setup for the public app. | Validator green, and the site matches the code. |

Sessions that are waiting read the code they will move, map its dependencies and write their plan in their status page. They do not move code before the phases above it are on `dev`.

## Decisions still for Dinis

1. **The Team app's name and bundle ID.** The working choice is `news.promptugal.team`, display name "PT Team". Tell us if it should be a RiskMandate name instead.
2. **A new App Store Connect record for the Team app,** created by hand (the API cannot create apps), plus moving the internal testers to it.
3. **Which Apple account publishes the RiskMandate app.** Until then it builds in CI but never uploads.
4. **TestFlight on push during the night.** Once the signing secrets exist, every merge to dev uploads. The release session gates uploads per app from `apps.json`, so nothing uploads to the wrong record.

## Rules for every session

The rules of the [overnight push](../2026-11-08__overnight-push/README.md#rules-for-every-session) apply:
- Work on your own branch, `split/<role>`.
- Bring it up to date by merging `origin/dev`. Never rebase and never force-push.
- CI is the compiler. A red branch is not merged.
- Apple SDK only.
- No secrets in git.
- Write plainly.

Also:

- **Phases are strict.** Wait for the phase above you to be on `dev`.
- **Move, don't rewrite.** Use `git mv`, so history follows the files. Change only what the move needs: `public`, `import`, `init`s for public structs. Behaviour stays the same, and every existing test still passes.
- **Never edit another app's project file.** Only platform edits `.xcodeproj` files until phase 4 is done.
- **Status page:** `briefs/2026-11-08__three-apps/status/<role>.md`, with a `# Title` line and a `> summary` line, updated at least every hour.
