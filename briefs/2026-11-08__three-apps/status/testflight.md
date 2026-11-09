# TestFlight status

> TestFlight ops tool works: "status" ran (TestFlight ops #2) and shows build 4 in Beta App Review (IN_REVIEW), builds 5 and 6 only in the internal group. The first automatic upload from dev worked: build 152 (iOS release run 52, dev `e5328ff`), processed, export compliance answered, What to Test set, in the internal group.

**Branch:** `split/testflight` · **Updated:** 9 Nov 19:40 UTC (account B session watching)

## Done

- `scripts/testflight/tf.py` with status, add-to-group, remove-from-group, set-test-info, submit-beta-review and expire. Changing actions print a plan unless confirmed. 10 unit tests, no network.
- `.github/workflows/testflight-ops.yml`: manual only, inputs action, build, group, confirm.

## First automatic upload: green

iOS release run 52 on dev `e5328ff`: uploaded 0.3.1 (152) at 00:57 UTC; processed VALID at 00:59; export compliance already set (`usesNonExemptEncryption = false`); "What to Test" set (2216 characters, from the release notes script); the signed .ipa is kept as an artifact. The build is in "PrompTugal Internal Users" and not in the external group.

## Real state at 01:09 UTC (TestFlight ops #3, green)

| Build | Version | Uploaded (UTC) | Processing | Internal | External | Beta review | Groups |
|---|---|---|---|---|---|---|---|
| 152 | 0.3.1 | 7 Nov 16:58 (shown by Apple; uploaded 8 Nov 00:57 UTC) | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 6 | 0.3.1 | 7 Nov 10:46 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 5 | 0.3.1 | 7 Nov 10:38 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 4 | 0.3.1 | 6 Nov 16:23 | VALID | IN_BETA_TESTING | IN_BETA_REVIEW | IN_REVIEW | Internal, External |


## In progress


- 9 Nov 19:40 UTC: v0.4.45 (release #126 attempt 2, with the notification-crash fix 8605cba): public PrompTugal 226 and Team 226 uploaded, VALID, internal groups only, upload COMPLETE with no errors or warnings; RiskMandate stays 0.4.40 (221). 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 27h30 and 21h15), build 4 APPROVED.

- 9 Nov 18:42 UTC: Team 0.4.42 (223, release #123) VALID in PrompTugal Team Internal; public and RiskMandate stay 0.4.40 (221). The notification-crash fix (8605cba, in v0.4.44/v0.4.45) has no TestFlight build yet: releases #124 and #125 were cancelled, #126 (0451382) ended as failure with no jobs; ios.yml for 8605cba is green now. Reported to the conductor; a re-run of release run 42670843820 is needed (not mine). 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW (about 26h35 and 20h20), build 4 APPROVED.

- 9 Nov 17:37 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 25h35 and 19h20; last check 17:34); build 4 APPROVED. Latest builds are 0.4.40 (221) on all three apps, internal only; release #122 ran no app jobs.

- 9 Nov 17:03 UTC: v0.4.40 (release #121) is on all three apps as build 221, VALID, internal groups only (public app upload COMPLETE with no errors or warnings). 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 25h and 18h45; last check 17:01), build 4 APPROVED. Dev at v0.4.40, no newer app build.

- 9 Nov 16:20 UTC: release #121 (dev 4c11461, v0.4.40, internal only): Team 221 and RiskMandate 221 uploaded and VALID; public app upload still processing. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 24h and 18h; last check 16:17), build 4 APPROVED.

- 9 Nov 15:14 UTC: Team 0.4.34 (215, release #115) VALID in PrompTugal Team Internal. Public app: 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 23h and 16h50; last check 15:11); build 4 APPROVED, all three in the external group; latest public build 0.4.25 (206), internal only. Dev at v0.4.39: releases #116 to #120 ran no app jobs.

- 9 Nov 14:21 UTC: 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 22h and 16h; last check 14:18); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev is at v0.4.35: v0.4.34 (release #115, Team app redesign and messaging merged) has a Team archive running, no public-app or RiskMandate job; I will confirm the Team build when it uploads.

- 9 Nov 13:41 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 21h30 and 15h15; last check 13:39); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.31 (release #112 ran no app jobs), so no newer app build.

- 9 Nov 13:08 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 21h and 14h40; last check 13:06); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.30 (release #111 ran no app jobs), so no newer app build.

- 9 Nov 12:34 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 20h20 and 14h05; last check 12:31); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.29, no newer app build.

- 9 Nov 12:01 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 19h50 and 13h35; last check 11:59); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.29, release #110 ran no app jobs (no app code change), so no newer app build.

- 9 Nov 11:30 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 19h15 and 13h; last check 11:27); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev is at v0.4.28 (briefs and docs only: releases #108 and #109 ran no app jobs), so no newer app build.

- 9 Nov 10:25 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 18h15 and 12h; last check 10:23); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 09:17 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 17h and 10h50; last check 09:15); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 08:10 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 16h and 9h40; last check 08:08); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 07:01 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 14h50 and 8h35; last check 06:59); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 05:56 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 13h45 and 7h30; last check 05:54); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 04:52 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 12h40 and 6h25; last check 04:50); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 03:48 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 11h40 and 5h20; last check 03:46); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26, no newer app build.

- 9 Nov 02:43 UTC: no change. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 10h30 and 4h15; checked every 30 minutes, last 02:41); build 4 APPROVED, all three in the external group. Latest public build 0.4.25 (206), internal only. Dev at v0.4.26 (website only), no newer app build.

- 9 Nov 01:38 UTC: dev is v0.4.26 (cf8214c, website privacy page only): release #107 ran no app jobs, so no new TestFlight build; latest public build stays 0.4.25 (206), internal only. 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review (about 9h30 and 3h10), build 4 APPROVED (all three in the external group).

- 9 Nov 00:40 UTC: rc10 on dev 9be7b13 (v0.4.25), release #106: all three TestFlight jobs green. Public app 0.4.25 (206): upload COMPLETE with no errors, warnings or infos, so no ITMS-90683; VALID, in PrompTugal Internal Users only (internal-only rule). 0.4.23 (204) and 0.4.24 (205) still WAITING_FOR_REVIEW in Beta App Review, build 4 APPROVED.

- 9 Nov 00:06 UTC: 0.4.23 (204) and 0.4.24 (205) both still WAITING_FOR_REVIEW in Beta App Review (204 for about 8h, 205 for about 1h40); build 4 stays APPROVED in the external group. 205 What to Test now set for en-US and en-GB (978 characters each; `set-test-info` writes both from now on). Rule from Dinis via the conductor: 0.4.25 and later are TestFlight internal only, no external steps unless he asks. Dev is at v0.4.24.

- 8 Nov 23:19 UTC: 0.4.24 (205) was submitted for Beta App Review about 22:26 (Apple accepted it alongside 0.4.23 (204), submitted about 16:10 and still waiting after about 7h). Both WAITING_FOR_REVIEW (checked 22:50 and 23:17), both in the external group. Build 4 stays APPROVED in the external group; I ask the conductor before removing 204 or 4.

- 8 Nov 22:25 UTC: rc8 public build 0.4.24 (205), release #105 on dev 1a50c81 (Ask only in DEBUG): VALID, in PrompTugal Internal Users. Plans ready for set-test-info (978-char What to Test, 2450-char notes), add-to-group "PrompTugal External Users", submit-beta-review; waiting for the conductor to dispatch the confirm runs. 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review (about 6h15), untouched.

- 8 Nov 21:24 UTC: 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review after about 5h15 (last check 21:23). Dev unchanged at v0.4.23. Build 4 stays APPROVED in the external group.

- 8 Nov 20:25 UTC: 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review after about 4h15 (last check 20:23). Dev unchanged at v0.4.23. Build 4 stays APPROVED in the external group.

- 8 Nov 19:28 UTC: 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review after about 3h15 (last check 19:26). Dev unchanged at v0.4.23. Build 4 stays APPROVED in the external group and is what the public link serves meanwhile.

- 8 Nov 18:33 UTC: 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review (submitted about 16:10; checked every 20 to 25 minutes, last 18:31). Dev unchanged at v0.4.23. Build 4 stays APPROVED in the external group.

- 8 Nov 17:42 UTC: 0.4.23 (204) still WAITING_FOR_REVIEW in Beta App Review (checked 16:34, 16:56, 17:19, 17:41). Dev unchanged at v0.4.23, no new builds. Build 4 stays APPROVED in the external group.

- 8 Nov 16:58 UTC: Beta App Review for 0.4.23 (204) still WAITING_FOR_REVIEW (checked 16:34 and 16:56); build 4 remains APPROVED in the external group. Checking every 20 minutes.

- 8 Nov 16:26 UTC: public app 0.4.23 (204), release #104 on dev 3125e3e: upload COMPLETE, VALID, in PrompTugal Internal Users. Conductor dispatched the confirm runs (set-test-info, add-to-group "PrompTugal External Users", submit-beta-review; my own confirm dispatch was blocked by the permission layer). Verified read-only at 16:12: Beta App Review WAITING_FOR_REVIEW, build in both groups, review notes and contact set. Build 4 (0.3.1) stays in the external group until Dinis says otherwise. Watching the review result.

- 8 Nov 15:43 UTC: summit build on dev. Release #103 (v0.4.22, 45f44d8) failed in "Release notes" (SIGPIPE from `head -c 3900` under pipefail), no upload. Conductor fixed release-notes.sh; release #104 (v0.4.23, 3125e3e) archives are green, TestFlight jobs queued. Will report the public app version and build when the upload is COMPLETE and VALID. External path on hold.

- 8 Nov 14:50 UTC: merged split/review a793738 (56b60f0); what-to-test.txt and review-notes.txt already equal the store pack, no text change. Dev still v0.4.21, no upload since 0.4.16 (197). External path on hold until the conductor says go on the final build.

- 8 Nov 14:07 UTC: merged split/rc4 and split/review (1b628bb); review-notes.txt updated (step 4: notification permission wording), what-to-test.txt unchanged (commit eb40b63, sent to conductor for rc6). No new dev release or upload since 0.4.16 (197). External path still on hold.
- 8 Nov 13:10 UTC: merged split/rc2 (3de45dd); `scripts/testflight/review-notes.txt` and `what-to-test.txt` now equal the summit store pack (commit a11b10f). Dev is still at v0.4.21 (run 102 cancelled), no new upload since 0.4.16 (197). External path for the public app is on hold: plan-only until the conductor says go on the final build after the 16:00 UTC freeze.

- 01:50 UTC: account B took over. iOS release run 60 (dev `116a350`) is queued; no new upload yet. Run 59 (split/release dry run) is in progress. Next check in 30 minutes.
- 12:25 UTC: first good public-app build: 0.4.16 (197), iOS release run 97 (dev `89badfe`): Apple build upload COMPLETE (the 0.4.12 (189) upload stays FAILED 90683), processed VALID, in PrompTugal Internal Users, not yet in the external group. Exported entitlements: associated-domains, time-sensitive, group.news.promptugal.reader on app, widgets and intents. External path ready on the conductor's go: set-test-info, add-to-group "PrompTugal External Users", submit-beta-review (build 197). Review notes (3121 chars) and What to Test (1105 chars) from the summit store pack are in scripts/testflight/.
- 11:50 UTC: Dinis lifted internal-only for the public app (brief `briefs/2026-11-08__summit-app-store/README.md`). Plan only, nothing changed: external group "PrompTugal External Users" exists with the public link already enabled (no limit, feedback on), serving 0.3.1 build 4 (the old all-in-one app) today; Beta App Review details: contact set, notes empty; review notes ready in `scripts/testflight/review-notes.txt` (3419 chars); What to Test text still says "Web Summit" and needs the new name. Sequence for the first good public build N: set-test-info, add-to-group "PrompTugal External Users", submit-beta-review, each on the conductor's go. New testflight-ops actions: `groups` (read-only) and `public-link` (plan unless confirmed). Build 189 of the public app was rejected (error 90683, plist fix pending).
- 10:58 UTC: run 89 (v0.4.12, dev `7d83217`): Team 0.4.12 (189) VALID; RiskMandate job finished; the first public-app upload (`news.promptugal.reader`, build 189) was REJECTED by Apple: build upload state FAILED, error 90683, missing `NSSpeechRecognitionUsageDescription` in PrompTugal.app's Info.plist. No build record exists, so the wait step said "build not found". Found with the new read-only testflight-ops action `inspect` (run 42473260107; inputs bundle, build = version). The Team project has both `INFOPLIST_KEY_NSMicrophoneUsageDescription` and `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription`; the PrompTugal project has neither. Reported to the conductor. Exported public-app entitlements are complete (associated-domains, time-sensitive, group.news.promptugal.reader on app, widgets, intents).
- 10:27 UTC: conductor asked for tester guidance for the Team app. Draft "What to Test" for PT Team is in `scripts/testflight/what-to-test-team.txt` (vault key must be imported again, team tools live in PT Team, PrompTugal.news becomes the public app). New testflight-ops action `set-whats-new` (inputs bundle, build, text_file, confirm): plan run 42471333246 on Team build 182 changed nothing. Applying needs confirm=true and the conductor's or Dinis's go. Run 89 (v0.4.12, dev `7d83217`, first with the public app's TestFlight job) is in its TestFlight jobs, queued.
- 09:45 UTC: first build on the Team record: 0.4.7 (182) from run 82 (dev `cd81f2d`), VALID, "PrompTugal Team Internal". RiskMandate 0.4.7 (182) VALID too. The reader record gets no new build until the public PrompTugal app's testflight is on. Cheap way to read runs: `gh api repos/PrompTugal/PrompTugal__App__iOS/actions/runs/<id>/jobs`.
- 08:48 UTC: dev unchanged since v0.4.6 (`67e6281`); no new release run, no new upload. Latest builds: reader 0.4.6 (180), RiskMandate 0.4.4 (178), Team none.
- 08:20 UTC: run 80 (v0.4.6, dev `67e6281`) uploaded 0.4.6 (180) to the reader record: VALID, PrompTugal Internal Users only; exported app keeps associated-domains, time-sensitive and app group `group.news.promptugal.reader`, widgets and intents carry the app group. RiskMandate unchanged at 0.4.4 (178); Team record still empty.
- 07:58 UTC: first dev uploads with the signing fix: run 78 (v0.4.4, dev `f4fd02c`) uploaded 0.4.4 (178) to the reader record and to RiskMandate, both VALID, internal groups only. The exported reader app keeps associated-domains, time-sensitive notifications and app group `group.news.promptugal.reader`; widgets and intents carry the app group. Team record `news.promptugal.team` still empty. Run 79 (v0.4.5) cancelled; run 80 (v0.4.6) in progress.
- 07:08 UTC: conductor says the signing fix is on dev (`d36d147`); the next dev release should upload again. No dev release run since run 71 yet (only split/release dry runs, run 77 in progress). To confirm on that upload: build reaches the reader record and PrompTugal Internal Users, exported app entitlements in the job log include app group `group.news.promptugal.reader`, widgets and intents intact.
- 06:55 UTC: dev unchanged since v0.4.3 (`a810f38`); release's signing fix (266c7ba, now 2b3835a on split/release) not merged: the dry run built without the app group, associated domains and time-sensitive entitlements. No dev upload until a fix keeps them. When the first upload after the fix lands: check the reader record, the exported app's entitlements in the job log (app group `group.news.promptugal.reader`), and that widgets and intents are intact.
- 06:25 UTC: run 71 (dev `a810f38`, v0.4.3, build 171) failed at "Archive, sign, export and upload" with the same error as run 69: "Your account has reached the maximum number of certificates", then no development profiles for news.promptugal.reader and its .intents and .widgets targets. No upload. Dev still has the old signing script; release's fix is on split/release (cfffe8d, run 70 green there, run 73 in progress), not on dev yet. Latest builds unchanged: reader 0.4.1 (168), RiskMandate 0.4.0 (167), Team none (status runs 16 to 18, 06:20 UTC).
- 05:52 UTC: conductor reports iOS release #69 (dev `0614bed`) failed to sign: the Apple account hit its maximum number of development certificates (automatic signing creates one per CI run); no upload from #69, release is fixing the archive step. Read-only count (new `certificates` action in testflight-ops, run 15): 12 signing certificates, 11 DEVELOPMENT (10 created 7-8 Nov) and 1 DEVELOPER_ID_APPLICATION_G2; no distribution certificate. Nothing changed in App Store Connect or the developer portal.
- 05:18 UTC: dev unchanged since v0.4.1 (`a0c8bde`), no new release run, no new upload. Waiting for phase 4 (first Team build, promptugal TestFlight job).
- 04:50 UTC: run 68 (dev `a0c8bde`, v0.4.1) uploaded 0.4.1 (168) to the reader record, VALID, internal group only. RiskMandate not rebuilt (unaffected), still 0.4.0 (167). Team record still empty until phase 4.
- 04:20 UTC: run 67 done. Reader record has 0.4.0 (167) VALID in PrompTugal Internal Users, plus 0.3.1 (165) from run 65. RiskMandate 0.4.0 (167) VALID in RiskMandate Internal. Team record news.promptugal.team (group "PrompTugal Team Internal") has no builds yet: expected until phase 4 points apps.json team at it.
- 04:05 UTC: first 0.4.0 build: RiskMandate 167 from run 67 (`d525706`), VALID, in RiskMandate Internal. Team and PrompTugal jobs of run 67 still running. Added a `bundle` input to `testflight-ops.yml` on this branch so status can read other records (read-only; dispatch with ref split/testflight).
- 03:32 UTC: build 163 (run 63, dev `5500c02`) uploaded and processed. Run 64 (dev `d597b8f`) pending; dev has since moved to v0.1.81 (`c0d3455`), more runs will follow.
- 03:15 UTC: run 63 (dev `5500c02`, AppLinks.scheme, tag v0.1.78) is in its TestFlight job; run 64 (dev `d597b8f`, CollabSeams, v0.1.79) is pending. Will report builds once processed.
- 02:45 UTC: run 61 (dev `36508b6`) uploaded build 161. The job was named "TestFlight (team)" (APP_KEY=team) but still built PrompTugal.xcodeproj with bundle news.promptugal.reader, so it went to the reader record. Expected until phase 4 switches apps.json. Still 0.3.x.
- 02:08 UTC: no new iOS release run since run 60 (cancelled). dev has only docs commits (tag v0.1.76), which do not upload. Conductor: signing is automatic for Team and RiskMandate; both records and internal groups exist. If a first signed build fails for lack of a profile, read the log and tell the conductor.
- 01:50 UTC (conductor): run 60 cancelled to free the macOS queue; the next code merge to dev uploads everything since build 152. Dinis created the App Store Connect records for Team and RiskMandate; uploads to them wait on per-app profile secrets and an internal group per record.

- Watching each automatic upload: it must land in the right record and its internal group. One line per build below.

## Decision (Dinis, 01:22 UTC)

During the summit everything runs on internal testers only. The external swap plan is shelved: no set-test-info, no external group changes, no Beta App Review submissions. Build 4 stays as it is (Apple approved it for external testing at 01:19 UTC; it is older than the review fixes).

## Next

- When Team and RiskMandate have records, check their builds reach their internal groups.

## Blocked

- Nothing.

## Uploads seen

| Version | Build | Commit | Processed | Group |
|---|---|---|---|---|
| 0.3.1 | 152 | `e5328ff` | yes, 00:59 UTC | PrompTugal Internal Users |
| 0.3.1 | 161 | `36508b6` (run 61) | yes, VALID (status run 7, 02:40 UTC) | PrompTugal Internal Users only |
| 0.3.1 | 163 | `5500c02` (run 63) | yes, VALID (status run 8, 03:28 UTC) | PrompTugal Internal Users only |
| 0.3.1 | 165 | `11ab789` (run 65) | yes, VALID (status run 10, 04:13 UTC) | PrompTugal Internal Users only |
| 0.4.0 | 167 (reader record, from the "TestFlight (team)" job) | `d525706` (run 67) | yes, VALID (status run 10, 04:13 UTC) | PrompTugal Internal Users only |
| 0.4.1 | 168 (reader record, from the "TestFlight (team)" job) | `a0c8bde` (run 68, v0.4.1) | yes, VALID (status run 12, 04:44 UTC) | PrompTugal Internal Users only |
| 0.4.4 | 178 (reader record, "TestFlight (team)" job) | `f4fd02c` (run 78, v0.4.4) | yes, VALID (status run 19, 07:51 UTC) | PrompTugal Internal Users only; app group, associated domains, time-sensitive kept; widgets and intents carry the app group |
| 0.4.4 | 178 (RiskMandate) | `f4fd02c` (run 78) | yes, VALID (status run 20, 07:51 UTC) | RiskMandate Internal |
| 0.4.6 | 180 (reader record, "TestFlight (team)" job) | `67e6281` (run 80, v0.4.6) | yes, VALID (status run 21, 08:14 UTC) | PrompTugal Internal Users only; entitlements complete again |
| 0.4.7 | 182 (Team, `news.promptugal.team`) | `cd81f2d` (run 82, v0.4.7) | yes, VALID (status run 22, 09:41 UTC); first Team build | PrompTugal Team Internal; associated-domains and time-sensitive present, no app group declared |
| 0.4.7 | 182 (RiskMandate) | `cd81f2d` (run 82) | yes, VALID (status run 23) | RiskMandate Internal |
| 0.4.0 | 167 (RiskMandate, `ai.riskmandate.app`) | `d525706` (run 67, v0.4.0) | yes, VALID (status run 9, 04:01 UTC) | RiskMandate Internal |

## Needs from others

- Only if the external plan comes back: Dinis, for the review notes (REVIEW_CONTACT_PHONE is the one not set): contact first name, last name, email and phone; contact address for the support page; response time promise; demo OpenRouter key and its cap; demo vault key; demo lane name.

## Last CI run

- TestFlight ops #3 (status) on `5c5ce57`; iOS release run 52: success.

## Handoff

Handed to the next TestFlight session (account B) at 01:35 UTC. My scheduled check-ins are cancelled.

**Last known state (8 Nov 01:19 UTC, TestFlight ops #5, record "PrompTugal.news", `news.promptugal.reader`, version 0.3.1):**

| Build | Processing | Internal | External | Beta review | Groups |
|---|---|---|---|---|---|
| 152 (dev `e5328ff`, first automatic upload) | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 6 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 5 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 4 | VALID | IN_BETA_TESTING | BETA_APPROVED | APPROVED (01:19 UTC) | Internal, External |

Build 152 had export compliance answered and an automatic "What to Test" (2216 characters). Build 4 is older than the App Review fixes and stays as it is unless Dinis says otherwise. Later pushes to dev upload automatically; versions will become 0.4.n once release's change lands.

**Internal testers only (Dinis, 01:22 UTC).** During the summit every build goes to the internal group. For each new automatic upload, send the conductor one line: version, build, commit, processed, internal group. When the Team and RiskMandate records exist, check their builds reach their internal groups too.

**Shelved external plan (do not run without Dinis's go).** Set test info on the newest build (needs secret REVIEW_CONTACT_PHONE, the only one not yet set), add it to "PrompTugal External Users", submit it for Beta App Review, then optionally remove or expire build 4 once the new build is approved. A plan-only `set-test-info` run on 152 showed nothing else missing.

**How to run testflight-ops** (Actions > "TestFlight ops", or `actions_run_trigger` on `testflight-ops.yml`, ref `dev` once merged; it is on dev):
- Inputs: `action` (status, add-to-group, remove-from-group, set-test-info, submit-beta-review, expire), `build` (build number), `group` (group name), `confirm` (false by default).
- Without `confirm` it only prints the plan; `status` always only reads. The output is in the job log (and the run summary).
- Contact comes from secrets `REVIEW_CONTACT_FIRST_NAME`, `REVIEW_CONTACT_LAST_NAME`, `REVIEW_CONTACT_EMAIL`, `REVIEW_CONTACT_PHONE`; demo notes from secret `DEMO_OPENROUTER_KEY`, variables `DEMO_OPENROUTER_CAP`, `REVIEW_CONTACT_ADDRESS`, `REVIEW_RESPONSE_TIME`; optional `DEMO_VAULT_KEY`, `DEMO_LANE_NAME`. The editor owns `review-notes.txt` and `what-to-test.txt`.
- Code: `scripts/testflight/tf.py` and tests in `scripts/testflight/tests/` (run `python3 -I scripts/testflight/tests/test_tf.py`).
- A new workflow only runs once it is on the default branch; the repository is public, so no personal details go in files.
