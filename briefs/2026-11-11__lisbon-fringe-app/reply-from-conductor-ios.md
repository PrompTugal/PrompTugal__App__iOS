# Reply: Indi's app to TestFlight

> From conductor@ios.PrompTugal.dinis (account A) to the session working on `work/appdev.indi-lisbon-tech-fringe` (session_01SZXKKC2jZvV547urwQyRzn), at Dinis's word on 11 Nov 2026: "Indi's Lisbon Tech Fringe app replaces Apps/Fringe. Help ship it to TestFlight." Written at about 18:55 UTC.

## Done on Apple's side (Dinis, about 18:45 UTC)

- **The bundle ID `news.promptugal.fringe`** was already registered in the team's account, as "XC news promptugal fringe" (CI's automatic signing did it).
- **The App Store Connect record now exists**, with an internal TestFlight group with automatic distribution. The "no App Store Connect record" skip from run 496 should not happen again.

## What run 498 showed (ios.yml on 8872dbb)

Only the test target failed (`** TEST BUILD FAILED **`). The app built.

- `Apps/Fringe/Tests/LogicTests.swift:12:15: argument 'place' must precede argument 'status'`
- `LogicTests.swift:185, 187, 189, 190: call to main actor-isolated static method 'fingerprint' / 'changes(savedIDs:snapshot:events:)' in a synchronous nonisolated context`

Your 725cd5c and 9057130 address both. Thank you.

## To merge into dev

1. Get one green run of the temporary Fringe check on your head.
2. **Remove `.github/workflows/fringe-check.yml`.** Your own commit says it goes before merging. Then dispatch one full **ios.yml** run (`app=fringe`, `quick=false`) on the branch head and get it green. That is the merge bar.
3. Write the commit and run number here, or in a new line of this file. Either the conductor on account A (this session, when Dinis asks) or conductor.B merges it into dev without rebasing. The first dev push that touches `Apps/Fringe` then builds, signs and uploads to TestFlight, versioned with the repo tag (0.4.n).
4. On `Packages/PTFringe`, now unused: keep it until after the summit. Removing it is a separate change.

Reminder: the app's deployment target is iOS 26, so testers need iOS 26 on their devices.

## Merged (11 Nov, about 19:35 UTC)

`7bbb1ad` was merged into dev without a rebase, after ios.yml run 500 passed the build, the iPhone tests and the iPad tests. The temporary fringe-check.yml was gone before the merge. This dev push builds, signs and uploads Lisbon Tech Fringe to its own App Store Connect record (`news.promptugal.fringe`), versioned with the repo tag. Thank you, Indi and session_01SZXKKC2jZvV547urwQyRzn.
