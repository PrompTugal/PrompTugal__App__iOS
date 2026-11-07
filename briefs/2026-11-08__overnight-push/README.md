# Overnight push: the team’s PrompTugal app

> From 02:45 to 10:30 Lisbon time on 8 November, seven sessions build the native PrompTugal app for the team: vaults on the phone, one schedule, agents and team visibility, observability, debug panels, AI and the product site. This page is the shared plan, and every session reads it first.

**Lead:** Dinis Cruz · **Conductor:** the coordinating Claude session · **Wrap-up:** about 10:30 Lisbon time (UTC), with a report on this page

## Positioning, from Dinis

- **This is PrompTugal, and only PrompTugal.** The app and its website are about PrompTugal. Leave RiskMandate, sgit.ai marketing and the other summit sites out of the product, its copy and its default shortcuts. Team data sources stay usable, as data.
- **Native is the point.** Large parts should be native. That is why we are building an app.
- **The team is the first customer.** Seven to nine of us use it at Web Summit Lisbon (9–12 November). Silvio has already installed it from Xcode, so everyone can. The App Store is a bonus, not a dependency.
- **Two products in one:** a **user platform** (readers and attendees) and a **creator platform** (the team, our agents, our newsroom). The platform itself is something we will sell.
- **Make it spectacular on iPad.** The iPad is a better place than the website to see what agents and the team are doing. What we learn natively goes back to the website.
- **Make everything visible.** Like our websites, the app should show its working: debug panels, traffic, encryption, data and versions.

## Decisions taken (answers to brief pack 2026-11-07, D1–D7)

| # | Decision |
| --- | --- |
| D1 | **Minimum iOS 18.** |
| D2 | **`nr.schedule.v1` is the app’s schedule format.** Website and app stay in sync. |
| D3 | **Share the passkey PRF salt** between the website and the app, and add the app to the passkey domain’s associated domains. |
| D4 | **Build the vault reader in Swift.** This is a showcase of consuming a vault locally. Add a debug panel showing traffic, encryption and data. |
| D5 | **Keep the vault key on each device behind Face ID.** |
| D6 | **Keep the meter in the app. Top-ups happen natively** (StoreKit), not through the website’s Stripe link. Start wiring it. |
| D7 | **Team features ship in the same app**, unlocked by having access to a team vault. |

## What to build tonight

1. **Vaults on the phone.** A Swift sgit reader with a cache and sync. Unlock with Face ID, with passkey PRF where possible and read-key import as the always-works path. A **debug panel** showing every request, byte count, file ID, decryption step and timing. Never show keys.
2. **One schedule.** Website picks (`nr.schedule.v1`) and native saved sessions as one list, synced both ways through the web view, mirrored to the vault (`agenda/picks`), with reminders. Plus "help me plan my presence", and coordination with teammates through their vaults.
3. **What my agents and team are doing.** Native iPad dashboards built from the team site’s public JSON (people, `me.json`, command-centre `data.json`, wakes, reports, pulse, meetings, log) and the newsroom’s JSON (`/api/v1/newsroom/*`).
4. **Briefed.** My stand-up briefings, the briefs, decisions waiting on me.
5. **The news, in every form.** The PrompTugal feed, newsletter editions, stories, wires and the graph. Some pages native, some web, side by side, to learn the balance.
6. **Observability and visualizations.** Website traffic and newsroom status, and the visualizations Silvio and Angelo have built, as native iPad views (Swift Charts) next to the web originals.
7. **AI.** OpenRouter chat with the key in the Keychain (and optionally in the vault), using the app’s own data (agenda, my picks, team status) as context.
8. **Collaboration through vaults.** Shared picks and notes, and append lanes for messages to teammates and to the newsroom.
9. **Meter and native top-up.** The website’s meter, kept, topped up through StoreKit, with a local StoreKit configuration for testing.
10. **The product site.** ios.app.promptugal.news becomes a PrompTugal product site for both platforms, with a build log of tonight and many admin pages.

## Sessions

| Role | Branch | Owns (folders) | Status page |
| --- | --- | --- | --- |
| iOS platform | `night/platform` | `PrompTugal.xcodeproj/`, `.github/workflows/ios.yml`, `PrompTugal/App/`, entitlements, Info settings, test targets | [status](status/platform.md) |
| Swift vault | `night/vault` | `Packages/SGitVault/`, `PrompTugal/Vault/` | [status](status/vault.md) |
| Team features | `night/team` | `PrompTugal/Schedule/`, `PrompTugal/Bridge/`, `PrompTugal/Team/`, `PrompTugal/Notifications/`, `PrompTugal/Store/` | [status](status/team.md) |
| Design and native UI | `night/design` | `PrompTugal/Shell/`, `PrompTugal/Design/`, `PrompTugal/Dashboards/`, `PrompTugal/Debug/`, `PrompTugal/News/` | [status](status/design.md) |
| Collaboration and AI | `night/collab` | `PrompTugal/AI/`, `PrompTugal/Lanes/`, `PrompTugal/Coordination/` | [status](status/collab.md) |
| Editor | `night/editor` | `website/`, `briefs/` (except other sessions’ status pages) | [status](status/editor.md) |
| Release engineer | `night/release` | `.github/workflows/ios-release.yml`, `scripts/release/`; writes `release-setup.md` | `status/release.md` |

The conductor merges green branches into `dev` about once an hour. Each merge releases and deploys the site.

## Rules for every session

- **Read [contracts](contracts.md) before writing code.** It fixes the shared interfaces and file ownership.
- **Stay in your folders.** If you need a change in someone else’s folder, write it in your status page under "Needs from others", and the conductor routes it.
- **Small commits, pushed often, to your branch only.** Rebase on `origin/dev` at least every hour. Never push to `dev` or `main`.
- **CI is the compiler.** No one can build Swift on Linux. Push, then read the `iOS` workflow result for your branch and fix it before moving on. A red branch is not merged.
- **No third-party packages.** Apple SDK only, as today.
- **No secrets in git.** No vault keys, read keys, tokens or OpenRouter keys in the repo, test fixtures or logs. Test vaults must be throwaway vaults created for the tests.
- **Update your status page at least every hour:** done, in progress, next, blocked, needs from others. It needs a `# Title` line and a `> summary` line, because the site publishes it.
- **Keep working until about 10:15 Lisbon time.** If you finish your list, take the next item from your backlog. If a turn ends early, schedule yourself a message to continue (`send_later`, 15–20 minutes) instead of stopping.
- **Write plainly.** Short sentences, numbers counted from source, no marketing words.
