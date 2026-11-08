# TestFlight status

> TestFlight ops tool works: "status" ran (TestFlight ops #2) and shows build 4 in Beta App Review (IN_REVIEW), builds 5 and 6 only in the internal group. Still watching the first automatic upload from dev (iOS release run 52).

**Branch:** `split/testflight` · **Updated:** 8 Nov 00:58 UTC

## Done

- `scripts/testflight/tf.py` with status, add-to-group, remove-from-group, set-test-info, submit-beta-review and expire. Changing actions print a plan unless confirmed. 10 unit tests, no network.
- `.github/workflows/testflight-ops.yml`: manual only, inputs action, build, group, confirm.

## Real state at 00:56 UTC (TestFlight ops #2, green)

| Build | Version | Uploaded (UTC) | Processing | Internal | External | Beta review | Groups |
|---|---|---|---|---|---|---|---|
| 6 | 0.3.1 | 7 Nov 10:46 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 5 | 0.3.1 | 7 Nov 10:38 | VALID | IN_BETA_TESTING | READY_FOR_BETA_SUBMISSION | none | Internal |
| 4 | 0.3.1 | 6 Nov 16:23 | VALID | IN_BETA_TESTING | IN_BETA_REVIEW | IN_REVIEW | Internal, External |

No CI build (151 or higher) has been uploaded yet.

## In progress

- First automatic upload from dev: iOS release run 52 (`e5328ff`), TestFlight job running.

## Next

- Report build number, processing, export compliance and What to Test to the conductor.
- Plan to move external review from build 4 to the newest CI build (not executed without Dinis's go).

## Blocked

- Nothing.

## Needs from others

- Dinis, for the review notes: contact first name, last name, email and phone; contact address for the support page; response time promise; demo OpenRouter key and its cap; demo vault key; demo lane name.

## Last CI run

- TestFlight ops #2 (status) on `adfdff3`: success.
