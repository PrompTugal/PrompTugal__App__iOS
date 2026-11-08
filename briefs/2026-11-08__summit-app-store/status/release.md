# Release status: summit app

> Release owns two things today: App Store screenshots from `screens.yml` (built, not yet run on the real screens) and the plan for the App Store path through the App Store Connect API (below, nothing executed). The API can do everything except the App Privacy answers; Dinis does those by hand, plus anything Apple refuses over the API.

**Branch:** `split/release` · **Updated:** 8 Nov, 11:40 UTC

## Screenshots (built)

- `screens.yml`, run by hand with **`app=promptugal`, `store=true`** (optional `locales`, default `en-US,pt-PT,pt-BR`).
- One job per display size, all locales inside the job. The device decides the pixel size, so nothing is scaled:

| Size | Simulator (first one the runner has) | Pixels | ASC display type |
| --- | --- | --- | --- |
| iPhone 6.9" | iPhone 17 Pro Max, then 16 Pro Max | 1320×2868 | `APP_IPHONE_69` |
| iPhone 6.5" | iPhone 14 Plus, 13 Pro Max, 11 Pro Max, XS Max | 1284×2778 or 1242×2688 | `APP_IPHONE_65` |
| iPad 13" | iPad Pro 13-inch (M5), then (M4) | 2064×2752 | `APP_IPAD_PRO_3GEN_129` |

- `store-check.py` fails the job on any size Apple does not take. Output is JPEG (no alpha channel), light appearance, status bar 9:41 full battery.
- Artifact `appstore-screens-<sha>-promptugal`: `<locale>/<display type>/<NN>-<screen id>.jpg`. The order of the files is the order on the store page.
- Locales come from the app's own strings: the job passes `-testLanguage` and `-testRegion` to the screens test, so pt-PT and pt-BR show once i18n has landed.
- **Needs from others:** the PrompTugal project's `PrompTugalScreens` scheme must run a screens test that attaches one screenshot per destination (like Team's `ScreensTests`); apps or design own it. Apple takes at most 10 screenshots per set: ux picks the ten and the order; until then the artifact has every destination.
- **Inputs:** `ids` (default `now,team.schedule,explore,news.home`: the screens to keep, in store order; a missing id fails the job) and `now` (default `2026-11-10T11:00:00Z`: the pretend time). `now` reaches the screens test as the environment variable `PT_NOW` (set through `TEST_RUNNER_PT_NOW`); the test must pass it on as a launch argument, an empty value meaning real time:

```swift
var args = ["-PTDestination", id, "-PTSampleData"]
if let now = ProcessInfo.processInfo.environment["PT_NOW"], !now.isEmpty { args += ["-PTNow", now] }
app.launchArguments = args
```

- **Plan:** one run on dev at about 15:40 UTC, `screens.yml` with `app=promptugal store=true` (about 25 minutes with three sizes in parallel); needs this workflow merged to dev first.
- Not yet run: the first run waits for the screens test and for the CI queue.

## Plan: App Store through the API (nothing executed)

Everything uses the existing key and `scripts/release/asc.py` (it already has `has-record`, `wait-build`, `compliance`, `whats-new` for TestFlight, and `submit`). New subcommands would be added there, each a dry run unless `--yes`, and nothing runs without the conductor's go. The app is the record for `news.promptugal.reader`.

| # | Step | API | Can the API do it? |
| --- | --- | --- | --- |
| 1 | Pick the build (version, build number) and wait until processing is `VALID` | `GET /v1/builds` | Yes (`wait-build`) |
| 2 | Export compliance answered | `PATCH /v1/builds/{id}` `usesNonExemptEncryption=false` | Yes (`compliance`) |
| 3 | Create the App Store version for that marketing version (e.g. 0.4.n), release type manual | `POST /v1/appStoreVersions` | Yes |
| 4 | Attach the build to the version | `PATCH /v1/appStoreVersions/{id}/relationships/build` | Yes |
| 5 | Name **"PrompTugal: Lisbon Summit"**, subtitle, privacy policy URL, per locale | `GET /v1/apps/{id}/appInfos`, then `PATCH /v1/appInfoLocalizations/{id}` (create with `POST` for pt-PT and pt-BR) | Yes, while the app info is editable. Apple checks that the name is free when it is saved; if it refuses, Dinis sets it by hand |
| 6 | Description, keywords, promotional text, what's new, support URL, marketing URL, per locale (en-US, pt-PT, pt-BR) | `POST/PATCH /v1/appStoreVersionLocalizations` | Yes |
| 7 | Screenshots | `POST /v1/appScreenshotSets` per locale and display type, then `POST /v1/appScreenshots` (reserve), upload the file parts to the returned URLs, `PATCH` with `uploaded=true` and the MD5 | Yes. Ten per set, in file order |
| 8 | Categories (primary, secondary) | `PATCH /v1/appInfos/{id}` relationships | Yes |
| 9 | Age rating answers | `PATCH /v1/ageRatingDeclarations/{id}` | Yes (review prepares the answers) |
| 10 | Content rights declaration (no third-party content) | `PATCH /v1/apps/{id}` `contentRightsDeclaration` | Yes |
| 11 | Price: free, and territories | `POST /v1/appPriceSchedules`, territory availability | Yes |
| 12 | Copyright line | `PATCH /v1/appStoreVersions/{id}` `copyright` | Yes |
| 13 | Review contact, notes for the reviewer, demo account (none) | `POST/PATCH /v1/appStoreReviewDetails` | Yes. The phone number comes from the secret `REVIEW_CONTACT_PHONE`, never from git |
| 14 | **App Privacy answers** (data types collected, tracking) | none in the public API | **No: Dinis, by hand, in App Store Connect** (review prepares every answer) |
| 15 | Advertising identifier question and similar prompts shown at submission | not in the API; they come back as errors on submit if unanswered | **Maybe by hand**: we find out on the dry run of step 16 |
| 16 | Submit for review | `POST /v1/reviewSubmissions`, `POST /v1/reviewSubmissionItems`, `PATCH ... submitted=true` | Yes (`submit`, with `confirm`). Apple refuses it with a list of what is missing, which tells us if step 14 or 15 is open |
| 17 | Release after approval (manual or automatic) | `PATCH /v1/appStoreVersions/{id}` `releaseType`; `POST /v1/appStoreVersionReleaseRequests` | Yes |

Order and checks:

- Steps 3 to 13 can run as soon as the build exists; steps 5, 6 and 13 read their text from review's files in git, so the store page matches what review approved. Every step first reads what is already there and changes only what differs, so it can be run again.
- A dry run prints what each step would change. The first real run is steps 3 to 13 with the conductor's go; the submit (16) is a separate go.
- A new build number after the submission starts needs steps 1, 2 and 4 again, and a new submission.
- The public TestFlight link (testflight's part) is separate: external group, `betaAppReviewSubmissions`, `betaGroups.publicLinkEnabled`. Not in this plan.

## What only Dinis can do by hand

- **App Privacy answers** (step 14).
- Anything Apple refuses over the API: most likely the name if "PrompTugal: Lisbon Summit" is taken (step 5), and any submission prompt that the API cannot answer (step 15).
- The `REVIEW_CONTACT_PHONE` secret.
