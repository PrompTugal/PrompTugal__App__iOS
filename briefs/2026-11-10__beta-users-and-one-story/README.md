# Beta users get every major feature set, and the app tells one story

> For the iOS conductor, devops.ios@web-summit.dinis, the workers, and Indi's team (conductor@web-summit.indi, prompter@, dev@ and the rest). From conductor@web-summit.dinis, at Dinis's word (10 November 2026, about 11:50 UTC).

## 1. Every major set of features goes to the external testers

Dinis: "make sure that every major set of features is also pushed to the external reviewers pipelines, so that it is pushed to our beta users."

The public TestFlight link is now being shared, for example on LinkedIn (conductor@web-summit.indi's draft of 10 November). Those testers are in the external group, so they only see builds that have passed Beta App Review. Today every `dev` push reaches the internal group only.

- **What counts as major:** a feature set a tester would notice. Examples: the map and location, Apple Intelligence, a design round, the briefing PDFs, RiskMandate parity. A fix-only push doesn't count.
- **How:** use the tools already in `.github/workflows/testflight-ops.yml`:
  1. `set-whats-new`, written for a beta user, not a developer;
  2. `submit-beta-review`;
  3. `add-to-group` for the external group.

  devops.ios@ owns the automation. It can be a step that runs when a push is marked as a feature release, or a daily cut. Either works, as long as it doesn't add Mac jobs to every push.
- **Plan for 12 to 24 hours.** Dinis reports that approval takes 12 to 24 hours. So:
  - submit as soon as a feature set is ready, not at the end of the day;
  - don't hold the next feature set behind a build still in review;
  - put the build number and submission time in `testflight-ops`'s status output, so everyone can see what beta users have and what is still waiting.
- **Mind the summit's days.** Web Summit runs 9 to 12 November. A feature set submitted after about 12:00 UTC on Wednesday may not reach external testers before the summit ends.
- **Keep it safe.** This doesn't change App Store submission: `ios-submit.yml` stays manual. security.repos@ has an open HIGH on signing from `dev` (its report of 10 November, 10:25Z). Don't widen what `dev` can reach while that is open.

## 2. One story: the website, the docs, the help and the app itself

Dinis: "ask our iOS agentic team to collaborate with Indi's team, since we now have started to share the external link of the app publicly ... we need to make sure that the website, documentation, help files and UX of the app itself (specially the one accepted) is all in sync."

A person who taps the public link should find the same app everywhere. The build they are given, the app's website (`website/` here, and the pages on pt.news), its help files and its documentation should all describe it the same way.

- **The build Apple accepted is the reference.** Describe what is in the approved external build, not what is on `dev`. Mark anything newer as "coming in the next beta".
- **Work together.** The iOS conductor and conductor@web-summit.indi agree on one owner for each surface: the website, the help in the app, the docs, What's New, and the LinkedIn and other public texts. Record the owners in this folder as `owners.md`.
- **A sync check on every external release.** When a build is accepted, check each surface against it: screens, feature names, steps and screenshots. Fix what drifted in the same hour. A short checklist in `website/` or `Tools/` that the build can print is enough.
- **Note the drift.** Each drift you find, and its fix, goes in this folder as `sync-log.md`. It's part of our own case study.

Please answer in this folder (`answer.md`) with the owners, the trigger for external submission, and the first sync check.
