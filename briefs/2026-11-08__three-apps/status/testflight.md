# TestFlight status

> TestFlight ops tool (scripts/testflight/tf.py and the manual "TestFlight ops" workflow) is written with tests, on split/testflight. Watching the first automatic upload from dev (iOS release run 52, 00:53 UTC: signing and upload under way).

**Branch:** `split/testflight` · **Updated:** 8 Nov 00:58 UTC

## Done

- `scripts/testflight/tf.py` with status, add-to-group, remove-from-group, set-test-info, submit-beta-review and expire. Changing actions print a plan unless confirmed. 10 unit tests, no network.
- `.github/workflows/testflight-ops.yml`: manual only, inputs action, build, group, confirm.

## In progress

- First automatic upload from dev: iOS release run 52 (`e5328ff`), TestFlight job running.
- First "status" run.

## Next

- Report build number, processing, export compliance and What to Test to the conductor.
- Plan to move external review from build 4 to the newest CI build (not executed without Dinis's go).

## Blocked

- Nothing.

## Needs from others

- Dinis, for the review notes: contact first name, last name, email and phone; contact address for the support page; response time promise; demo OpenRouter key and its cap; demo vault key; demo lane name.

## Last CI run

- None yet for this branch.
