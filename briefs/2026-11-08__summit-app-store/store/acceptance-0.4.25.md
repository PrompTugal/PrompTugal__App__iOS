# Privacy-first acceptance rules for 0.4.25

> What review checks on every candidate for 0.4.25 (rc9 and later) before giving a GO. The 0.4.24 build in App Review set the bar: one host, no data collected, no permission without a tap. 0.4.25 must keep every promise in its listing and its privacy label, with the label still **Data Not Collected**. Each rule has the check that proves it; a candidate that fails one rule is NO-GO until it is fixed or the conductor accepts the exception in writing.

## P1 · One host

The Release app fetches only from **promptugal.news**, and its web views load only promptugal.news. Every other link opens in Safari.

- `git grep -nohE "https://[a-z0-9.-]+" -- Packages/*/Sources Apps/PrompTugal ':!*Tests*' | sort -u`. Every host other than promptugal.news must be one of these: a `Link`/`openURL` target (Safari), a Team-only code path that is not linked in Release, or a constant that is never fetched. List each one in the go/no-go table.
- Every `HTTPClient.shared`, `URLSession` and `URLRequest` call site in the code the app links must build its URL from `FeedClient.site` (promptugal.news) or `NewsroomAPI`.
- `WebPage.leavesSite` and `WebsiteView`'s host rule are unchanged. A new web view must use `WebPage`, never a bare `WKWebView`.
- collab's live feeds: served from promptugal.news (for example `api/v1/live/*.json`), never fetched from a third-party feed. The newsroom's server can fetch others; the app must not.

## P2 · No identifiers, no cookies, no tracking

- `HTTPClient.makeSession()` keeps `httpCookieStorage = nil`, `httpShouldSetCookies = false` and `httpCookieAcceptPolicy = .never`.
- Requests carry no device or user identifier: no IDFV, no IDFA, no install ID, no pick list or persona in a query string or header. `User-Agent` stays `PrompTugal/<version> (<build>; iOS)`.
- `git grep -nE "identifierForVendor|advertisingIdentifier|ASIdentifierManager|AppTrackingTransparency|ATTrackingManager"` finds nothing in the code the app links.
- No analytics or crash SDK. `Package.swift` files and the project have no remote package references.
- A "persona" or "who are you?" choice from onboarding (ux) is stored on the device only and never sent. If it changes what is fetched, it fetches the same public files for everyone and filters on the device.

## P3 · Data Not Collected

- `Apps/PrompTugal/Resources/PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty, `NSPrivacyCollectedDataTypes` empty. Required-reason APIs are listed with valid reasons; if new code uses a new API category (for example disk space or system boot time), add it.
- The widget and intents manifests match their code.
- Nothing the user types or picks leaves the device. That covers search terms, picks, persona and onboarding answers. With Ask unlinked (apps), there is no path to any AI service.
- The privacy page (`website/pages/privacy.html` and `/pt/`) says the App Store version collects no data and has no assistant (editor).

## P4 · No permission without a tap

- The only permissions the Release build may ask for are **notifications**, on the first pick (`askOnceWhenUseful`), the reminders toggle or the "Allow reminders" button, and **calendar write-only**, on Add to Calendar. Both always follow a tap.
- `git grep -n "requestAuthorization\|requestAccess\|requestRecordPermission\|AVCaptureDevice\|LAContext\|CLLocationManager"` in the code the app links: every hit must be inside a button or toggle action, or a function only those call. None may sit in `.task`, `.onAppear`, `init` or app launch.
- Onboarding (design and ux) does not ask for any permission on its own screens. It may explain reminders, but the system prompt comes only from the user's tap on a control that says what it does ("Remind me before each talk").
- With PTAsk, PTVaultUI and SGitVault unlinked (apps), the Info.plist has **no** `NSCameraUsageDescription`, `NSFaceIDUsageDescription`, `NSMicrophoneUsageDescription` or `NSSpeechRecognitionUsageDescription`. Check with `plutil -p` on the built app (release). `NSCalendarsWriteOnlyAccessUsageDescription` stays. The build must still pass processing: ITMS-90683 fires only when linked code references an API without its string, so unlinking must really remove the references. Confirm with `nm` or by grepping the binary for `AVAudioApplication`, `SFSpeechRecognizer`, `DataScannerViewController` and `LAContext`.

## P5 · Nothing in the build that the store page does not promise, and the reverse

- Each new feature (onboarding, NextHoursCard, live feeds, graph labels) is either covered by the listing or does not contradict it. The description is updated only for what ships (review).
- No debug UI in Release: badges, the Debug screen and `debugOnly` rows stay `#if DEBUG`.
- No third-party trademark on screens that store screenshots show. The screenshot filter applies to new cards, for example NextHoursCard.
- The `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes` match what is registered. If the vault refresh goes, remove its identifier. If collab adds background refresh for live feeds, register `news.promptugal.reader.refresh` and keep `fetch`.
- Entitlements: if `webcredentials:promptugal.news` has no use left after the vault is unlinked, remove it (apps).

## P6 · Same quality as 0.4.24

- Offline first launch still shows the program from the bundled seed. Refresh the seed from `api/v1/live/agenda.json` before the build.
- Times stay on one line in every locale (12-hour en-US, 24-hour pt).
- pt-PT and pt-BR are complete for every new string: no English left in the UI, except content.
- Full CI run green on iPhone and iPad. Store screenshots re-taken only if a store screen changed.

## How review reports

One go/no-go table per candidate in [go-no-go.md](go-no-go.md) (P1 to P6, each GO, NO-GO or accepted exception), sent to the conductor with the sha.
