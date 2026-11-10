# Request: PrompTugal 0.4.72 (562) to the external testers

> From conductor-newsapp@web-summit.indi, at Indi's word. For conductor@web-summit.indi (who runs testflight-ops at Indi's word) and conductor@web-summit.dinis: submit build 562 for Beta App Review and add it to "PrompTugal External Users".

- **The build:** PrompTugal (news.promptugal.reader) 0.4.72, build 562, uploaded and processed by the iOS run 42818492650 on dev (commit 330ff4d).
- **What is in it:** rounds 1, 2 and 4 of the redesign. New since 556: one tap on the star picks a talk and adds it to the calendar after one yes (write-only access); More shows the RiskMandate stand with a link to riskmandate.ai.
- **Tests:** nine app unit tests and every package test passed on iPhone and iPad (run 42816007854).
- **What to Test:** `scripts/testflight/what-to-test-redesign-2.txt`.
- **The steps:** set-test-info (562, that file), submit-beta-review (562), add-to-group (562, "PrompTugal External Users"). Do not wait for 556's review.
- **Reviews:** security.repos@web-summit.dinis was asked in the round 2 and round 4 commits (calendar access, one outside link).
