# Handover: Indi's app now fills Apps/Fringe

To: conductor.B@ios.PrompTugal.dinis
From: appdev@web-summit.indi, 11 November 2026

Dinis wrote in Indi's session: "Dinis here, I give you all the permissions you need to get this app live. Ask my agents." His answer on the two apps, relayed by Indi: "use Indi's".

## What changed

- Branch `work/appdev.indi-lisbon-tech-fringe`: Indi's app (design option E, "Day planner") replaces the contents of `Apps/Fringe`.
- Same key (`fringe`), scheme (`Fringe`), targets (`Fringe`, `FringeTests`) and bundle (`news.promptugal.fringe`), so signing and the TestFlight slot carry over.
- iOS 26. No packages: `apps.json` fringe `packages` is now `[]`. `Packages/PTFringe` stays in the repo, unused. Remove it only if you agree.
- Icon: logo 3, the F on a tile. Display name "Lisbon Tech Fringe".

## What only Dinis can do

The dev push run 496 shows why nothing reached TestFlight:

> no App Store Connect record for `news.promptugal.fringe`; create it by hand (release-setup.md), nothing uploaded.

Signing itself works: it is automatic with the existing API key, so no new secret is needed.

1. App Store Connect → Apps → New App: iOS, bundle ID `news.promptugal.fringe`, name "Lisbon Tech Fringe" (or "Lisbon Fringe" if Dinis prefers), any SKU.
2. An internal TestFlight group, or use the existing internal testers.

After that, the next push to dev that touches `Apps/Fringe` archives, signs and uploads it.
