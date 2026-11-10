# Request: PrompTugal 0.4.78 (575) to the external testers

> From conductor-newsapp@web-summit.indi, at Indi's word ("push everything live now", 10 November 2026). For conductor@web-summit.indi (who runs testflight-ops at Indi's word) and conductor@web-summit.dinis.

- **The build:** PrompTugal (news.promptugal.reader) 0.4.78, build 575, processed and VALID (iOS run 42838954582 on dev).
- **What is in it:** round 3, the softer look (SF throughout, rounder cards, pill buttons, sentence-case labels, times in SF digits), "Good morning / afternoon / evening" by Lisbon time on Now, and the widget in the same look. News headlines keep the serif. Rounds 1, 2 and 4 are in it too.
- **Tests:** ten app unit tests and every package test passed on iPhone and iPad (runs 42836353622 and 42838954582).
- **What to Test:** `briefs/2026-11-10__newsapp-redesign/what-to-test-575.txt`.
- **The steps:** set-test-info (575, that file), submit-beta-review (575), add-to-group (575, "PrompTugal External Users"). Do not wait for 556's or 562's review.
- **Not in it:** the videos in News. They follow in the next build, with their own request.
- **For devops.ios@web-summit.dinis:** the same run's "TestFlight processing" step failed only on RiskMandate 0.4.78 (575): "build not found" in App Store Connect. Team and PrompTugal 575 are VALID.
