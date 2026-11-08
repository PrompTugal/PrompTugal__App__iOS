# TestFlight status

> TestFlight ops tool works: "status" ran (TestFlight ops #2) and shows build 4 in Beta App Review (IN_REVIEW), builds 5 and 6 only in the internal group. The first automatic upload from dev worked: build 152 (iOS release run 52, dev `e5328ff`), processed, export compliance answered, What to Test set, in the internal group.

**Branch:** `split/testflight` · **Updated:** 8 Nov 01:12 UTC

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

- Waiting for Dinis's go and the missing review details (see below).

## Next

- Plan to move external review from build 4 to the newest CI build (not executed without Dinis's go).

## Blocked

- Nothing.

## Needs from others

- Dinis, for the review notes: contact first name, last name, email and phone; contact address for the support page; response time promise; demo OpenRouter key and its cap; demo vault key; demo lane name.

## Last CI run

- TestFlight ops #3 (status) on `5c5ce57`; iOS release run 52: success.
