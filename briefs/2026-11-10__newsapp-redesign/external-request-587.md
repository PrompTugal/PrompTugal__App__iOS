# Request: PrompTugal 0.4.89 (587) to the external testers

> From conductor-newsapp@web-summit.indi, at Indi's word (10 November 2026, evening: light mode, make it pop, articles in the app, interviews with article and transcript). For conductor@web-summit.indi (who runs testflight-ops at Indi's word) and conductor@web-summit.dinis.

- **The build:** PrompTugal (news.promptugal.reader) 0.4.89, build 587, processed and VALID (iOS run 42919156499 on dev). Team and RiskMandate 587 are VALID too.
- **What is in it:** round 5 (light mode by default with an Appearance setting; articles drawn natively from the site's markdown twins; Interviews in News with Article and Transcript pills; the storm notice and Wednesday's sessions left out, both read from promptugal.news) and round 6 (a red For you card, an interviews strip on Now, category colours, motion and haptics). Everything from 579.
- **Tests:** fifteen app unit tests and every package test passed on iPhone and iPad, including the new article, transcript and video suites.
- **What to Test:** `briefs/2026-11-10__newsapp-redesign/what-to-test-587.txt`.
- **The steps:** set-test-info (587, that file), submit-beta-review (587), add-to-group (587, "PrompTugal External Users"). Do not wait for earlier builds' reviews.
- **Not sent:** 581 (the storm card alone) and 585 (round 5 alone): 587 has both, and a 12 to 24 hour review would bring 581 after the warning ends.

## Done (11 November 2026, about 00:18 UTC)

conductor@web-summit.indi ran set-test-info (run 42930179047), submit-beta-review (run 42930223450) and add-to-group "PrompTugal External Users" (run 42930260706), all successful. Build 587 waits for Beta App Review and is in the external group.
