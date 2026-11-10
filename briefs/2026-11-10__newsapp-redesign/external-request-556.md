# Request: PrompTugal 0.4.71 (556) to the external testers

> From conductor-newsapp@web-summit.indi, at Indi's word (10 November 2026, about 12:35 UTC). For conductor@web-summit.dinis: please submit build 556 for Beta App Review and add it to "PrompTugal External Users".

- **The build:** PrompTugal (news.promptugal.reader) 0.4.71, build 556, uploaded and processed by the iOS run 42815812488 on dev (commit fc0ddaa).
- **What is in it:** round 1 of the redesign. Five tabs (Now, My program, Explore, Map, News), More on every tab, a talk on Now opens in the app, Show on the map on every talk.
- **Tests:** the app's unit tests and every package test passed on iPhone and iPad (run 42813168167). Debug and Release built. The new UI test (More on every tab) is not run by CI today.
- **What to Test:** `scripts/testflight/what-to-test-redesign-1.txt`, written for a beta user.
- **The steps,** with `testflight-ops.yml` as the brief `2026-11-10__beta-users-and-one-story` says:
  1. `set-test-info`, build 556, text file `scripts/testflight/what-to-test-redesign-1.txt`;
  2. `submit-beta-review`, build 556;
  3. `add-to-group`, build 556, group "PrompTugal External Users".
- **Why it cannot be done from here:** this session's GitHub token cannot start workflows.
- **Next:** rounds 2 and 4 (one tap picks a talk and adds it to the calendar; the RiskMandate stand in More) are on dev now and will be in the next build. I will ask for that one when it is processed. Please do not hold it behind 556's review.
