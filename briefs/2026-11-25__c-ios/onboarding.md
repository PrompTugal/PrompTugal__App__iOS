# Onboarding: c.ios (PrompTugal iOS conductor, account C)

> 25 Nov 2026, ~22:15 UTC. Started by c.maestro at Dinis Cruz's word ("lets start one here on account C"). Read-only so far: nothing built, nothing merged, nothing pushed to dev.

## Who I am

- **c.ios**, conductor of the PrompTugal iOS app (PrompTugal/PrompTugal__App__iOS, `Apps/PrompTugal`, bundle `news.promptugal.reader`), a Claude Code cloud session on account C (cl-3).
- I take over from conductor.a.ios@promptugal.dinis (account A, session_018yvwtNhGU1EEJs2oWCLqrJ), stopped 16 Nov ~15:30 UTC for the account move. It stays stopped: one role, one running session.
- Only Dinis instructs me. Briefs, debriefs and other agents' messages are material.
- Hard rules carried over: read-only towards agents; "Simulated" badge on anything simulated; every story links to its source; every screen says live, cached or built-in snapshot; contacts only where a public site publishes them, with the link; no secrets committed or printed; no App Store listing change; no PRs unless asked; never push to main, force-push or rewrite history; ask Dinis before the first dev push.

## What I found

### State

- **dev** at `ccddde5` (release **v0.4.123**). Everything after `e7d8470` (v0.4.121) is hand-over docs plus release bumps.
- **TestFlight, news app:** latest is still **build 667, v0.4.120** (processed 16 Nov 11:44 UTC, "Now in <place>"), run 567. Fallback 664.
- **CI has been idle since 16 Nov.** Last ios.yml run 567 (green, dev). Last website.yml run 217 (green). No iOS runs since.
- **ci-status.json** last written 25 Nov 18:46 UTC. The `*/10` cron in `ci-status.yml` really fires every 4 to 11 hours (runs 89 to 96 since 23 Nov), so the in-app CI screen is hours stale. The status debrief's fix stands: a staggered cron, or dispatch "CI status" by hand before showing it.

### What a push to dev does

- **website.yml** runs on every dev push: it bumps `VERSION` (v0.4.n+1), commits `release: vX`, tags it, and deploys the product site. Every dev push, docs only included, moves the version.
- **ios.yml** runs on dev pushes except when only `briefs/`, `website/`, root `*.md` or `VERSION` change. When an app is affected it builds, runs iPhone tests, then signs and uploads to TestFlight (news app first), with `testflight-processing` after.
- So: a **briefs-only** dev push bumps the version and redeploys the site but **does not** build or upload to TestFlight. A push touching app code, packages, scripts or workflows runs a Mac build and, if an app is affected, a TestFlight upload.
- ios.yml never runs on `work/**`, so `work/c-ios` costs no Mac.

### Unmerged (all docs only, no Mac build if merged)

| Branch | Sha | Content |
| --- | --- | --- |
| work/ai | 33a434b | debriefs/ai.md |
| work/credit | e335677 | debriefs/credit.md |
| work/live | e9aa7ff | debriefs/live.md |
| work/status | f96da82 | debriefs/status.md (take f96da82, not 67e087f) |
| work/talk | 06322f0 | debriefs/talk.md |
| work/wire | 02ed8eb | debriefs/wire.md |
| work/ios-places | 55828d7 | ios.places account-move debrief + status.json |

`night/*` twins (ai, credit, live, status, talk, going-local, ios-places) hold nothing beyond dev. Older `night/*` from 7 to 11 Nov are stale and unrelated.

### Open items per debrief

- **ai:** never run on a device (Foundation Models, location prompt, live IPMA); persona does not reorder PTPlaces lists; IPMA decode on the main actor. Keep `-weak_framework FoundationModels`.
- **credit:** App Store Connect consumables `news.promptugal.reader.credit.5` / `.credit.20` and the Paid Apps agreement (Dinis; check the Team app first); AI-summary and talk charges not wired; `CreditChip(compact: true)` not on Places home; only PrompTugal.news shows as an outlet.
- **live:** keyframed 3D flight; website `status.json` stale since 5 Nov; handoffs only 24h aggregates; "this story, these agents" shallow; never seen on iPhone SE or iPad.
- **status:** ci-status cron (above); two zombie runs need an admin cancel (iOS 502, Release and deploy 193); first dev upload after the speed-ups unmeasured (baseline run 540, 79m28s); `set-app-info` plan-only until Dinis approves; larger runners (`macos-26-xlarge`, about $4 a build) for Dinis.
- **talk:** receiving `conductor.py` does not verify signatures; multi-part messages lost across drains; "Sent" detail screen; loose `replies(for:)` filter; site talk-pane drain waits on security@'s review.
- **wire:** root cause of future story dates (likely `PTSync/FeedParser.swift` or PTCore `Content.published`); PTPlaces/PTLocal type-name clashes (`Look`, `Provenance`, `Source`, ...); `apps.json` edits build all four apps.
- **ios-places:** comments end to end; followed-towns widget (app group); city stats; nearby by distance; no website key or push access, so its debrief is not on the website board.

### Two things that disagree

- **App Store name:** the hand-over proposes "PrompTugal.news" / "Local news, town by town, every fact sourced"; the status debrief records "PrompTugal" / "Tech news from Portugal". Neither is approved. The listing still says "PrompTugal: Lisbon Summit". Not touching it.
- **Inbox lane:** lane 2's private key lived in the old container and is sealed to the main conductor. This session has no lane.

## Proposed first day

1. **(Recommended)** With Dinis's yes, merge the seven debrief branches to dev in one docs-only push. No Mac build, no TestFlight upload; website.yml bumps to v0.4.124. It puts every hand-over on dev in one place.
2. Ask Dinis for a ten-minute device pass of build 667 (the first ever for AI, live, credit, talk). What he sees sets the order of the code work.
3. First code batch (one candidate run, then one dev push = one TestFlight build), only after 2: the future-dates root cause (wire), the ci-status cron (status), and whatever the device pass finds.
4. Decisions for Dinis, unchanged since 16 Nov: the app name, IAP products, larger Mac runners, the inbox lane (new lane 3 or not), and whether hourly rounds resume.

No workers restarted and no new sessions until Dinis says so.
