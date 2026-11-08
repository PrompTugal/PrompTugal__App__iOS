# App Review readiness: quality and security push

> Three read-only reviews of the app at v0.1.44 (security, App Store guidelines, code quality), what they found, which session fixes what, and the decisions Dinis still has to take before the app goes to Apple.

**Pack date:** 8 November 2026 · **App at time of review:** v0.1.44, commit `d4f4292` · **Status:** fixes done. Every item in the lists below is on `dev` (17:15 Lisbon, 8 Nov), each branch green in CI on iPhone and iPad before it was merged. What remains is in [Decisions for Dinis](#decisions-for-dinis).

## Outcome (17:15)

- **All six sessions' lists are on `dev`:** vault, collab, team, design, platform and editor. CI covers the Debug build, the Release build, the SGitVault tests, and 198 unit tests in 55 suites on iPhone and on iPad.
- **The five likely rejections are addressed in the code:**
  - R1: "Try with sample data", and "not on the team" opens the reader view.
  - R2: the Ask consent sheet, with context off except the public agenda.
  - R3: the privacy page matches the code, and Settings links to it.
  - R4: Report… and Block in Messages.
  - R5: Reading credit is hidden in release builds and its prices match.
- **Both High security findings are fixed:**
  - S1: signatures are required, from pinned signers.
  - S2: the consent sheet above.
- **Not proven:** the purchase tests. StoreKit returns no products in the CI simulator (tried: the scheme's StoreKit configuration, `SKTestSession(contentsOf:)`, an ad hoc signed host). The three purchase tests record a known issue instead of passing. Platform is trying the configuration as a test-bundle resource. Check a purchase by hand in Xcode before submitting.
- **Still needs Dinis:**
  - the contact address (support page and `LaneReport.contactAddress`)
  - the reviewer's demo credentials
  - the decisions below

## The short answer

- **Internal TestFlight (the team): ready now.** It needs no Beta App Review. The privacy manifest and the export-compliance key are already in place.
- **Update, 8 Nov:** Apple's Beta App Review approved build 0.3.1 (4), the version reviewed here before these fixes, in about 24 hours. See [three apps: Apple review so far](../2026-11-08__three-apps/README.md#apple-review-so-far).
- **External TestFlight or Unlisted App Store: about a day of fixes.** These go through App Review. Five things would very likely get the app rejected today (see the list below).
- **Public App Store: not recommended.** This is an internal app tied to one event. Apple's **Unlisted App Distribution** is meant for exactly this case ("limited audiences … conference attendees").

The security review found **no critical issues**. It found two high-risk ones: vault signatures are not enforced, and data goes to the AI provider without consent.

## What App Review would reject today

| # | Guideline | Problem | Owner |
| --- | --- | --- | --- |
| R1 | 2.1(a) completeness | A reviewer without team keys meets "Who are you?" with real team names, then an empty Today tab. Ask, Vault and Messages need keys. Sample data can only be turned on with a launch argument. | design, team |
| R2 | 5.1.2(i) third-party AI | Ask sends agenda, picks, team status and page text to OpenRouter. The app says only that the *key* goes there. There is no consent step. | collab |
| R3 | 5.1.1(i) privacy policy | The site's privacy page says the app "collects nothing", but lanes send messages, Ask sends prompts and dictation can use Apple's servers. There is no privacy link inside the app. | editor, design |
| R4 | 1.2 user content | Messages between people have no report or block, and the support page has no contact address. | collab, editor |
| R5 | 3.1.1 / 2.3.1 purchases | Reading credit unlocks nothing ("every page still opens at any balance"), the price shown in the app (£5) differs from the StoreKit file (0.99), and credit can be lost if the site's storage is cleared. | team |

Also flagged: the app shows debug panels by default; the camera, NFC and speech purpose strings are inaccurate; the `processing` background mode is declared but not used; the passkey and universal-link file is missing on promptugal.news (404); and the app uses Web Summit's name and a badge asset (guideline 5.2).

## Security findings

| # | Level | Finding | Owner |
| --- | --- | --- | --- |
| S1 | High | Vault commit signatures are checked but never required. A commit that fails verification is still used, and the trusted keys come from the vault itself. Anyone with a read key and write access to the server could serve forged picks, AI settings or lane descriptors. | vault |
| S2 | High | Same as R2: personal and team data go to OpenRouter without consent. | collab |
| S3 | Medium | When Face ID and the passcode are unavailable, the Keychain quietly stores vault keys with no access control, while the screen still says "behind Face ID". | vault |
| S4 | Medium | Debug mode is on in release builds, the web inspector can attach to bridge pages, and `promptugal://open/debug` ignores the debug setting. | design, platform |
| S5 | Medium | A teammate's imported vault can become "your" vault, which means an OpenRouter key could be loaded from a vault they control. | vault, collab |
| S6 | Medium | The app-switcher snapshot shows keys, messages and the Ask conversation. The key field is a plain text field. | design, vault |
| S7 | Low | No size caps on inflate or HTTP responses; pasted keys stay on the pasteboard; the bridge's notification permission can be triggered without a tap; lane endpoints can be any https host; Ask renders tappable links from model output. | vault, platform, team, collab |

**Checked and fine:** no secrets in the repo (the fixture keys are throwaway and labelled); no keys or tokens in logs; AES-GCM nonces; object-hash checks; path checks; the bridge's origin checks on every message; App-Bound Domains; no ATS exceptions; StoreKit transaction verification; and file protection on caches.

## Stability findings

| # | Level | Finding | Owner |
| --- | --- | --- | --- |
| Q1 | Must fix | A pick time like `1e300` from a web page or another device crashes the app when it is converted to milliseconds, and keeps crashing on every launch once saved. | team |
| Q2 | Must fix | The graph explorer can index past the end of a reloaded, smaller graph. Huge numbers in graph JSON trap in `Int(...)`. | design |
| Q3 | Must fix | A failed meter save still finishes the StoreKit transaction, so the credit is lost. | team |
| Q4 | Must fix | RSA-4096 key generation and inbox decryption run on the main thread, which can freeze the screen for seconds. | collab |
| Q5 | Should fix | No `#if DEBUG` anywhere; launch arguments and sample people ship in release; CI builds only Debug. | platform |
| Q6 | Should fix | Tapping a reminder does nothing, and the notification delegate is set too late for a cold launch. | team |
| Q7 | Should fix | Error text shows raw `Error Domain=…` strings and vault object paths. | vault, collab |
| Q8 | Should fix | Three copies of the team models, base URL and Lisbon-day code; TeamStore bypasses the shared HTTP client, so its requests never appear in Debug → Network. | team, design, collab |
| Q9 | Should fix | Fixed widths (400, 360, 340, 250 pt) break iPad Split View. | design, collab |
| Q10 | Should fix | No tests for the bridge's origin checks, StoreKit, the Keychain or the planner store. | team, vault |

The full findings, with file and line references, are in [findings](findings.md).

## Who does what

| Session | Fixes |
| --- | --- |
| **vault** | S1 enforce signatures and pin trusted keys; S3 no silent fallback; S5 never treat an imported vault as yours; S6 secure key field; Q7 readable errors; inflate cap; clear the pasteboard after import; a throwaway demo vault for the reviewer. |
| **collab** | R2/S2 consent sheet before the first Ask, with context off by default; R4 report and block on lanes; Q4 crypto off the main thread; links in Ask output need confirmation; double-send guard; Split View widths. |
| **team** | Q1 clamp pick times; Q3 finish only after the save succeeds; R5 make prices match, and hide Reading credit in release builds until Dinis decides; Q6 reminder taps; block every Stripe and checkout host in all web views; notification permission only after a tap; bridge and StoreKit tests; route TeamStore through HTTPClient. |
| **design** | R1 "Try with sample data" on Who are you?, and "not on the team" opens the reader view; debug off by default in release; respect `debugOnly` in links; Q2 graph fixes; S6 cover the app in the switcher; privacy and support links in Settings; Split View widths. |
| **platform** | `#if DEBUG` for launch arguments, sample data and `isInspectable`; remove NFC, narrow the camera and speech strings; remove the `processing` background mode; a Release build job in CI; response size cap in HTTPClient; a decision note on applinks/AASA. |
| **editor** | R3 rewrite privacy.html to match the code; R4 contact section on support.html; App Review notes and an App Store Connect privacy-label sheet in this pack. |

## Decisions for Dinis

1. **Distribution path.** Recommended: internal TestFlight now. Then go Unlisted, not public, if attendees should get it.
2. **Reading credit.** Make it a tip ("Support the newsroom"), or make credit do something native? Until you decide, it is hidden in release builds so it cannot block review.
3. **Contact address** for the support page and for App Review.
4. **Web Summit name and badge.** The `ShortcutWebSummit` image reads "RiskMandate • Web Summit edition". For an Unlisted or public build, drop it or confirm permission. The non-affiliation note stays.
5. **Export compliance.** `ITSAppUsesNonExemptEncryption = NO` is defensible, because all the crypto is Apple's. Confirm it once in the App Store Connect questionnaire. Whether a yearly self-classification report is needed is a legal call.
6. **Reviewer credentials.** A capped OpenRouter key and a demo vault and lane made for the reviewer only, never a team key.
