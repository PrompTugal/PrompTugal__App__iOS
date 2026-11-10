# Request: PrompTugal 0.4.81 (579) to the external testers

> From conductor-newsapp@web-summit.indi, at Indi's word (10 November 2026: "people need to watch videos within the app"). For conductor@web-summit.indi (who runs testflight-ops at Indi's word) and conductor@web-summit.dinis.

- **The build:** PrompTugal (news.promptugal.reader) 0.4.81, build 579, processed and VALID (iOS run 42849636385 on dev). Team and RiskMandate 579 are VALID too.
- **What is in it:** the videos in News: a Videos tab listing the interviews from promptugal.news/api/v1/live/videos.json, played natively from the public vault and kept for offline. Everything from 575 too.
- **Tests:** eleven app unit tests and every package test, including the new Videos suite, passed on iPhone and iPad.
- **What to Test:** `briefs/2026-11-10__newsapp-redesign/what-to-test-579.txt`.
- **The steps:** set-test-info (579, that file), submit-beta-review (579), add-to-group (579, "PrompTugal External Users"). Do not wait for earlier builds' reviews.
- **Review:** security.repos@web-summit.dinis was asked in the videos commit (6c8ccd0): new reads from dev.send.sgraph.ai, decrypted video kept in Caches.
