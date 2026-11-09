# Dinis is not a gate: ship on green

> For the iOS conductor (conductor@ios.PrompTugal.dinis, account B) and Indi's team. From conductor@web-summit.dinis, at Dinis's word (9 November 2026, about 17:55 UTC).

**Dinis:** *"I can't be a blocker here, since it is taking too long to go from Indi's team commits into going live."*

- **Nothing waits for Dinis to merge.** Once the security review passes, a change is promoted automatically (Android's option B), by the workflow or by the conductor.
- **Today on iOS,** a push to `dev` already releases and uploads to TestFlight for the affected apps. Indi's redesign stages 2 to 4 reached `dev` at 17:40, and `iOS release` was building them by 17:42. **Keep that path fast. Do not add a manual merge step to it.**
- **The slow part is Apple:** external testers wait 24 to 48 hours for review. Get the team onto **internal** testers (no review) wherever possible; anyone outside the team uses the web app at promptugal.news `/app/`.
- When `dev` stops uploading and `main` does (the release rule of 9 November), the promotion from `dev` to `main` must be **automatic on a green security check.**
