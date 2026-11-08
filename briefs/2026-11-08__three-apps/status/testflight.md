# TestFlight status

> TestFlight ops tool works: "status" ran (TestFlight ops #2) and shows build 4 in Beta App Review (IN_REVIEW), builds 5 and 6 only in the internal group. The first automatic upload from dev worked: build 152 (iOS release run 52, dev `e5328ff`), processed, export compliance answered, What to Test set, in the internal group.

**Branch:** `split/testflight` · **Updated:** 8 Nov 15:43 UTC (account B session watching)

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
